using System;
using System.Globalization;
using System.Linq;
using System.Numerics;
using System.Text.RegularExpressions;

namespace Yayaml;

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
            integer = SchemaHelpers.ParseIntOctal(intMatch.Groups["Octal"].Value);
        }
        else if (intMatch.Groups["Decimal"].Success)
        {
            integer = BigInteger.Parse(intMatch.Groups["Decimal"].Value, NumberStyles.AllowLeadingSign);
        }
        else
        {
            // Ensure it is padded to an 8 byte boundary so it's only negative
            // if the MSB is set.
            string rawValue = intMatch.Groups["Hex"].Value.Substring(2);
            int paddingLength = (rawValue.Length + 7) & (-8);
            rawValue = rawValue.PadLeft(paddingLength, '0');
            integer = BigInteger.Parse(rawValue, NumberStyles.HexNumber);
        }

        result = SchemaHelpers.GetBestInt(integer);
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
