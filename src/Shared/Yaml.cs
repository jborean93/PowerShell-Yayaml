using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.IO;
using System.Management.Automation;
using System.Numerics;
using System.Text;
using YamlDotNet.Core;
using YamlDotNet.RepresentationModel;
using YamlDotNet.Serialization;

namespace Yayaml.Shared;

// internal sealed class YamlConverter
// {
//     public bool WasTruncated { get; set; }

//     public YamlConverter()
//     { }

//     public object? ConvertToYamlObject(object? inputObject, int depth)
//     {
//         if (inputObject == null)
//         {
//             return "";
//         }

//         if (depth < 0)
//         {
//             WasTruncated = true;
//             return inputObject?.ToString() ?? "";
//         }

//         return inputObject switch
//         {
//             IDictionary dict => ConvertToTomlTable(dict, depth),
//             Array array => ConvertToTomlArray(array, depth),
//             _ => ConvertToTomlFriendlyObject(inputObject, depth),
//         };
//     }

//     private List<object?> ConvertToTomlArray(Array array, int depth)
//     {
//         List<object?> result = new();

//         foreach (object value in array)
//         {
//             result.Add(ConvertToYamlObject(value, depth - 1));
//         }

//         return result;
//     }

//     private Dictionary<object, object?> ConvertToTomlTable(IDictionary dict, int depth)
//     {
//         Dictionary<object, object?> model = new();
//         foreach (DictionaryEntry entry in dict)
//         {
//             object? value = ConvertToYamlObject(entry.Value ?? "", depth - 1);
//             model.Add(entry.Key, value);
//         }

//         return model;
//     }

//     private object? ConvertToTomlFriendlyObject(object? obj, int depth)
//     {
//         if (obj is PSObject psObj)
//         {
//             obj = psObj.BaseObject;
//         }
//         else
//         {
//             psObj = PSObject.AsPSObject(obj);
//         }

//         if (obj is char || obj is Guid)
//         {
//             return obj.ToString() ?? "";
//         }
//         else if (obj is Enum enumObj)
//         {
//             return Convert.ChangeType(enumObj, enumObj.GetTypeCode());
//         }

//         if (
//             obj is bool ||
//             obj is DateTime ||
//             obj is DateTimeOffset ||
//             obj is sbyte ||
//             obj is byte ||
//             obj is Int16 ||
//             obj is UInt16 ||
//             obj is Int32 ||
//             obj is UInt32 ||
//             obj is Int64 ||
//             obj is UInt64 ||
//             obj is float ||
//             obj is double ||
//             obj is string
//         )
//         {
//             return obj;
//         }

//         Dictionary<object, object?> model = new();
//         foreach (PSPropertyInfo prop in psObj.Properties)
//         {
//             object? propValue = null;
//             try
//             {
//                 propValue = prop.Value;
//             }
//             catch (GetValueInvocationException e)
//             {
//                 propValue = e.Message;
//             }

//             model[prop.Name] = ConvertToYamlObject(propValue, depth - 1);
//         }

//         return model;
//     }
// }

public class YamlParseException : FormatException
{
    public Mark Start { get; }
    public Mark End { get; }

    public YamlParseException(string message, Mark start, Mark end)
        : base(message)
    {
        Start = start;
        End = end;
    }

    public YamlParseException(string message, Mark start, Mark end,
        Exception innerException)
        : base(message, innerException)
    {
        Start = start;
        End = end;
    }
}

public static class YAMLLib
{
    public static List<object?> ConvertFromYaml(string yaml,
        YamlTransformer transformer)
    {
        DeserializerBuilder builder = new DeserializerBuilder();
        IDeserializer deserializer = builder.Build();

        using StringReader reader = new(yaml);
        Parser parser = new(reader);
        MergingParser mergingParser = new(parser);
        YamlStream yamlStream = new();
        try
        {
            yamlStream.Load(mergingParser);
        }
        catch (SemanticErrorException e)
        {
            throw new YamlParseException(e.Message, e.Start, e.End, e);
        }

        List<object?> results = new();
        foreach (YamlDocument entry in yamlStream)
        {
            results.Add(ConvertFromYamlNode(entry.RootNode, transformer));
        }

        return results;
    }

    public static string ConvertToYaml(object? inputObject, int depth, out bool wasTruncated)
    {
        // YamlConverter converter = new();
        // object? finalObject = converter.ConvertToYamlObject(inputObject, depth);
        // wasTruncated = converter.WasTruncated;
        wasTruncated = false;

        SerializerBuilder builder = new SerializerBuilder();
        return builder.Build().Serialize(inputObject);
    }


    private static object? ConvertFromYamlNode(YamlNode node,
        YamlTransformer transformer) => node switch
        {
            null => null,
            YamlMappingNode mapping => ConvertFromYamlMappingNode(mapping, transformer),
            YamlSequenceNode sequence => ConvertFromYamlSequenceNode(sequence, transformer),
            YamlScalarNode scalar => ConvertFromYamlScalarNode(scalar, transformer),
            _ => throw new NotImplementedException(""),
        };

    private static object? ConvertFromYamlMappingNode(YamlMappingNode node,
        YamlTransformer transformer)
    {
        List<KeyValuePair<object?, object?>> res = new();
        foreach (KeyValuePair<YamlNode, YamlNode> kvp in node)
        {
            object? key = ConvertFromYamlNode(kvp.Key, transformer);
            object? value = ConvertFromYamlNode(kvp.Value, transformer);
            res.Add(new KeyValuePair<object?, object?>(key, value));
        }

        return transformer.MappingParser(res.ToArray(), node.Tag.ToString());
    }

    private static object? ConvertFromYamlSequenceNode(YamlSequenceNode node,
        YamlTransformer transformer)
    {
        List<object?> res = new();
        foreach (YamlNode childNode in node)
        {
            res.Add(ConvertFromYamlNode(childNode, transformer));
        }

        return transformer.SequenceParser(res.ToArray(), node.Tag.ToString());
    }

    private static object? ConvertFromYamlScalarNode(YamlScalarNode node,
        YamlTransformer transformer)
    {
        string nodeValue = node.Value ?? "";
        string nodeTag = node.Tag.ToString();

        try
        {
            return transformer.ScalarParser(nodeValue, nodeTag, (ScalarStyle)node.Style);
        }
        catch (ArgumentException e)
        {
            throw new YamlParseException(
                $"Failed to unpack yaml node '{nodeValue}' with tag '{nodeTag}': {e.Message}",
                node.Start, node.End, e);
        }
    }

    private static object? ConvertFromYamlScalarUntaggedValue(string value)
    {
        return value;
    }
}
