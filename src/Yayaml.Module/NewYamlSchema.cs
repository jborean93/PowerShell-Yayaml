using System.Management.Automation;

namespace Yayaml.Module;

[Cmdlet(VerbsCommon.New, "YamlSchema")]
[OutputType(typeof(YamlSchema))]
public sealed class NewYamlSchemaCommand : PSCmdlet
{
    [Parameter]
    public MapEmitter? EmitMap { get; set; }

    [Parameter]
    public ScalarEmitter? EmitScalar { get; set; }

    [Parameter]
    public SequenceEmitter? EmitSequence { get; set; }

    [Parameter]
    public TransformEmitter? EmitTransformer { get; set; }

    [Parameter]
    public IsScalarCheck? IsScalar { get; set; }

    [Parameter]
    public MapParser? ParseMap { get; set; }

    [Parameter]
    public ScalarParser? ParseScalar { get; set; }

    [Parameter]
    public SequenceParser? ParseSequence { get; set; }

    [Parameter]
#if NET6_0_OR_GREATER
    [YamlSchemaCompletions]
#else
    [ArgumentCompleter(typeof(YamlSchemaCompletionsAttribute))]
#endif
    [SchemaParameterTransformer]
    public YamlSchema? BaseSchema { get; set; }

    protected override void EndProcessing()
    {
        YamlSchema? baseSchema = BaseSchema ?? YamlSchema.CreateDefault();

        if (
            IsScalar == null &&
            EmitMap == null &&
            EmitScalar == null &&
            EmitSequence == null &&
            EmitTransformer == null &&
            ParseMap == null &&
            ParseScalar == null &&
            ParseSequence == null
        )
        {
            WriteObject(baseSchema);
        }
        else
        {
            CustomSchema finalSchema = new(
                baseSchema,
                isScalar: IsScalar,
                mapEmitter: EmitMap,
                scalarEmitter: EmitScalar,
                sequenceEmitter: EmitSequence,
                transformEmitter: EmitTransformer,
                mapParser: ParseMap,
                scalarParser: ParseScalar,
                sequenceParser: ParseSequence
            );
            WriteObject(finalSchema);
        }
    }
}
