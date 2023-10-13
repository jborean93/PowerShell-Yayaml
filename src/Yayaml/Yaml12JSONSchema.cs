using System;
using System.Collections;
using System.Globalization;
using System.Linq;
using System.Numerics;
using System.Text.RegularExpressions;

namespace Yayaml;

/// <summary>YAML 1.2 JSON Schema.</summary>
/// <see href="https://yaml.org/spec/1.2-old/spec.html#id2803231">YAML 1.2 JSON Schema</see>
public sealed class Yaml12JSONSchema : YamlSchema
{
    private static Regex INT_PATTERN = new Regex(@"
^
-?(0|[1-9][0-9]*)
$
", RegexOptions.Compiled | RegexOptions.ExplicitCapture | RegexOptions.IgnorePatternWhitespace);

    private static Regex FLOAT_PATTERN = new Regex(@"
^
-?
(
    0
    |
    [1-9][0-9]*
)
(
    \.[0-9]*
)?
(
    [eE][-+]?[0-9]+
)?
$
", RegexOptions.Compiled | RegexOptions.ExplicitCapture | RegexOptions.IgnorePatternWhitespace);

    public override MapValue EmitMap(IDictionary values)
    {
        return new()
        {
            Values = values,
            Style = CollectionStyle.Flow
        };
    }

    public override ScalarValue EmitScalar(object? value)
    {
        ScalarValue? commonScalar = SchemaHelpers.GetCommonScalar(value);
        if (commonScalar != null)
        {
            // If the values are a NaN or +/-Infinity they need to be tagged.
            if ((new[] { ".nan", ".inf", "-.inf" }).Contains(commonScalar.Value))
            {
                commonScalar.Tag = "!!float";
            }
            return commonScalar;
        }

        string finalValue = SchemaHelpers.GetInstanceString(value!);
        ScalarStyle style = SchemaHelpers.GetScalarStyle(value!);
        return new ScalarValue(finalValue)
        {
            Style = ScalarStyle.DoubleQuoted,
            Tag = style == ScalarStyle.Plain ? "!!str" : null,
        };
    }

    public override SequenceValue EmitSequence(object?[] values)
    {
        return new(values)
        {
            Style = CollectionStyle.Flow
        };
    }

    public override object? ParseScalar(ScalarValue value) => value.Tag switch
    {
        "tag:yaml.org,2002:bool" => ParseBool(value.Value),
        "tag:yaml.org,2002:int" => ParseInt(value.Value),
        "tag:yaml.org,2002:float" => ParseFloat(value.Value),
        "tag:yaml.org,2002:null" => ParseNull(value.Value),
        "tag:yaml.org,2002:str" => value.Value,
        _ => ParseUntagged(value.Value, value.Tag, value.Style),
    };

    private static object? ParseUntagged(string value, string? tag, ScalarStyle style)
    {
        // https://yaml.org/spec/1.2.2/#1022-tag-resolution
        if (style != ScalarStyle.Plain || !(string.IsNullOrWhiteSpace(tag) || tag == "?"))
        {
            return value;
        }
        if (TryParseNull(value, out var nullResult))
        {
            return nullResult;
        }
        else if (TryParseBool(value, out var boolResult))
        {
            return boolResult;
        }
        else if (TryParseInt(value, out var intResult))
        {
            return intResult;
        }
        else if (TryParseFloat(value, out var floatResult, wasTagged: false))
        {
            return floatResult;
        }
        else
        {
            throw new ArgumentException("Does not match JSON bool, int, float, or null literals");
        }
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
        result = SchemaHelpers.GetBestInt(integer);
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

    private static bool TryParseFloat(string value, out object? result, bool wasTagged = true)
    {
        result = default;

        if (wasTagged)
        {
            Double? canonicalMatch = value switch
            {
                "0" => new Double(),
                ".inf" => Double.PositiveInfinity,
                "-.inf" => Double.NegativeInfinity,
                ".nan" => Double.NaN,
                _ => null,
            };
            if (canonicalMatch != null)
            {
                result = canonicalMatch;
                return true;
            }
        }

        Match floatMatch = FLOAT_PATTERN.Match(value);
        if (!floatMatch.Success)
        {
            return false;
        }

        result = Double.Parse(
            value,
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
}
