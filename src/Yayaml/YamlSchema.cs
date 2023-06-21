using System;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Globalization;
using System.Linq;
using System.Numerics;

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

    /// <summary>
    /// Called when parsing a scalar value.
    /// </summary>
    /// <param name="value">The raw YAML node string to parse.</param>
    /// <param name="tag">The associated YAML tag or '?' for undefined.</param>
    /// <param name="style">The raw style of the YAML node string.</param>
    /// <returns>The parsed scalar value</returns>
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

    /// <summary>
    /// Called when parsing a map value (dictionary).
    /// </summary>
    /// <param name="values">Contains a list of all the key and values.</param>
    /// <param name="tag">The associated YAML tag.</param>
    /// <returns>The parsed map value.</returns>
    public virtual object? ParseMap(KeyValuePair<object?, object?>[] values, string tag)
    {
        OrderedDictionary res = new();
        foreach (KeyValuePair<object?, object?> entry in values)
        {
            res[entry.Key ?? NullKey.Value] = entry.Value;
        }

        return res;
    }

    /// <summary>
    /// Called when parsing a sequence value (list).
    /// </summary>
    /// <param name="values">Contains a list of all the values.</param>
    /// <param name="tag">The associated YAML tag.</param>
    /// <returns>The parsed sequence value.</returns>
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

internal static class SchemaHelpers
{
    public static BigInteger ParseIntBinary(string binary)
        => binary.Substring(2)
            .Aggregate(new BigInteger(), (b, c) => b * 2 + c - '0');

    public static BigInteger ParseIntOctal(string octal)
        => octal.Substring(2)
            .Aggregate(new BigInteger(), (b, c) => b * 8 + c - '0');

    public static BigInteger ParseIntSexagesimal(string sexagesimal)
    {
        string[] parts = sexagesimal.Split(':');
        BigInteger integer = BigInteger.Zero;
        foreach (string p in parts)
        {
            integer *= 60;
            integer += BigInteger.Parse(p, NumberStyles.None);
        }

        return integer;
    }

    public static object GetBestInt(BigInteger value)
    {
        // Will attempt to get an Int32 or Int64 if the BigInteger fits,
        // otherwise it just returns the BigInteger itself.
        if (value >= Int32.MinValue && value <= Int32.MaxValue)
        {
            return (int)value;
        }
        else if (value >= Int64.MinValue && value <= Int64.MaxValue)
        {
            return (Int64)value;
        }
        else
        {
            return value;
        }
    }
}
