using System;
using System.Collections;
using System.Collections.Generic;
using System.Management.Automation;

namespace Yayaml;

public abstract class YamlSchema
{
    public abstract Dictionary<string, Func<string, object?>> GetSchema();
}

/// <summary>
/// Custom YAML Schema. Can be used to define custom tag transformers outside
/// of any of the known schemas.
/// </summary>
public sealed class CustomSchema : YamlSchema
{
    private Dictionary<string, Func<string, object?>> _schema;

    public CustomSchema(Dictionary<string, Func<string, object?>> schema)
    {
        _schema = schema;
    }

    public override Dictionary<string, Func<string, object?>> GetSchema() => _schema;
}

/// <summary>YAML 1.1 Types Schema.</summary>
/// <see href="https://yaml.org/type/">YAML 1.1 Types</see>
public sealed class Yaml11 : YamlSchema
{
    private Dictionary<string, Func<string, object?>> _schema = new()
    {
        { "tag:yaml.org,2002:bool", ParseBool },
        { "tag:yaml.org,2002:int", ParseInt },
        { "tag:yaml.org,2002:float", ParseFloat },
        { "tag:yaml.org,2002:null", ParseNull },
        { "tag:yaml.org,2002:binary", ParseBinary },
        { "tag:yaml.org,2002:timestamp", ParseTimestamp },
        { "?", ParseUntagged },
    };

    public override Dictionary<string, Func<string, object?>> GetSchema() => _schema;

    private static object? ParseBool(string value)
    {
        return false;
    }

    private static object? ParseInt(string value)
    {
        return 0;
    }

    private static object? ParseFloat(string value)
    {
        return false;
    }

    private static object? ParseNull(string value)
    {
        return null;
    }

    private static object? ParseBinary(string value)
    {
        return null;
    }

    private static object? ParseTimestamp(string value)
    {
        return null;
    }

    private static object? ParseUntagged(string value)
    {
        return value;
    }
}

/// <summary>YAML 1.2 Core Schema.</summary>
/// <see href="https://yaml.org/spec/1.2-old/spec.html#id2804923">YAML 1.2 Core Schema</see>
public sealed class Yaml12 : YamlSchema
{
    private Dictionary<string, Func<string, object?>> _schema = new()
    {
        { "tag:yaml.org,2002:bool", ParseBool },
        { "tag:yaml.org,2002:int", ParseInt },
        { "tag:yaml.org,2002:float", ParseFloat },
        { "tag:yaml.org,2002:null", ParseNull },
        { "tag:yaml.org,2002:str", (s => s) },
        { "?", ParseUntagged },
    };

    public override Dictionary<string, Func<string, object?>> GetSchema() => _schema;

    private static object? ParseBool(string value)
    {
        return false;
    }

    private static object? ParseInt(string value)
    {
        return 0;
    }

    private static object? ParseFloat(string value)
    {
        return false;
    }

    private static object? ParseNull(string value)
    {
        return null;
    }

    private static object? ParseUntagged(string value)
    {
        return value;
    }
}


/// <summary>YAML 1.2 JSON Schema.</summary>
/// <see href="https://yaml.org/spec/1.2-old/spec.html#id2803231">YAML 1.2 JSON Schema</see>
public sealed class Yaml12JSON : YamlSchema
{
    private Dictionary<string, Func<string, object?>> _schema = new()
    {
        { "tag:yaml.org,2002:bool", ParseBool },
        { "tag:yaml.org,2002:int", ParseInt },
        { "tag:yaml.org,2002:float", ParseFloat },
        { "tag:yaml.org,2002:null", ParseNull },
        { "?", ParseUntagged },
    };

    public override Dictionary<string, Func<string, object?>> GetSchema() => _schema;

    private static object? ParseBool(string value)
    {
        return false;
    }

    private static object? ParseInt(string value)
    {
        return 0;
    }

    private static object? ParseFloat(string value)
    {
        return false;
    }

    private static object? ParseNull(string value)
    {
        return null;
    }

    private static object? ParseUntagged(string value)
    {
        return value;
    }
}

public sealed class SchemaTransformer: ArgumentTransformationAttribute
{
    public override object Transform(EngineIntrinsics engineIntrinsics,
        object? inputData)
    {
        if (inputData is PSObject objPS)
        {
            inputData = objPS.BaseObject;
        }

        return inputData switch
        {
            YamlSchema schema => schema,
            IDictionary dict => ConvertToSchema(dict),
            _ => throw new ArgumentTransformationMetadataException(
                $"Could not convert input '{inputData}' to schema object"),
        };
    }

    private YamlSchema ConvertToSchema(IDictionary dict)
    {
        Dictionary<string, Func<string, object?>> schema = new();
        foreach (DictionaryEntry entry in dict)
        {
            string tag = entry.Key.ToString() ?? "";

            if (entry.Value is Func<string, object?> convert)
            {
                schema[tag] = convert;
            }
            else
            {
                throw new ArgumentTransformationMetadataException(
                    $"Schema value for '{tag}' must be a ScriptBlock that accepts a string");
            }
        }

        return new CustomSchema(schema);
    }
}
