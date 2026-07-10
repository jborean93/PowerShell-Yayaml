using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Management.Automation;
using YamlDotNet.Serialization;

namespace Yayaml;

public abstract class ToYamlBaseCommand : PSCmdlet
{
    private List<PSObject?> _data = [];
    private ISerializer? _serializer;

    protected static int InputPosition = 0;

    public abstract PSObject? InputObject { get; set; }

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

    protected abstract void ProcessYaml(string yaml);

    private void SerializeAndWrite(object? obj)
    {
        Debug.Assert(_serializer is not null, "Serializer should be initialized in BeginProcessing");

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
        ProcessYaml(res);
    }
}
