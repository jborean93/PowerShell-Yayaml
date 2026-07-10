using System.Management.Automation;

namespace Yayaml;

[Cmdlet(VerbsData.ConvertTo, "Yaml")]
[OutputType(typeof(string))]
public sealed class ConvertToYamlCommand : ToYamlBaseCommand
{
    [Parameter(
        Mandatory = true,
        Position = 0,
        ValueFromPipeline = true,
        ValueFromPipelineByPropertyName = true
    )]
    [AllowNull]
    public override PSObject? InputObject { get; set; } = null;

    protected override void ProcessYaml(string yaml)
    {
        WriteObject(yaml);
    }
}
