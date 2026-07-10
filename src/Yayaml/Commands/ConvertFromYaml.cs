using System;
using System.IO;
using System.Management.Automation;
using System.Text;

namespace Yayaml;

[Cmdlet(VerbsData.ConvertFrom, "Yaml")]
public sealed class ConvertFromYamlCommand : PSCmdlet
{
    private StringBuilder _inputValues = new();

    [Parameter(
        Mandatory = true,
        Position = 0,
        ValueFromPipeline = true,
        ValueFromPipelineByPropertyName = true
    )]
    [AllowEmptyString]
    public string[] InputObject { get; set; } = Array.Empty<string>();

    [Parameter]
    public SwitchParameter NoEnumerate { get; set; }

    [Parameter]
#if NET6_0_OR_GREATER
    [YamlSchemaCompletions]
#else
    [ArgumentCompleter(typeof(YamlSchemaCompletionsAttribute))]
#endif
    [SchemaParameterTransformer]
    public YamlSchema? Schema { get; set; }

    protected override void ProcessRecord()
    {
        foreach (string toml in InputObject)
        {
            _inputValues.AppendLine(toml);
        }
    }

    protected override void EndProcessing()
    {
        YamlSchema schema = Schema ?? YamlSchema.CreateDefault();

        string yaml = _inputValues.ToString();
        using StringReader reader = new(yaml);
        YamlReader.EmitYaml(reader, schema, this, NoEnumerate, rawYaml: yaml);
    }
}
