using System;
using System.Collections.Generic;
using System.Management.Automation;
using System.Management.Automation.Language;
using System.Reflection;
using System.Text;
using Yayaml.Shared;

namespace Yayaml;

/*
$transformer = New-YamlTransformer -Schema Yaml12Core -Scalar {} -Mapping {} -Sequence {}

ConvertFrom-Yaml '' -Transformer {
    param($Tag, $Value)

    $Value
}

ConvertTo-Yaml '' -Schema {
    param($Tag, $Value)

    $Value.ToString()
}
*/

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
    [SchemaTransformer]
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
        YamlSchema schema = Schema ?? new Yaml12();
        Dictionary<string, Func<string, object?>> schemaTags = schema.GetSchema();

        string yaml = _inputValues.ToString();
        List<object?> obj;
        try
        {
            obj = YAMLLib.ConvertFromYaml(yaml, schemaTags);
        }
        catch (YamlParseException e)
        {
            ErrorRecord err = new(
                e,
                "YamlParseError",
                ErrorCategory.ParserError,
                yaml);

            // By setting the InvocationInfo we get a nice error description
            // in PowerShell with positional details. Unfortunately this is not
            // publicly settable so we have to use reflection.
            string[] lines = yaml.Split(new[] { "\r\n", "\r", "\n" }, StringSplitOptions.None);
            ScriptPosition start = new("", e.Start.Line, e.Start.Column, lines[e.Start.Line - 1]);
            ScriptPosition end = new("", e.End.Line, e.End.Column, lines[e.End.Line - 1]);
            InvocationInfo info = InvocationInfo.Create(
                MyInvocation.MyCommand,
                new ScriptExtent(start, end));
            err.GetType().GetField(
                "_invocationInfo",
                BindingFlags.NonPublic | BindingFlags.Instance)
                ?.SetValue(err, info);

            WriteError(err);
            return;
        }
        catch (Exception e)
        {
            ErrorRecord err = new ErrorRecord(
                e,
                "YamlError",
                ErrorCategory.NotSpecified,
                null);
            WriteError(err);
            return;
        }

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
