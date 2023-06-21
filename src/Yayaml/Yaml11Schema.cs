using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Globalization;
using System.Linq;
using System.Numerics;
using System.Text.RegularExpressions;

namespace Yayaml;

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
    \.[0-9_]*
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
(?<Infinity>^[-+]?\.(inf|InF|INF)$)
|
(?<NaN>^\.(nan|NaN|NAN)$)
", RegexOptions.Compiled | RegexOptions.ExplicitCapture | RegexOptions.IgnorePatternWhitespace);

    private static Regex TIMESTAMP_PATTERN = new Regex(@"
(?<Date>^
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]
$)
|
(^
    (?<Year>[0-9][0-9][0-9][0-9])   # Year
    -(?<Month>[0-9][0-9]?)          # Month
    -(?<Day>[0-9][0-9]?)            # Day
    ([Tt]|[ \t]+)                   # Time separator
    (?<Hour>[0-9][0-9]?)            # Hour
    :(?<Minute>[0-9][0-9])          # Minute
    :(?<Second>[0-9][0-9])          # Second
    (\.(?<Fraction>[0-9]*))?        # Fraction
    (                               # Timezone
        ([ \t]*)
        (
            (?<Zulu>Z)
            |
            (?<TZ>
                (?<TZSign>([-+]))
                (?<TZHour>[0-9][0-9]?)
                (:(?<TZMinute>[0-9][0-9]))?
            )
        )
    )?
$)
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
            return Convert.FromBase64String(value.Replace(" ", "").Replace("\r", "").Replace("\n", ""));
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

        throw new ArgumentException("Does not match expected bool values");
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
        if (intMatch.Groups["Binary"].Success)
        {
            string sign = "";
            string rawValue = intMatch.Groups["Binary"].Value.Replace("_", "");
            if (rawValue.StartsWith("+") || rawValue.StartsWith("-"))
            {
                sign = rawValue.Substring(0, 1);
                rawValue = rawValue.Substring(3);
            }
            else
            {
                rawValue = rawValue.Substring(2);
            }

            integer = rawValue.Aggregate(new BigInteger(), (b, c) => b * 2 + c - '0');
            if (sign == "-")
            {
                integer = -integer;
            }
        }
        else if (intMatch.Groups["Octal"].Success)
        {
            string sign = "";
            string rawValue = intMatch.Groups["Octal"].Value.Replace("_", "");
            if (rawValue.StartsWith("+") || rawValue.StartsWith("-"))
            {
                sign = rawValue.Substring(0, 1);
                rawValue = rawValue.Substring(2);
            }
            else
            {
                rawValue = rawValue.Substring(1);
            }

            integer = rawValue.Aggregate(new BigInteger(), (b, c) => b * 8 + c - '0');
            if (sign == "-")
            {
                integer = -integer;
            }
        }
        else if (intMatch.Groups["Decimal"].Success)
        {
            integer = BigInteger.Parse(
                intMatch.Groups["Decimal"].Value.Replace("_", ""),
                NumberStyles.AllowLeadingSign);
        }
        else if (intMatch.Groups["Hex"].Success)
        {
            string rawValue = intMatch.Groups["Hex"].Value.Replace("_", "");

            // YAML 1.1 hex is special as it supports a sign char. If it's
            // not signed then the MSB (multiples of 8) will denote if it's
            // a negative number or not like YAML 1.2. If it's signed with + it
            // will treat the value as unsigned. If it's signed with - it will
            // ensure the end result is a negative number.
            bool isNegative = false;
            if (rawValue.StartsWith("+"))
            {
                // Add 0 so it's always a positive number
                rawValue = "0" + rawValue.Substring(3);
            }
            else
            {
                 if (rawValue.StartsWith("-"))
                {
                    // Mark that the final parsed value should be negative
                    rawValue = rawValue.Substring(1);
                    isNegative = true;
                }

                // Ensure it's left padded to the nearest multiple of 8 so
                // it's only treated as a negative number if the MSB is set.
                rawValue = rawValue.Substring(2);
                int paddingLength = (rawValue.Length + 7) & (-8);
                rawValue = rawValue.PadLeft(paddingLength, '0');

            }

            integer = BigInteger.Parse(rawValue, NumberStyles.HexNumber);
            if (isNegative && integer.Sign == 1)
            {
                integer *= -1;
            }
        }
        else
        {
            string rawValue = intMatch.Groups["Sexagesimal"].Value.Replace("_", "");
            bool isNegative = rawValue.StartsWith("-");
            if (isNegative || rawValue.StartsWith("+"))
            {
                rawValue = rawValue.Substring(1);
            }

            string[] parts = rawValue.Split(':');
            integer = BigInteger.Zero;
            foreach (string p in parts)
            {
                integer *= 60;
                integer += BigInteger.Parse(p, NumberStyles.None);
            }

            if (isNegative)
            {
                integer *= -1;
            }
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

        string rawValue;
        if (floatMatch.Groups["Sexagesimal"].Success)
        {
            rawValue = floatMatch.Groups["Sexagesimal"].Value.Replace("_", "");
            bool isNegative = rawValue.StartsWith("-");
            if (isNegative || rawValue.StartsWith("+"))
            {
                rawValue = rawValue.Substring(1);
            }

            string[] integerSplit = rawValue.Split('.', 2);

            string[] parts = integerSplit[0].Split(':');
            BigInteger integer = BigInteger.Zero;
            foreach (string p in parts)
            {
                integer *= 60;
                integer += BigInteger.Parse(p, NumberStyles.None);
            }

            if (isNegative)
            {
                integer *= -1;
            }

            rawValue = $"{integer.ToString()}.{integerSplit[1]}";
        }
        else
        {
            rawValue = floatMatch.Groups["Number"].Value.Replace("_", "");
        }

        result = Double.Parse(
            rawValue,
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

        if (dtMatch.Groups["Date"].Success)
        {
            result = DateTimeOffset.ParseExact(
                $"{dtMatch.Groups["Date"].Value} +00:00",
                "yyyy-MM-dd zzz",
                CultureInfo.InvariantCulture);
            return true;
        }

        string year = dtMatch.Groups["Year"].Value;
        string month = dtMatch.Groups["Month"].Value.PadLeft(2, '0');
        string day = dtMatch.Groups["Day"].Value.PadLeft(2, '0');
        string hour = dtMatch.Groups["Hour"].Value.PadLeft(2, '0');
        string minute = dtMatch.Groups["Minute"].Value.PadLeft(2, '0');
        string second = dtMatch.Groups["Second"].Value.PadLeft(2, '0');
        string fraction;
        if (dtMatch.Groups["Fraction"].Success)
        {
            // DateTimes only support up to 100s of nanoseconds
            fraction = $".{dtMatch.Groups["Fraction"].Value.PadRight(7, '0').Substring(0, 7)}";
        }
        else
        {
            fraction = ".0";
        }

        string tz = "";
        if (dtMatch.Groups["Zulu"].Success)
        {
            tz = "+00:00";
        }
        else if (dtMatch.Groups["TZ"].Success)
        {
            string tzHours = dtMatch.Groups["TZHour"].Value.PadLeft(2, '0');
            string tzMinutes = "00";
            if (dtMatch.Groups["TZMinute"].Success)
            {
                tzMinutes = dtMatch.Groups["TZMinute"].Value.PadLeft(2, '0');
            }

            tz = $"{dtMatch.Groups["TZSign"].Value}{tzHours}:{tzMinutes}";
        }
        else
        {
            // If no TZ is specified it is assumed to be UTC.
            tz = "+00:00";
        }

        result = DateTimeOffset.ParseExact(
            $"{year}-{month}-{day}T{hour}:{minute}:{second}{fraction} {tz}",
            "yyyy-MM-ddTHH:mm:ss.FFFFFFF zzz",
            CultureInfo.InvariantCulture);
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

    public override object? ParseMap(KeyValuePair<object?, object?>[] values, string tag)
    {
        OrderedDictionary res = new();
        foreach (KeyValuePair<object?, object?> entry in values)
        {
            // If '>>: !!map ...' is encountered then the values need to be
            // merged into the final result.
            if (
                entry.Key is string stringKey &&
                stringKey == "<<" &&
                entry.Value is OrderedDictionary mergeTable)
            {
                foreach (DictionaryEntry mergeEntry in mergeTable)
                {
                    if (res.Contains(mergeEntry.Key))
                    {
                        continue;
                    }
                    res[mergeEntry.Key] = mergeEntry.Value;
                }
            }
            else
            {
                res[entry.Key ?? NullKey.Value] = entry.Value;
            }
        }

        return res;
    }
}
