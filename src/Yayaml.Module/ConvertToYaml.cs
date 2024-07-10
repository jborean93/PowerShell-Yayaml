using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Diagnostics.CodeAnalysis;
using System.Linq;
using System.Management.Automation;
using System.Reflection;
using YamlDotNet.Core.Events;
using YamlDotNet.Serialization;
using YamlDotNet.Serialization.ObjectGraphVisitors;
using YamlDotNet.Core;

namespace Yayaml.Module;

[Cmdlet(VerbsData.ConvertTo, "Yaml")]
[OutputType(typeof(string))]
public sealed class ConvertToYamlCommand : PSCmdlet
{
    private List<PSObject?> _data = new();
    private ISerializer _serializer = default!; // Set in BeginProcessing

    [Parameter(
        Mandatory = true,
        Position = 0,
        ValueFromPipeline = true,
        ValueFromPipelineByPropertyName = true
    )]
    [System.Management.Automation.AllowNull]
    public PSObject? InputObject { get; set; } = null;

    [Parameter]
    public SwitchParameter AsArray { get; set; }

    [Parameter]
    public int Depth { get; set; } = 2;

    [Parameter]
    public SwitchParameter IndentSequence { get; set; }

    [Parameter]
#if NET6_0_OR_GREATER
    [YamlSchemaCompletions]
#else
    [ArgumentCompleter(typeof(YamlSchemaCompletionsAttribute))]
#endif
    [SchemaParameterTransformer]
    public YamlSchema? Schema { get; set; }

    [Parameter]
    public SwitchParameter Stream { get; set; }

    protected override void BeginProcessing()
    {
        SerializerBuilder builder = new SerializerBuilder()
            // We disable the builtin type inspector and pre-processing visitor
            // This is because our emission phase visitor will handle all the
            // type conversions and processing.
            .WithTypeInspector(inner => new YayamlNullTypeInspector())
            .WithPreProcessingPhaseObjectGraphVisitor(new YayamlNullPreProcessingVisitor())
            .WithEmissionPhaseObjectGraphVisitor(
                args => new YayamlObjectGraphVisitor(
                    args.InnerVisitor,
                    this,
                    Depth,
                    Schema ?? YamlSchema.CreateDefault()), w => w.OnTop());
        if (IndentSequence)
        {
            builder = builder.WithIndentedSequences();
        }
        _serializer = builder.Build();
    }

    protected override void ProcessRecord()
    {
        if (Stream)
        {
            SerializeAndWrite(AsArray ? new[] { InputObject } : InputObject);
        }
        else
        {
            _data.Add(InputObject);
        }
    }

    protected override void EndProcessing()
    {
        if (Stream)
        {
            return;
        }

        object? toSerialize = _data.Count == 1 && !AsArray ? _data[0] : _data;
        SerializeAndWrite(toSerialize);
    }

    private void SerializeAndWrite(object? obj)
    {
        string res;
        try
        {
            res = _serializer.Serialize(obj);
        }
        catch (Exception e)
        {
            WriteError(new ErrorRecord(
                e,
                "InputObjectInvalid",
                ErrorCategory.InvalidArgument,
                obj
            ));
            return;
        }

        // Remove the newline added to the end
        res = res.Substring(0, res.Length - Environment.NewLine.Length);
        WriteObject(res);
    }
}

[ExcludeFromCodeCoverage]
internal sealed class YayamlNullTypeInspector : ITypeInspector
{
    public IEnumerable<IPropertyDescriptor> GetProperties(Type type, object? container)
        => Array.Empty<IPropertyDescriptor>();

    public IPropertyDescriptor GetProperty(Type type, object? container, string name, bool ignoreUnmatched)
        => null!;
}

[ExcludeFromCodeCoverage]
internal sealed class YayamlNullPreProcessingVisitor : PreProcessingPhaseObjectGraphVisitorSkeleton
{
    public YayamlNullPreProcessingVisitor() : base(Array.Empty<IYamlTypeConverter>())
    { }

    protected override bool Enter(IObjectDescriptor value)
        => false;

    protected override bool EnterMapping(IObjectDescriptor key, IObjectDescriptor value)
        => false;

