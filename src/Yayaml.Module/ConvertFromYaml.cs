using System;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.IO;
using System.Management.Automation;
using System.Management.Automation.Language;
using System.Reflection;
using System.Text;
using YamlDotNet.Core;
using YamlDotNet.RepresentationModel;
using YamlDotNet.Serialization;

namespace Yayaml.Module;

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
        List<object?> obj;
        try
        {
            obj = ConvertFromYaml(yaml, schema);
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
            ScriptPosition start = new("", e.StartLine, e.StartColumn, lines[e.StartLine - 1]);
            ScriptPosition end = new("", e.EndLine, e.EndColumn, lines[e.EndLine - 1]);
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

        foreach (object? entry in obj)
        {
            bool enumerate = !(NoEnumerate && entry is object[]);
            WriteObject(entry, enumerate);
        }
    }

    private static List<object?> ConvertFromYaml(string yaml,
        YamlSchema schema)
    {
        using StringReader reader = new(yaml);
        YamlDotNet.Core.Parser parser = new(reader);
        YamlStream yamlStream = new();
        try
        {
            yamlStream.Load(parser);
        }
        catch (SemanticErrorException e)
        {
            throw new YamlParseException(e.Message, (int)e.Start.Line, (int)e.Start.Column,
                (int)e.End.Line, (int)e.End.Column, e);
        }

        List<object?> results = new();
        foreach (YamlDocument entry in yamlStream)
        {
            results.Add(ConvertFromYamlNode(entry.RootNode, schema));
        }

        return results;
    }

    private static object? ConvertFromYamlNode(YamlNode node,
        YamlSchema schema) => node switch
        {
            YamlMappingNode mapping => ConvertFromYamlMappingNode(mapping, schema),
            YamlSequenceNode sequence => ConvertFromYamlSequenceNode(sequence, schema),
            YamlScalarNode scalar => ConvertFromYamlScalarNode(scalar, schema),
            _ => throw new NotImplementedException(""),
        };

    private static object? ConvertFromYamlMappingNode(YamlMappingNode node,
        YamlSchema schema)
    {
        OrderedDictionary res = new();
        foreach (KeyValuePair<YamlNode, YamlNode> kvp in node)
        {
            object? key = ConvertFromYamlNode(kvp.Key, schema);
            object? value = ConvertFromYamlNode(kvp.Value, schema);
            res[key ?? NullKey.Value] = value;
        }

        return schema.ParseMap(new MapValue()
        {
            Values = res,
            Style = (CollectionStyle)node.Style,
        });
    }

    private static object? ConvertFromYamlSequenceNode(YamlSequenceNode node,
        YamlSchema schema)
    {
        List<object?> res = new();
        foreach (YamlNode childNode in node)
        {
            res.Add(ConvertFromYamlNode(childNode, schema));
        }

        return schema.ParseSequence(new SequenceValue(res.ToArray())
        {
            Style = (CollectionStyle)node.Style,
        });
    }

    private static object? ConvertFromYamlScalarNode(YamlScalarNode node,
        YamlSchema schema)
    {
        ScalarValue value = new(node.Value ?? "")
        {
            Style = (ScalarStyle)node.Style,
            Tag = node.Tag.ToString(),
        };

        try
        {
            return schema.ParseScalar(value);
        }
        catch (ArgumentException e)
        {
            throw new YamlParseException(
                $"Failed to unpack yaml node '{value.Value}' with tag '{value.Tag}': {e.Message}",
                (int)node.Start.Line, (int)node.Start.Column, (int)node.End.Line, (int)node.End.Column, e);
        }
    }
}
