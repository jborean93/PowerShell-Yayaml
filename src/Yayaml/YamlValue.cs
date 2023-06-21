using System;
using System.Collections;

namespace Yayaml;

// This is just a copy of the YamlDotNet SequenceStyle/MappingStyle enum to avoid ALC problems
public enum CollectionStyle
{
    Any = 0,
    Block = 1,
    Flow = 2,
}

// This is just a copy of the YamlDotNet enum to avoid ALC problems
public enum ScalarStyle
{
    Any = 0,
    Plain = 1,
    SingleQuoted = 2,
    DoubleQuoted = 3,
    Literal = 4,
    Folded = 5,
}

public sealed class MapValue
{
    /// <summary>
    /// The map's values.
    /// </summary>
    public IDictionary Values { get; set; }

    /// <summary>
    /// The map style.
    /// </summary>
    public CollectionStyle Style { get; set; }

    public MapValue()
    {
        Values = new Hashtable();
    }
}

public sealed class ScalarValue
{
    /// <summary>
    /// The raw scalar string value.
    /// </summary>
    public string Value { get; set; }

    /// <summary>
    /// The scalar style.
    /// </summary>
    public ScalarStyle Style { get; set; } = ScalarStyle.Any;

    /// <summary>
    /// The scalar tag if set.
    /// </summary>
    public string? Tag { get; set; }

    public ScalarValue() : this("")
    { }

    public ScalarValue(string value)
    {
        Value = value;
    }
}

public sealed class SequenceValue
{
    /// <summary>
    /// The sequence values.
    /// </summary>
    public object?[] Values { get; set; }

    /// <summary>
    /// The sequence style.
    /// </summary>
    public CollectionStyle Style { get; set; } = CollectionStyle.Any;

    public SequenceValue()
        : this(Array.Empty<object?>())
    { }

    public SequenceValue(object?[] values)
    {
        Values = values;
    }
}