    protected override bool EnterMapping(IPropertyDescriptor key, IObjectDescriptor value)
        => false;

    protected override void VisitScalar(IObjectDescriptor scalar)
    { }

    protected override void VisitMappingStart(IObjectDescriptor mapping, Type keyType, Type valueType)
    { }

    protected override void VisitMappingEnd(IObjectDescriptor mapping)
    { }

    protected override void VisitSequenceStart(IObjectDescriptor sequence, Type elementType)
    { }

    protected override void VisitSequenceEnd(IObjectDescriptor sequence)
    { }
}

internal sealed class YayamlObjectGraphVisitor : ChainedObjectGraphVisitor
{
    private readonly PSCmdlet _cmdlet;
    private readonly int _depth;
    private readonly YamlSchema _schema;
    private bool _emittedDepthWarning = false;

    public YayamlObjectGraphVisitor(
        IObjectGraphVisitor<IEmitter> nextVisitor,
        PSCmdlet cmdlet,
        int depth,
        YamlSchema schema) : base(nextVisitor)
    {
        _cmdlet = cmdlet;
        _depth = depth;
        _schema = schema;
    }

    public override bool Enter(IObjectDescriptor value, IEmitter emitter)
    {
        EmitValue(SchemaHelpers.GetPSObject(value.Value), emitter, _depth);
        return false;
    }

    private void EmitValue(PSObject? value, IEmitter emitter, int depth)
    {
        value = _schema.EmitTransformer(value);
        YayamlFormat? formatProp = null;
        if (value != null)
        {
            formatProp = SchemaHelpers.GetYayamlFormatProperty(value);
        }

        object baseObj = value?.BaseObject!;  // Null check is down below
        PSObject psObj = value!;
        if (
            baseObj is null ||
            baseObj is bool ||
            baseObj is char ||
            baseObj is DateTime ||
            baseObj is DateTimeOffset ||
            baseObj is Guid ||
            baseObj is string ||
            SchemaHelpers.IsIntegerValue(baseObj) ||
            SchemaHelpers.IsFloatValue(baseObj) ||
            _schema.IsScalar(baseObj)
        )
        {
            // It's important to send the PSObject if it's a string as the code
            // won't be able to resurrect the PSObject of that type to access
            // any ETS props added to that object. Other types are unaffected
            // by this
            baseObj = _schema.EmitScalar(baseObj is string ? value : baseObj);
            psObj = SchemaHelpers.GetPSObject(baseObj);
        }
        else if (depth < 0)
        {
            string strValue = LanguagePrimitives.ConvertTo<string>(baseObj);
            baseObj = _schema.EmitScalar(strValue);
            psObj = SchemaHelpers.GetPSObject(baseObj);

            if (!_emittedDepthWarning)
            {
                _cmdlet.WriteWarning($"Resulting YAML is truncated as serialization has exceeded the set depth of {_depth}");
                _emittedDepthWarning = true;
            }
        }

        if (baseObj is ScalarValue scalar)
        {
            EmitScalar(scalar, formatProp?.ScalarStyle, emitter);
        }
        else if (baseObj is IList list)
        {
            EmitSequence(list, formatProp?.CollectionStyle, emitter, depth - 1);
        }
        else if (
            IsGenericType(baseObj.GetType(), typeof(Memory<>)) ||
            IsGenericType(baseObj.GetType(), typeof(ReadOnlyMemory<>))
        )
        {
            MethodInfo toArrayMeth = baseObj.GetType().GetMethod(
                "ToArray",
                BindingFlags.Public | BindingFlags.Instance)!;
            EmitSequence(
                (Array)toArrayMeth.Invoke(baseObj, Array.Empty<object>())!,
                formatProp?.CollectionStyle,
                emitter,
                depth - 1);
        }
        else if (baseObj is SequenceValue sequence)
        {
            EmitSequence(sequence, formatProp?.CollectionStyle, emitter, depth - 1);
        }
        else if (baseObj is IDictionary dict)
        {
            EmitMap(dict, formatProp?.CollectionStyle, emitter, depth - 1);
        }
        else if (baseObj is MapValue map)
        {
            EmitMap(map, formatProp?.CollectionStyle, emitter, depth - 1);
        }
        else
        {
            // Treat any other type as a map and process accordingly.
            OrderedDictionary model = new();
            foreach (PSPropertyInfo prop in psObj.Properties)
            {
                // Do not serialize our custom format note property.
                if (prop is PSNoteProperty && prop.Name == SchemaHelpers.YAYAML_FORMAT_ID)
                {
                    continue;
                }

                object? propValue = null;
                try
                {
                    propValue = prop.Value;
                }
                catch (GetValueInvocationException e)
                {
                    propValue = e.Message;
                }
                catch (GetValueException)
                {
                    // PowerShell fails to get ByRef struct values. We can do a bit
                    // more to convert Span<T> types to an array.
                    PropertyInfo? propTypeInfo = baseObj.GetType().GetProperty(prop.Name);
                    Type? propType = propTypeInfo?.PropertyType;
                    if (
                        propType is not null &&
                        (IsGenericType(propType, typeof(Span<>)) ||
                        IsGenericType(propType, typeof(ReadOnlySpan<>)))
                    )
                    {
                        propValue = ReflectionHelper.SpanToArray(baseObj, propTypeInfo!);
                    }
                    else
                    {
                        throw;
                    }
                }

                model[prop.Name] = propValue;
            }

            EmitMap(model, formatProp?.CollectionStyle, emitter, depth - 1);
        }
    }

