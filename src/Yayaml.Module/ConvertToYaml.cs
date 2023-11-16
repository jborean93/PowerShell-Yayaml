using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Linq;
using System.Management.Automation;
using System.Reflection;
using YamlDotNet.Core.Events;
using YamlDotNet.Serialization;
using YamlDotNet.RepresentationModel;

namespace Yayaml.Module;

[Cmdlet(VerbsData.ConvertTo, "Yaml")]
[OutputType(typeof(string))]
public sealed class ConvertToYamlCommand : PSCmdlet
{
    private List<YamlNode> _data = new();
    private bool _emittedDepthWarning = false;
    private YamlSchema? _schema = null;

    [Parameter(
        Mandatory = true,
        Position = 0,
        ValueFromPipeline = true,
        ValueFromPipelineByPropertyName = true
    )]
    [AllowNull]
    public PSObject? InputObject { get; set; } = null;

    [Parameter]
    public SwitchParameter AsArray { get; set; }

    [Parameter]
    public int Depth { get; set; } = 2;

    [Parameter]
    public SwitchParameter IndentSequence { get; set; }

    [Parameter]
#if CORE
    [YamlSchemaCompletions]
#else
    [ArgumentCompleter(typeof(YamlSchemaCompletionsAttribute))]
#endif
    [SchemaParameterTransformer]
    public YamlSchema? Schema { get; set; }

    protected override void BeginProcessing()
    {
        _schema = Schema ?? YamlSchema.CreateDefault();
    }

    protected override void ProcessRecord()
    {
        YamlConverter converter = new(_schema ?? YamlSchema.CreateDefault());
        _data.Add(converter.ConvertToYamlObject(InputObject, Depth));

        if (converter.WasTruncated && !_emittedDepthWarning)
        {
            _emittedDepthWarning = true;
            WriteWarning($"Resulting YAML is truncated as serialization has exceeded the set depth of {Depth}");
        }
    }

    protected override void EndProcessing()
    {
        SerializerBuilder builder = new SerializerBuilder();
        if (IndentSequence)
        {
            builder = builder.WithIndentedSequences();
        }
        ISerializer serializer = builder.Build();
        object? toSerialize = _data.Count == 1 && !AsArray ? _data[0] : _data;

        try
        {
            string res = serializer.Serialize(toSerialize);
            // Remove the newline added to the end
            res = res.Substring(0, res.Length - Environment.NewLine.Length);
            WriteObject(res);
        }
        catch (Exception e)
        {
            WriteError(new ErrorRecord(
                e,
                "InputObjectInvalid",
                ErrorCategory.InvalidArgument,
                toSerialize
            ));
        }
    }
}

internal sealed class YamlConverter
{
    private YamlSchema _schema;

    public bool WasTruncated { get; set; }

    public YamlConverter(YamlSchema schema)
    {
        _schema = schema;
    }

    public YamlNode ConvertToYamlObject(PSObject? inputObject, int depth)
    {
        inputObject = _schema.EmitTransformer(inputObject);
        if (inputObject == null)
        {
            ScalarValue nullValue = _schema.EmitScalar(null);
            return GetScalarNode(nullValue);
        }

        YamlNode node;
        if (inputObject.BaseObject is MapValue map)
        {
            node = ConvertToYamlMap(map, depth);
        }
        else if (inputObject.BaseObject is ScalarValue scalar)
        {
            node = GetScalarNode(scalar);
        }
        else if (inputObject.BaseObject is SequenceValue sequence)
        {
            node = ConvertToYamlSequence(sequence, depth);
        }
        else
        {
            node = ConvertToYamlNode(inputObject, depth);
        }

        YayamlFormat? formatProp = SchemaHelpers.GetYayamlFormatProperty(inputObject);
        if (formatProp == null)
        {
            return node;
        }

        if (node is YamlMappingNode mapNode && formatProp.CollectionStyle != CollectionStyle.Any)
        {
            mapNode.Style = (MappingStyle)(int)formatProp.CollectionStyle;
        }
        else if (node is YamlSequenceNode seqNode && formatProp.CollectionStyle != CollectionStyle.Any)
        {
            seqNode.Style = (SequenceStyle)(int)formatProp.CollectionStyle;
        }
        else if (node is YamlScalarNode scalarNode && formatProp.ScalarStyle != ScalarStyle.Any)
        {
            scalarNode.Style = (YamlDotNet.Core.ScalarStyle)(int)formatProp.ScalarStyle;
        }

        return node;
    }

