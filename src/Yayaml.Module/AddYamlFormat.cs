using System.Management.Automation;

namespace Yayaml.Module;

[Cmdlet(VerbsCommon.Add, "YamlFormat")]
public sealed class AddYamlFormatCommand : PSCmdlet
{
    [Parameter(
        Mandatory = true,
        Position = 0,
        ValueFromPipeline = true,
        ValueFromPipelineByPropertyName = true
    )]
    public PSObject InputObject { get; set; } = new PSObject();

    [Parameter]
    public ScalarStyle ScalarStyle { get; set; }

    [Parameter]
    public CollectionStyle CollectionStyle { get; set; }

    [Parameter]
    public SwitchParameter PassThru { get; set; }

    [Parameter]
    public string? Comment { get; set; }

    [Parameter]
    public string? PreComment { get; set; }

    [Parameter]
    public string? PostComment { get; set; }

    protected override void ProcessRecord()
    {
        YayamlFormat format = new(CollectionStyle, ScalarStyle, Comment, PreComment, PostComment);
        InputObject.Properties.Add(new PSNoteProperty(SchemaHelpers.YAYAML_FORMAT_ID, format));

        if (PassThru)
        {
            WriteObject(InputObject);
        }
    }
}
