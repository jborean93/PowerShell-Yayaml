using System;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Management.Automation;

namespace Yayaml;

public class YamlSchema
{
    protected Dictionary<string, Func<string, object?>> Tags { get; set; } = new();

    public virtual object? ParseScalar(string value, string tag)
    {
        if (Tags.TryGetValue(tag, out var transformer))
        {
            return transformer(value);
        }
        else
        {
            return value;
        }
    }

    public virtual object? ParseMap(KeyValuePair<object?, object?>[] values, string tag)
    {
        OrderedDictionary res = new();
        foreach (KeyValuePair<object?, object?> entry in values)
        {
            // FIXME: Allow null keys
            res[entry.Key ?? ""] = entry;
        }

        return res;
    }

    public virtual object? ParseSequence(object?[] values, string tag)
        => values;

    internal static YamlSchema CreateDefault() => new Yaml12Schema();
}

public sealed class CustomSchema : YamlSchema
{
    private YamlSchema _baseSchema;
    private Func<string, string, object?>? _scalar;
    private Func<KeyValuePair<object?, object?>[], string, object?>? _map;
    private Func<object?[], string, object?>? _sequence;

    public CustomSchema(
        YamlSchema baseSchema,
        Func<string, string, object?>? scalar = null,
        Func<KeyValuePair<object?, object?>[], string, object?>? map = null,
        Func<object?[], string, object?>? sequence = null
    )
    {
        _baseSchema = baseSchema;
        _scalar = scalar;
        _map = map;
        _sequence = sequence;
    }

    public override object? ParseScalar(string value, string tag)
    {
        if (Tags.TryGetValue(tag, out var transformer))
        {
            return transformer(value);
        }
        else if (_scalar != null)
        {
            return _scalar(value, tag);
        }
        else
        {
            return value;
        }
    }

    public override object? ParseMap(KeyValuePair<object?, object?>[] values, string tag)
        => (_map ?? _baseSchema.ParseMap)(values, tag);

    public override object? ParseSequence(object?[] values, string tag)
        => (_sequence ?? _baseSchema.ParseSequence)(values, tag);
}

/// <summary>YAML 1.1 Types Schema.</summary>
/// <see href="https://yaml.org/type/">YAML 1.1 Types</see>
public sealed class Yaml11Schema : YamlSchema
{
    public Yaml11Schema()
    {
        Tags = new()
        {
            { "tag:yaml.org,2002:bool", ParseBool },
            { "tag:yaml.org,2002:int", ParseInt },
            { "tag:yaml.org,2002:float", ParseFloat },
            { "tag:yaml.org,2002:null", ParseNull },
            { "tag:yaml.org,2002:binary", ParseBinary },
            { "tag:yaml.org,2002:timestamp", ParseTimestamp },
            { "?", ParseUntagged },
        };
    }

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
public sealed class Yaml12Schema : YamlSchema
{
    public Yaml12Schema()
    {
        Tags = new()
        {
            { "tag:yaml.org,2002:bool", ParseBool },
            { "tag:yaml.org,2002:int", ParseInt },
            { "tag:yaml.org,2002:float", ParseFloat },
            { "tag:yaml.org,2002:null", ParseNull },
            { "tag:yaml.org,2002:str", (s => s) },
            { "?", ParseUntagged },
        };
    }

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
public sealed class Yaml12JSONSchema : YamlSchema
{
    public Yaml12JSONSchema()
    {
        Tags = new()
        {
            { "tag:yaml.org,2002:bool", ParseBool },
            { "tag:yaml.org,2002:int", ParseInt },
            { "tag:yaml.org,2002:float", ParseFloat },
            { "tag:yaml.org,2002:null", ParseNull },
            { "?", ParseUntagged },
        };
    }

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

public class YamlSchemaCompletionsAttribute : ArgumentCompletionsAttribute
{
    public YamlSchemaCompletionsAttribute()
        : base(
            "Blank",
            "Yaml11",
            "Yaml12",
            "Yaml12JSON"
        )
    { }
}

public sealed class SchemaParameterTransformer : ArgumentTransformationAttribute
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
            string schemaType => ConvertToSchema(schemaType),
            YamlSchema schema => schema,
            _ => throw new ArgumentTransformationMetadataException(
                $"Could not convert input '{inputData}' to schema object"),
        };
    }

    internal static YamlSchema ConvertToSchema(string name) => name switch
    {
        "Blank" => new YamlSchema(),
        "Yaml11" => new Yaml11Schema(),
        "Yaml12" => new Yaml12Schema(),
        "Yaml12JSON" => new Yaml12JSONSchema(),
        _ => throw new ArgumentTransformationMetadataException($"Unknown schema type '{name}'"),
    };
}
