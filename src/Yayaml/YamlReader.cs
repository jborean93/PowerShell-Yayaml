using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.IO;
using System.Management.Automation;
using System.Reflection;
using System.Text;
using YamlDotNet.Core;
using YamlDotNet.RepresentationModel;
using YamlDotNet.Serialization;

namespace Yayaml;

internal sealed class YamlReader
{
    public static void EmitYaml(
        TextReader reader,
        YamlSchema schema,
        PSCmdlet cmdlet,
        bool noEnumerate,
        string? rawYaml = null)
    {
        try
        {
            foreach (object? entry in ConvertFromYaml(reader, schema))
            {
                bool enumerate = !(noEnumerate && entry is object[]);
                cmdlet.WriteObject(entry, enumerate);
            }
        }
        catch (YamlParseException e)
        {
            Hashtable? targetInfo = null;
            if (!string.IsNullOrWhiteSpace(rawYaml))
            {
                targetInfo = new Hashtable()
                {
                    // PowerShell uses these properties to give a nicer
                    // error message with the position of the error in the
                    // message.
                    { "Line", e.StartLine },
                    { "LineText", rawYaml },
                    // Support for columns were added in PS 7.7, it is
                    // ignored on older versions.
                    { "StartColumn", e.StartColumn },
                    { "EndColumn", e.EndColumn }
                };
            }

            ErrorRecord err = new(
                e,
                "YamlParseError",
                ErrorCategory.ParserError,
                targetInfo);

            cmdlet.WriteError(err);
        }
        catch (Exception e)
        {
            ErrorRecord err = new(
                e,
                "YamlError",
                ErrorCategory.NotSpecified,
                null);
            cmdlet.WriteError(err);
        }
    }

    private static IEnumerable<object?> ConvertFromYaml(
        TextReader reader,
        YamlSchema schema)
    {
        Parser parser = new(reader);
        YamlStream yamlStream = new();
        try
        {
            yamlStream.Load(parser);
        }
        catch (SemanticErrorException e)
        {
            throw new YamlParseException(
                e.Message,
                (int)e.Start.Line,
                (int)e.Start.Column,
                (int)e.End.Line,
                (int)e.End.Column,
                e);
        }

        foreach (YamlDocument entry in yamlStream)
        {
            yield return ConvertFromYamlNode(entry.RootNode, schema);
        }
    }

    private static object? ConvertFromYamlNode(
        YamlNode node,
        YamlSchema schema) => node switch
        {
            YamlMappingNode mapping => ConvertFromYamlMappingNode(mapping, schema),
            YamlSequenceNode sequence => ConvertFromYamlSequenceNode(sequence, schema),
            YamlScalarNode scalar => ConvertFromYamlScalarNode(scalar, schema),
            _ => throw new NotImplementedException(""),
        };

    private static object? ConvertFromYamlMappingNode(
        YamlMappingNode node,
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
            Tag = node.Tag.ToString(),
        });
    }

    private static object? ConvertFromYamlSequenceNode(
        YamlSequenceNode node,
        YamlSchema schema)
    {
        List<object?> res = [];
        foreach (YamlNode childNode in node)
        {
            res.Add(ConvertFromYamlNode(childNode, schema));
        }

        return schema.ParseSequence(new SequenceValue(res.ToArray())
        {
            Style = (CollectionStyle)node.Style,
            Tag = node.Tag.ToString(),
        });
    }

    private static object? ConvertFromYamlScalarNode(
        YamlScalarNode node,
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
                (int)node.Start.Line,
                (int)node.Start.Column,
                (int)node.End.Line,
                (int)node.End.Column,
                e);
        }
    }
}
