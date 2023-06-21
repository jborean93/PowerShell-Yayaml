using System;
using System.Globalization;
using System.Numerics;
using System.Text.RegularExpressions;

namespace Yayaml;

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