    private YamlMappingNode ConvertToYamlMap(IDictionary dict, int depth)
        => ConvertToYamlMap(_schema.EmitMap(dict), depth);

    private YamlMappingNode ConvertToYamlMap(MapValue value, int depth)
    {
        YamlMappingNode node = new()
        {
            Style = (MappingStyle)(int)value.Style,
        };

        foreach (DictionaryEntry entry in value.Values)
        {
            PSObject? entryKey = null;
            if (entry.Key != NullKey.Value)
            {
                entryKey = SchemaHelpers.GetPSObject(entry.Key);
            }
            PSObject? entryValue = SchemaHelpers.GetPSObject(entry.Value);

            node.Add(
                ConvertToYamlObject(entryKey, depth),
                ConvertToYamlObject(entryValue, depth)
            );
        }

        return node;
    }

    private YamlSequenceNode ConvertToYamlSequence(IList values, int depth)
        => ConvertToYamlSequence(_schema.EmitSequence(values.Cast<object?>().ToArray()), depth);

    private YamlSequenceNode ConvertToYamlSequence(SequenceValue value, int depth)
    {
        YamlSequenceNode node = new()
        {
            Style = (SequenceStyle)(int)value.Style,
        };

        foreach (object? v in value.Values)
        {
            node.Add(ConvertToYamlObject(SchemaHelpers.GetPSObject(v), depth));
        }

        return node;
    }

    private YamlNode ConvertToYamlNode(PSObject obj, int depth)
    {
        object baseObj = obj.BaseObject;

        if (
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
            ScalarValue toEmit = _schema.EmitScalar(baseObj is string ? obj : baseObj);
            return GetScalarNode(toEmit);
        }

        if (depth < 0)
        {
            WasTruncated = true;
            string strValue = LanguagePrimitives.ConvertTo<string>(baseObj);
            ScalarValue stringValue = _schema.EmitScalar(strValue);
            return GetScalarNode(stringValue);
        }

        if (baseObj is IList list)
        {
            return ConvertToYamlSequence(list, depth - 1);
        }
        else if (baseObj is IDictionary dict)
        {
            return ConvertToYamlMap(dict, depth - 1);
        }
        else if (
            IsGenericType(baseObj.GetType(), typeof(Memory<>)) ||
            IsGenericType(baseObj.GetType(), typeof(ReadOnlyMemory<>))
        )
        {
            MethodInfo toArrayMeth = baseObj.GetType().GetMethod(
                "ToArray",
                BindingFlags.Public | BindingFlags.Instance)!;

            return ConvertToYamlSequence(
                (Array)toArrayMeth.Invoke(baseObj, Array.Empty<object>())!,
                depth - 1);
        }

        // Treat any other type as a map and process accordingly.
        OrderedDictionary model = new();
        foreach (PSPropertyInfo prop in obj.Properties)
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
                if (propTypeInfo == null)
                {
                    throw;
                }

                Type propType = propTypeInfo.PropertyType;
                if (
                    IsGenericType(propType, typeof(Span<>)) ||
                    IsGenericType(propType, typeof(ReadOnlySpan<>))
                )
                {
                    propValue = ReflectionHelper.SpanToArray(baseObj, propTypeInfo);
                }
                else
                {
                    throw;
                }
            }

            model[prop.Name] = propValue;
        }

        return ConvertToYamlMap(model, depth - 1);
    }

    private YamlScalarNode GetScalarNode(ScalarValue value)
    {
        YamlScalarNode node = new(value.Value)
        {
            Style = (YamlDotNet.Core.ScalarStyle)(int)value.Style,
        };
        if (!string.IsNullOrWhiteSpace(value.Tag))
        {
            node.Tag = new(value.Tag!);
        }

        return node;
    }

    private static bool IsGenericType(Type objType, Type genericType)
        => objType.IsGenericType && objType.GetGenericTypeDefinition() == genericType;
}
