using System;
using System.Collections.Generic;
using System.Management.Automation;
using System.Text;
using Yayaml.Shared;

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

    protected override void ProcessRecord()
    {
        foreach (string toml in InputObject)
        {
            _inputValues.AppendLine(toml);
        }
    }

    protected override void EndProcessing()
    {
        string yaml = _inputValues.ToString();
        List<object?> obj = YAMLLib.ConvertFromYaml(yaml);

        if (NoEnumerate)
        {
            WriteObject(obj.ToArray());
        }
        else
        {
            foreach (object? entry in obj)
            {
                WriteObject(entry);
            }
        }
    }
}