    private void EmitScalar(ScalarValue value, ScalarStyle? style, IEmitter emitter)
    {
        YamlDotNet.Core.ScalarStyle finalStyle = (YamlDotNet.Core.ScalarStyle)(int)value.Style;
        if (style is not null && style != ScalarStyle.Any)
        {
            finalStyle = (YamlDotNet.Core.ScalarStyle)(int)style;
        }

        Scalar toEmit = new(
            AnchorName.Empty,
            value.Tag,
            value.Value,
            finalStyle,
            string.IsNullOrWhiteSpace(value.Tag),
            false);
        emitter.Emit(toEmit);
    }

    private void EmitMap(IDictionary value, CollectionStyle? style, IEmitter emitter, int depth)
        => EmitMap(_schema.EmitMap(value), style, emitter, depth);

    private void EmitMap(MapValue value, CollectionStyle? style, IEmitter emitter, int depth)
    {
        MappingStyle finalStyle = (MappingStyle)(int)value.Style;
        if (style is not null && style != CollectionStyle.Any)
        {
            finalStyle = (MappingStyle)(int)style;
        }
        emitter.Emit(new MappingStart(AnchorName.Empty, TagName.Empty, true, finalStyle));
        foreach (DictionaryEntry entry in value.Values)
        {
            PSObject? entryKey = null;
            if (entry.Key != NullKey.Value)
            {
                entryKey = SchemaHelpers.GetPSObject(entry.Key);
            }
            EmitValue(entryKey, emitter, depth);
            EmitValue(SchemaHelpers.GetPSObject(entry.Value), emitter, depth);
        }
        emitter.Emit(new MappingEnd());
    }

    private void EmitSequence(IList values, CollectionStyle? style, IEmitter emitter, int depth)
        => EmitSequence(_schema.EmitSequence(values.Cast<object?>().ToArray()), style, emitter, depth);

    private void EmitSequence(SequenceValue value, CollectionStyle? style, IEmitter emitter, int depth)
    {
        SequenceStyle finalStyle = (SequenceStyle)(int)value.Style;
        if (style is not null && style != CollectionStyle.Any)
        {
            finalStyle = (SequenceStyle)(int)style;
        }

        emitter.Emit(new SequenceStart(AnchorName.Empty, TagName.Empty, true, finalStyle));
        foreach (object? v in value.Values)
        {
            EmitValue(SchemaHelpers.GetPSObject(v), emitter, depth);
        }
        emitter.Emit(new SequenceEnd());
    }

    private static bool IsGenericType(Type objType, Type genericType)
        => objType.IsGenericType && objType.GetGenericTypeDefinition() == genericType;
}
