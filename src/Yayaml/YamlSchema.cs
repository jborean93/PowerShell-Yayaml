using System.Collections.Generic;
using System.Collections.Specialized;

namespace Yayaml;

/// <summary>
/// Delegate signature for a custom schema map handler.
/// </summary>
public delegate object? MapParser(KeyValuePair<object?, object?>[] values, string tag);

/// <summary>
/// Delegate signature for a custom schema scalar handler.
/// </summary>
public delegate object? ScalarParser(string value, string tag, ScalarStyle style);

/// <summary>
/// Delegate signature for a custom schema sequence handler.
/// </summary>
public delegate object? SequenceParser(object?[] values, string tag);

/// <summary>
/// Delegate signature for a custom scalar tag handler.
/// </summary>
public delegate object? TagTransformer(string value);

public class YamlSchema
{
    protected Dictionary<string, TagTransformer> Tags { get; set; } = new();

    public virtual object? ParseScalar(string value, string tag, ScalarStyle style)
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
            res[entry.Key ?? NullKey.Value] = entry.Value;
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
    private ScalarParser? _scalar;
    private MapParser? _map;
    private SequenceParser? _sequence;

    public CustomSchema(
        YamlSchema baseSchema,
        Dictionary<string, TagTransformer> tags,
        ScalarParser? scalar = null,
        MapParser? map = null,
        SequenceParser? sequence = null
    )
    {
        Tags = tags;
        _baseSchema = baseSchema;
        _scalar = scalar;
        _map = map;
        _sequence = sequence;
    }

    public override object? ParseScalar(string value, string tag, ScalarStyle style)
    {
        if (Tags.TryGetValue(tag, out var transformer))
        {
            return transformer(value);
        }
        else if (_scalar != null)
        {
            return _scalar(value, tag, style);
        }
        else
        {
            return _baseSchema.ParseScalar(value, tag, style);
        }
    }

    public override object? ParseMap(KeyValuePair<object?, object?>[] values, string tag)
        => (_map ?? _baseSchema.ParseMap)(values, tag);

    public override object? ParseSequence(object?[] values, string tag)
        => (_sequence ?? _baseSchema.ParseSequence)(values, tag);
}
