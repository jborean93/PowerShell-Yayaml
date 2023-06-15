using Yayaml.Shared;
using System;
using System.Collections.Generic;
using System.Management.Automation;

namespace Yayaml;

[Cmdlet(VerbsData.ConvertTo, "Yaml")]
[OutputType(typeof(string))]
public sealed class ConvertToYamlCommand : PSCmdlet
{
    private List<object?> _data = new();

    [Parameter(
        Mandatory = true,
        Position = 0,
        ValueFromPipeline = true,
        ValueFromPipelineByPropertyName = true
    )]
    [AllowNull]
    public object?[] InputObject { get; set; } = Array.Empty<object>();

    [Parameter]
    public int Depth { get; set; } = 2;

    protected override void ProcessRecord()
    {
        _data.AddRange(InputObject);
    }

    protected override void EndProcessing()
    {
        string res;
        bool wasTruncated = false;
        try
        {
            res = YAMLLib.ConvertToYaml(_data, Depth, out wasTruncated);
        }
        catch (Exception e)
        {
            WriteError(new ErrorRecord(
                e,
                "InputObjectInvalid",
                ErrorCategory.InvalidArgument,
                _data
            ));
            return;
        }

        if (wasTruncated)
        {
            WriteWarning($"Resulting YAML is truncated as serialization has exceeded the set depth of {Depth}");
        }

        WriteObject(res);
    }
}
