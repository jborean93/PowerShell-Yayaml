using System;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Globalization;
using System.Linq;
using System.Management.Automation;
using System.Numerics;
using System.Text.RegularExpressions;
using Yayaml.Shared;

namespace Yayaml;

public class YamlSchema
{
    protected Dictionary<string, Func<string, object?>> Tags { get; set; } = new();

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
            // FIXME: Allow null keys
            res[entry.Key ?? ""] = entry.Value;
        }

        return res;
    }

    public virtual object? ParseSequence(object?[] values, string tag)
        => values;

    internal static YamlSchema CreateDefault() => new Yaml12Schema();

    internal YamlTransformer CreateTransformer()
        => new(
            ParseMap,
            ParseScalar,
            ParseSequence
        );
}

public sealed class CustomSchema : YamlSchema
{
    private YamlSchema _baseSchema;
    private ScalarParser? _scalar;
    private MapParser? _map;
    private SequenceParser? _sequence;

    public CustomSchema(
        YamlSchema baseSchema,
        Dictionary<string, Func<string, object?>> tags,
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

/// <summary>YAML 1.1 Types Schema.</summary>
/// <see href="https://yaml.org/type/">YAML 1.1 Types</see>
public sealed class Yaml11Schema : YamlSchema
{
    private static Regex INT_PATTERN = new Regex(@"
(?<Binary>^[-+]?0b[0-1_]+$)  # Base2
|
(?<Octal>^[-+]?0[0-7_]+$)  # Base8
|
(?<Decimal>^[-+]?(0|[1-9][0-9_]*) $)  # Base10
|
(?<Hex>^[-+]?0x[0-9a-fA-F_]+$)  # Base16
|
(?<Sexagesimal>^[-+]?[1-9][0-9_]*(:[0-5]?[0-9])+$)  # Base60
", RegexOptions.Compiled | RegexOptions.ExplicitCapture | RegexOptions.IgnorePatternWhitespace);

    private static Regex FLOAT_PATTERN = new Regex(@"
(?<Number>^
    [-+]?
    (
        [0-9][0-9_]*
    )?
    \.[0-9.]*
    (
        [eE][-+][0-9]+
    )?
$)
|
(?<Sexagesimal>^
    [-+]?
    [0-9][0-9_]*
    (:[0-5]?[0-9])+
    \.[0-9_]*
$)
|
(?<Infinity>^[-+]?\.(int|InF|INF)$)
|
(?<NaN>^\.(nan|NaN\NAN)$)
", RegexOptions.Compiled | RegexOptions.ExplicitCapture | RegexOptions.IgnorePatternWhitespace);

    private static Regex TIMESTAMP_PATTERN = new Regex(@"
(?<Date>^
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]
$)
|
(?<DateTime>^
    [0-9][0-9][0-9][0-9]  # Year
    -[0-9][0-9]?          # Month
    -[0-9][0-9]?          # Day
    ([Tt]|[ \t]+)         # Time separator
    [0-9][0-9]?           # Hour
    :[0-9][0-9]           # Minute
    :[0-9][0-9]           # Second
    (\.[0-9]*)?           # Fraction
    (                     # Timezone
        ([ \t]*)Z
        |
        [-+][0-9][0-9]?
        (:[0-9][0-9])?
    )?
$)


  # (time zone)
", RegexOptions.Compiled | RegexOptions.ExplicitCapture | RegexOptions.IgnorePatternWhitespace);

    public Yaml11Schema()
    {
        Tags = new()
        {
            { "tag:yaml.org,2002:binary", ParseBinary },
            { "tag:yaml.org,2002:bool", ParseBool },
            { "tag:yaml.org,2002:int", ParseInt },
            { "tag:yaml.org,2002:float", ParseFloat },
            { "tag:yaml.org,2002:null", ParseNull },
            { "tag:yaml.org,2002:timestamp", ParseTimestamp },
        };
    }

    private static object? ParseBinary(string value)
    {
        try
        {
            return Convert.FromBase64String(value.Replace(" ", ""));
        }
        catch (FormatException e)
        {
            throw new ArgumentException($"Does not match expected binary base64 value: {e.Message}", e);
        }
    }

    private static bool TryParseBool(string value, out bool result)
    {
        result = default;

        if (new[] { "y", "Y", "yes", "Yes", "YES", "true", "True", "TRUE", "on", "On", "ON" }.Contains(value))
        {
            result = true;
            return true;
        }
        else if (new[] { "n", "N", "no", "No", "NO", "false", "False", "FALSE", "off", "Off", "OFF" }.Contains(value))
        {
            result = false;
            return true;
        }

        return false;
    }

    private static object? ParseBool(string value)
    {
        if (TryParseBool(value, out var result))
        {
            return result;
        }

        throw new ArgumentException("Does not match expected bool values true, True, TRUE, false, False, FALSE");
    }

    private static bool TryParseInt(string value, out object? result)
    {
        result = default;

        Match intMatch = INT_PATTERN.Match(value);
        if (!intMatch.Success)
        {
            return false;
        }

        BigInteger integer;
        if (intMatch.Groups["Octal"].Success)
        {
            string rawValue = intMatch.Groups["Octal"].Value.Substring(2);
            integer = rawValue.Aggregate(new BigInteger(), (b, c) => b * 8 + c - '0');
        }
        else
        {
            NumberStyles styles = NumberStyles.None;
            string rawValue;
            if (intMatch.Groups["Decimal"].Success)
            {
                styles |= NumberStyles.AllowLeadingSign;
                rawValue = intMatch.Groups["Decimal"].Value;
            }
            else
            {
                styles |= NumberStyles.HexNumber;
                // Ensure it starts with 0 so it isn't interpreted as a negative
                // number.
                rawValue = "0" + intMatch.Groups["Hex"].Value;
            }

            integer = BigInteger.Parse(rawValue, styles);
        }

        if (integer >= Int32.MinValue && integer <= Int32.MaxValue)
        {
            result = (int)integer;
        }
        else if (integer >= Int64.MinValue && integer <= Int64.MaxValue)
        {
            result = (Int64)integer;
        }
        else
        {
            result = integer;
        }

        return true;
    }

    private static object? ParseInt(string value)
    {
        if (TryParseInt(value, out var result))
        {
            return result;
        }

        throw new ArgumentException("Does not match expected int value pattern '[-+]?[0-9]+', '0o[0-7]+', '0x[0-9a-fA-F]+'");
    }

    private static bool TryParseFloat(string value, out object? result)
    {
        result = default;

        Match floatMatch = FLOAT_PATTERN.Match(value);
        if (!floatMatch.Success)
        {
            return false;
        }

        if (floatMatch.Groups["NaN"].Success)
        {
            result = Double.NaN;
            return true;
        }
        else if (floatMatch.Groups["Infinity"].Success)
        {
            if (floatMatch.Groups["Infinity"].Value.StartsWith("-"))
            {
                result = Double.NegativeInfinity;
            }
            else
            {
                result = Double.PositiveInfinity;
            }
            return true;
        }

        result = Double.Parse(
            floatMatch.Groups["Number"].Value,
            NumberStyles.AllowDecimalPoint | NumberStyles.AllowExponent | NumberStyles.AllowLeadingSign
        );

        return true;
    }

    private static object? ParseFloat(string value)
    {
        if (TryParseFloat(value, out var result))
        {
            return result;
        }

        throw new ArgumentException("Does not match expected float value pattern");
    }

    private static bool TryParseNull(string value, out object? result, bool acceptBlank = true)
    {
        result = null;
        return new[] { "null", "Null", "NULL", "~" }.Contains(value) || (acceptBlank && value == "");
    }

    private static object? ParseNull(string value)
    {
        if (TryParseNull(value, out var result))
        {
            return result;
        }

        throw new ArgumentException("Does not match expected null values null, Null, NULL, ~");
    }

    private static bool TryParseTimestamp(string value, out DateTimeOffset result)
    {
        result = default;

        Match dtMatch = TIMESTAMP_PATTERN.Match(value);
        if (!dtMatch.Success)
        {
            return false;
        }

        return true;
    }

    private static object? ParseTimestamp(string value)
    {
        if (TryParseTimestamp(value, out var result))
        {
            return result;
        }

        throw new ArgumentException("Does not match expected timestamp value");
    }

    public override object? ParseScalar(string value, string tag, ScalarStyle style)
    {
        if (Tags.TryGetValue(tag, out var transformer))
        {
            return transformer(value);
        }
        else if (style != ScalarStyle.Plain || tag != "?")
        {
            return value;
        }
        else if (TryParseBool(value, out var boolResult))
        {
            return boolResult;
        }
        else if (TryParseInt(value, out var intResult))
        {
            return intResult;
        }
        else if (TryParseFloat(value, out var floatResult))
        {
            return floatResult;
        }
        else if (TryParseNull(value, out var nullResult, acceptBlank: false))
        {
            return nullResult;
        }
        else if (TryParseTimestamp(value, out var dtResult))
        {
            return dtResult;
        }
        else
        {
            return value;
        }
    }
}

/// <summary>YAML 1.2 Core Schema.</summary>
/// <see href="https://yaml.org/spec/1.2-old/spec.html#id2804923">YAML 1.2 Core Schema</see>
public sealed class Yaml12Schema : YamlSchema
{
    private static Regex INT_PATTERN = new Regex(@"
(?<Octal>^0o[0-7]+$)  # Base8
|
(?<Decimal>^[-+]?[0-9]+$)  # Base10
|
(?<Hex>^0x[0-9a-fA-F]+$)  # Base16
", RegexOptions.Compiled | RegexOptions.ExplicitCapture | RegexOptions.IgnorePatternWhitespace);

    private static Regex FLOAT_PATTERN = new Regex(@"
(?<Number>^
[-+]?
(
    \.[0-9]+
    |
    [0-9]+(\.[0-9]*)?
)
(
    [eE][-+]?[0-9]+
)?
$)
|
(?<Infinity>^[-+]?(\.inf|\.Inf|\.INF)$)
|
(?<NaN>^\.nan|\.NaN|\.NAN$)
", RegexOptions.Compiled | RegexOptions.ExplicitCapture | RegexOptions.IgnorePatternWhitespace);

    public Yaml12Schema()
    {
        Tags = new()
        {
            { "tag:yaml.org,2002:bool", ParseBool },
            { "tag:yaml.org,2002:int", ParseInt },
            { "tag:yaml.org,2002:float", ParseFloat },
            { "tag:yaml.org,2002:null", ParseNull },
            { "tag:yaml.org,2002:str", (s => s) },
        };
    }

    private static bool TryParseBool(string value, out bool result)
    {
        result = default;

        if (new[] { "true", "True", "TRUE" }.Contains(value))
        {
            result = true;
            return true;
        }
        else if (new[] { "false", "False", "FALSE" }.Contains(value))
        {
            result = false;
            return true;
        }

        return false;
    }

    private static object? ParseBool(string value)
    {
        if (TryParseBool(value, out var result))
        {
            return result;
        }

        throw new ArgumentException("Does not match expected bool values true, True, TRUE, false, False, FALSE");
    }

    private static bool TryParseInt(string value, out object? result)
    {
        result = default;

        Match intMatch = INT_PATTERN.Match(value);
        if (!intMatch.Success)
        {
            return false;
        }

        BigInteger integer;
        if (intMatch.Groups["Octal"].Success)
        {
            string rawValue = intMatch.Groups["Octal"].Value.Substring(2);
            integer = rawValue.Aggregate(new BigInteger(), (b, c) => b * 8 + c - '0');
        }
        else if (intMatch.Groups["Decimal"].Success)
        {
            integer = BigInteger.Parse(intMatch.Groups["Decimal"].Value, NumberStyles.AllowLeadingSign);
        }
        else
        {
            // Ensure it starts with 0 so it isn't interpreted as a negative
            // number.
            string rawValue = intMatch.Groups["Hex"].Value.Substring(2);
            int paddingLength = (rawValue.Length + 7) & (-8);
            rawValue = rawValue.PadLeft(paddingLength, '0');
            integer = BigInteger.Parse(rawValue, NumberStyles.HexNumber);
        }

        if (integer >= Int32.MinValue && integer <= Int32.MaxValue)
        {
            result = (int)integer;
        }
        else if (integer >= Int64.MinValue && integer <= Int64.MaxValue)
        {
            result = (Int64)integer;
        }
        else
        {
            result = integer;
        }

        return true;
    }

    private static object? ParseInt(string value)
    {
        if (TryParseInt(value, out var result))
        {
            return result;
        }

        throw new ArgumentException("Does not match expected int value pattern '[-+]?[0-9]+', '0o[0-7]+', '0x[0-9a-fA-F]+'");
    }

    private static bool TryParseFloat(string value, out object? result)
    {
        result = default;

        Match floatMatch = FLOAT_PATTERN.Match(value);
        if (!floatMatch.Success)
        {
            return false;
        }

        if (floatMatch.Groups["NaN"].Success)
        {
            result = Double.NaN;
            return true;
        }
        else if (floatMatch.Groups["Infinity"].Success)
        {
            if (floatMatch.Groups["Infinity"].Value.StartsWith("-"))
            {
                result = Double.NegativeInfinity;
            }
            else
            {
                result = Double.PositiveInfinity;
            }
            return true;
        }

        result = Double.Parse(
            floatMatch.Groups["Number"].Value,
            NumberStyles.AllowDecimalPoint | NumberStyles.AllowExponent | NumberStyles.AllowLeadingSign
        );

        return true;
    }

    private static object? ParseFloat(string value)
    {
        if (TryParseFloat(value, out var result))
        {
            return result;
        }

        throw new ArgumentException("Does not match expected float value pattern");
    }

    private static bool TryParseNull(string value, out object? result, bool acceptBlank = true)
    {
        result = null;
        return new[] { "null", "Null", "NULL", "~" }.Contains(value) || (acceptBlank && value == "");
    }

    private static object? ParseNull(string value)
    {
        if (TryParseNull(value, out var result))
        {
            return result;
        }

        throw new ArgumentException("Does not match expected null values null, Null, NULL, ~");
    }

    public override object? ParseScalar(string value, string tag, ScalarStyle style)
    {
        if (Tags.TryGetValue(tag, out var transformer))
        {
            return transformer(value);
        }
        else if (style != ScalarStyle.Plain || tag != "?")
        {
            return value;
        }
        else if (TryParseBool(value, out var boolResult))
        {
            return boolResult;
        }
        else if (TryParseInt(value, out var intResult))
        {
            return intResult;
        }
        else if (TryParseFloat(value, out var floatResult))
        {
            return floatResult;
        }
        else if (TryParseNull(value, out var nullResult, acceptBlank: false))
        {
            return nullResult;
        }
        else
        {
            return value;
        }
    }
}


/// <summary>YAML 1.2 JSON Schema.</summary>
/// <see href="https://yaml.org/spec/1.2-old/spec.html#id2803231">YAML 1.2 JSON Schema</see>
public sealed class Yaml12JSONSchema : YamlSchema
{
    private static Regex INT_PATTERN = new Regex(@"
(^0$)
|
(^-?[1-9][0-9]*$)
", RegexOptions.Compiled | RegexOptions.ExplicitCapture | RegexOptions.IgnorePatternWhitespace);

    private static Regex FLOAT_PATTERN = new Regex(@"
(?<Number>^(
0
|
(
    -?[1-9]
    (\.[0-9]+)?
    (e[-+][1-9][0-9]*)?
)
)$)
|
(?<Infinity>^-?\.inf$)
|
(?<NaN>^\.nan$)
", RegexOptions.Compiled | RegexOptions.ExplicitCapture | RegexOptions.IgnorePatternWhitespace);

    public Yaml12JSONSchema()
    {
        Tags = new()
        {
            { "tag:yaml.org,2002:bool", ParseBool },
            { "tag:yaml.org,2002:int", ParseInt },
            { "tag:yaml.org,2002:float", ParseFloat },
            { "tag:yaml.org,2002:null", ParseNull },
        };
    }

    private static bool TryParseBool(string value, out bool result)
    {
        result = default;

        if (value == "true")
        {
            result = true;
            return true;
        }
        else if (value == "false")
        {
            result = false;
            return true;
        }

        return false;
    }

    private static object? ParseBool(string value)
    {
        if (TryParseBool(value, out var result))
        {
            return result;
        }

        throw new ArgumentException("Does not match expected JSON bool values true or false");
    }

    private static bool TryParseInt(string value, out object? result)
    {
        result = default;

        Match intMatch = INT_PATTERN.Match(value);
        if (!intMatch.Success)
        {
            return false;
        }

        BigInteger integer = BigInteger.Parse(value);
        if (integer >= Int32.MinValue && integer <= Int32.MaxValue)
        {
            result = (int)integer;
        }
        else if (integer >= Int64.MinValue && integer <= Int64.MaxValue)
        {
            result = (Int64)integer;
        }
        else
        {
            result = integer;
        }

        return true;
    }

    private static object? ParseInt(string value)
    {
        if (TryParseInt(value, out var result))
        {
            return result;
        }

        throw new ArgumentException("Does not match expected JSON int value pattern '0|-?[1-9][0-9]*'");
    }

    private static bool TryParseFloat(string value, out object? result)
    {
        result = default;

        Match floatMatch = FLOAT_PATTERN.Match(value);
        if (!floatMatch.Success)
        {
            return false;
        }

        if (floatMatch.Groups["NaN"].Success)
        {
            result = Double.NaN;
            return true;
        }
        else if (floatMatch.Groups["Infinity"].Success)
        {
            if (floatMatch.Groups["Infinity"].Value.StartsWith("-"))
            {
                result = Double.NegativeInfinity;
            }
            else
            {
                result = Double.PositiveInfinity;
            }
            return true;
        }

        result = Double.Parse(
            floatMatch.Groups["Number"].Value,
            NumberStyles.AllowDecimalPoint | NumberStyles.AllowExponent | NumberStyles.AllowLeadingSign
        );

        return true;
    }

    private static object? ParseFloat(string value)
    {
        if (TryParseFloat(value, out var result))
        {
            return result;
        }

        throw new ArgumentException("Does not match expected JSON float value pattern");
    }

    private static bool TryParseNull(string value, out object? result)
    {
        result = null;
        return value == "null";
    }

    private static object? ParseNull(string value)
    {
        if (TryParseNull(value, out var result))
        {
            return result;
        }

        throw new ArgumentException("Does not match expected JSON null value null");
    }

    public override object? ParseScalar(string value, string tag, ScalarStyle style)
    {
        if (Tags.TryGetValue(tag, out var transformer))
        {
            return transformer(value);
        }
        else if (style != ScalarStyle.Plain || tag != "?")
        {
            return value;
        }
        else if (TryParseBool(value, out var boolResult))
        {
            return boolResult;
        }
        else if (TryParseInt(value, out var intResult))
        {
            return intResult;
        }
        else if (TryParseFloat(value, out var floatResult))
        {
            return floatResult;
        }
        else if (TryParseNull(value, out var nullResult))
        {
            return nullResult;
        }
        else
        {
            return value;
        }
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

    internal static YamlSchema ConvertToSchema(string name) => name.ToLowerInvariant() switch
    {
        "blank" => new YamlSchema(),
        "yaml11" => new Yaml11Schema(),
        "yaml12" => new Yaml12Schema(),
        "yaml12json" => new Yaml12JSONSchema(),
        _ => throw new ArgumentTransformationMetadataException($"Unknown schema type '{name}'"),
    };
}
