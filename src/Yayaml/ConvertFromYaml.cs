using Yayaml.Shared;
using System;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Management.Automation;
using System.Text;

namespace Yayaml;

[Cmdlet(VerbsData.ConvertFrom, "Yaml")]
// [OutputType(typeof(OrderedDictionary))]
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
        // TomlTable table;
        // try
        // {
        //     table = TOMLLib.ConvertFromToml(toml);
        // }
        // catch (Exception e)
        // {
        //     WriteError(new ErrorRecord(
        //         e,
        //         "ParseError",
        //         ErrorCategory.NotSpecified,
        //         toml
        //     ));
        //     return;
        // }

        // OrderedDictionary result = ConvertToOrderedDictionary(table);
        // WriteObject(result);
    }
}
