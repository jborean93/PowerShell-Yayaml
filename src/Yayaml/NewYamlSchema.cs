using System;
using System.Management.Automation;
using Yayaml.Shared;

namespace Yayaml;

[Cmdlet(VerbsCommon.New, "YamlSchema")]
[OutputType(typeof(YamlSchema))]
public sealed class NewYamlSchemaCommand : PSCmdlet
{
    [Parameter]
    public MapParser? ParseMap { get; set; }

    [Parameter]
    public ScalarParser? ParseScalar { get; set; }

    [Parameter]
    public SequenceParser? ParseSequence { get; set; }

    [Parameter]
    [YamlSchemaCompletions]
    [SchemaParameterTransformer]
    public YamlSchema? BaseSchema { get; set; }

    protected override void EndProcessing()
    {
        YamlSchema? baseSchema = BaseSchema ?? YamlSchema.CreateDefault();

        if (ParseMap == null && ParseScalar == null && ParseSequence == null)
        {
            WriteObject(baseSchema);
        }
        else
        {
            CustomSchema finalSchema = new(
                baseSchema,
                map: null,
                scalar: null,
                sequence: null
            );
            WriteObject(finalSchema);
        }
    }
}
