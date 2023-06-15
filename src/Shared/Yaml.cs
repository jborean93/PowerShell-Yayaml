using System;
using System.Collections;
using System.Collections.Generic;
using System.Management.Automation;
using YamlDotNet.Serialization;

namespace Yayaml.Shared;

internal sealed class YamlConverter
{
    public bool WasTruncated { get; set; }

    public YamlConverter()
    { }

    public object? ConvertToYamlObject(object? inputObject, int depth)
    {
        if (inputObject == null)
        {
            return "";
        }

        if (depth < 0)
        {
            WasTruncated = true;
            return inputObject?.ToString() ?? "";
        }

        return inputObject switch
        {
            IDictionary dict => ConvertToTomlTable(dict, depth),
            Array array => ConvertToTomlArray(array, depth),
            _ => ConvertToTomlFriendlyObject(inputObject, depth),
        };
    }

    private List<object?> ConvertToTomlArray(Array array, int depth)
    {
        List<object?> result = new();

        foreach (object value in array)
        {
            result.Add(ConvertToYamlObject(value, depth - 1));
        }

        return result;
    }

    private Dictionary<object, object?> ConvertToTomlTable(IDictionary dict, int depth)
    {
        Dictionary<object, object?> model = new();
        foreach (DictionaryEntry entry in dict)
        {
            object? value = ConvertToYamlObject(entry.Value ?? "", depth - 1);
            model.Add(entry.Key, value);
        }

        return model;
    }

    private object? ConvertToTomlFriendlyObject(object? obj, int depth)
    {
        if (obj is PSObject psObj)
        {
            obj = psObj.BaseObject;
        }
        else
        {
            psObj = PSObject.AsPSObject(obj);
        }

        if (obj is char || obj is Guid)
        {
            return obj.ToString() ?? "";
        }
        else if (obj is Enum enumObj)
        {
            return Convert.ChangeType(enumObj, enumObj.GetTypeCode());
        }

        if (
            obj is bool ||
            obj is DateTime ||
            obj is DateTimeOffset ||
            obj is sbyte ||
            obj is byte ||
            obj is Int16 ||
            obj is UInt16 ||
            obj is Int32 ||
            obj is UInt32 ||
            obj is Int64 ||
            obj is UInt64 ||
            obj is float ||
            obj is double ||
            obj is string
        )
        {
            return obj;
        }

        Dictionary<object, object?> model = new();
        foreach (PSPropertyInfo prop in psObj.Properties)
        {
            object? propValue = null;
            try
            {
                propValue = prop.Value;
            }
            catch (GetValueInvocationException e)
            {
                propValue = e.Message;
            }

            model[prop.Name] = ConvertToYamlObject(propValue, depth - 1);
        }

        return model;
    }
}

public static class YAMLLib
{
    public static object ConvertFromYaml(string yaml)
    {
        DeserializerBuilder builder = new DeserializerBuilder();

        return builder.Build().Deserialize(yaml);
    }

    public static string ConvertToYaml(object? inputObject, int depth, out bool wasTruncated)
    {
        YamlConverter converter = new();
        object? finalObject = converter.ConvertToYamlObject(inputObject, depth);
        wasTruncated = converter.WasTruncated;

        SerializerBuilder builder = new SerializerBuilder();
        return builder.Build().Serialize(finalObject);
    }
}
