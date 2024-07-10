using System;
using System.Collections;
using System.Diagnostics.CodeAnalysis;
using System.Globalization;
using System.Linq;
using System.Management.Automation;
using System.Numerics;
using System.Text.RegularExpressions;

namespace Yayaml;

/// <summary>Base YAML schema, acts like the YAML 1.2 Failsafe Schema.</summary>
/// <see href="https://yaml.org/spec/1.2.2/#101-failsafe-schema">YAML 1.2 Failsafe Schema</see>
public class YamlSchema
{
    public virtual bool IsScalar(object? value)
        => false;

    public virtual MapValue EmitMap(IDictionary values)
        => new() { Values = values };

    public virtual ScalarValue EmitScalar(object? value)
        => new(SchemaHelpers.GetInstanceString(value ?? "null"));

    public virtual SequenceValue EmitSequence(object?[] values)
        => new(values);

    public virtual PSObject? EmitTransformer(PSObject? value)
        => value;

    /// <summary>
    /// Called when parsing a scalar value.
    /// </summary>
    /// <param name="value">The raw YAML node string to parse.</param>
    /// <param name="tag">The associated YAML tag or '?' for undefined.</param>
    /// <param name="style">The raw style of the YAML node string.</param>
    /// <returns>The parsed scalar value</returns>
    public virtual object? ParseScalar(ScalarValue value)
        => value.Value;

    /// <summary>
    /// Called when parsing a map value (dictionary).
    /// </summary>
    /// <param name="values">Contains a list of all the key and values.</param>
    /// <param name="tag">The associated YAML tag.</param>
    /// <returns>The parsed map value.</returns>
    public virtual object? ParseMap(MapValue value)
        => value.Values;

    /// <summary>
    /// Called when parsing a sequence value (list).
    /// </summary>
    /// <param name="values">Contains a list of all the values.</param>
    /// <param name="tag">The associated YAML tag.</param>
    /// <returns>The parsed sequence value.</returns>
    public virtual object? ParseSequence(SequenceValue value)
        => value.Values;

    internal static YamlSchema CreateDefault() => new Yaml12Schema();
}

internal class YayamlFormat
{
    public CollectionStyle CollectionStyle { get; }
    public ScalarStyle ScalarStyle { get; }
    public string? Comment { get; }
    public string? PreComment { get; }
    public string? PostComment { get; }

    public YayamlFormat(
        CollectionStyle collectionStyle,
        ScalarStyle scalarStyle,
        string? comment,
        string? preComment,
        string? postComment)
    {
        CollectionStyle = collectionStyle;
        ScalarStyle = scalarStyle;
        Comment = comment;
        PreComment = preComment;
        PostComment = postComment;
    }
}

internal static class SchemaHelpers
{
    internal const string YAYAML_FORMAT_ID = "_YayamlFormat";

    private static Regex FLOAT_PATTERN = new Regex(@"
(?<Significand>-?\d+)\.(?<Base>\d+)e(?<Exponent>[+-]\d+)
", RegexOptions.Compiled | RegexOptions.ExplicitCapture | RegexOptions.IgnorePatternWhitespace);

    public static bool IsIntegerValue(object value)
        => value is sbyte ||
            value is byte ||
            value is Int16 ||
            value is UInt16 ||
            value is Int32 ||
            value is UInt32 ||
            value is Int64 ||
            value is UInt64 ||
            value is BigInteger ||
            value is IntPtr ||
            value is UIntPtr ||
            value is Enum;

    public static bool IsFloatValue(object value)
        => value is float ||
            value is double ||
            value is Decimal;

    public static ScalarValue? GetCommonScalar(object? value)
    {
        if (value == null)
        {
            return new ScalarValue("null");
        }

        ScalarStyle style = GetScalarStyle(value);
        bool noTag = style == ScalarStyle.Any || style == ScalarStyle.Plain;

        if (value is bool valueBool)
        {
            return new ScalarValue(valueBool ? "true" : "false")
            {
                Tag = noTag ? null : "!!bool",
            };
        }
        else if (value is Enum enumValue)
        {
            object rawEnum = Convert.ChangeType(enumValue, enumValue.GetTypeCode());
            return new ScalarValue(rawEnum.ToString() ?? "0")
            {
                Tag = noTag ? null : "!!int",
            };
        }
        else if (SchemaHelpers.IsIntegerValue(value))
        {
            return new ScalarValue(value.ToString() ?? "0")
            {
                Tag = noTag ? null : "!!int",
            };
        }
        else if (IsFloatValue(value))
        {
            string rawValue = value switch
            {
                float f when f == float.PositiveInfinity => ".inf",
                float f when f == float.NegativeInfinity => "-.inf",
                float f when f.ToString(CultureInfo.InvariantCulture) == "NaN" => ".nan",
                float f => f.ToString("e", CultureInfo.InvariantCulture),
                double d when d == double.PositiveInfinity => ".inf",
                double d when d == double.NegativeInfinity => "-.inf",
                double d when d.ToString(CultureInfo.InvariantCulture) == "NaN" => ".nan",
                double d => d.ToString("e", CultureInfo.InvariantCulture),
                _ => ((Decimal)value).ToString("e", CultureInfo.InvariantCulture),
            };

            Match floatMatch = FLOAT_PATTERN.Match(rawValue);
            if (floatMatch.Success)
            {
                // The e format is a bit different to what strict yaml supports
                // as it uses a padded base an exponent. Reparse the value to
                // unpad these sections to form the raw float value as needed.
                BigInteger significand = BigInteger.Parse(
                    floatMatch.Groups["Significand"].Value,
                    NumberStyles.AllowLeadingSign);
                BigInteger baseI = BigInteger.Parse(
                    floatMatch.Groups["Base"].Value.TrimEnd('0').PadLeft(1, '0'),
                    NumberStyles.AllowLeadingSign);
                BigInteger exponent = BigInteger.Parse(
                    floatMatch.Groups["Exponent"].Value,
                    NumberStyles.AllowLeadingSign);

                string sign = "";
                if (exponent >= 0)
                {
                    sign = "+";
                }

                rawValue = $"{significand}.{baseI}e{sign}{exponent}";
            }

            return new ScalarValue(rawValue)
            {
                Tag = noTag ? null : "!!float",
            };
        }

        return null;
    }

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

    [return: NotNullIfNotNull("obj")]
    public static PSObject? GetPSObject(object? obj)
    {
        if (obj == null)
        {
            return null;
        }
        else if (obj is PSObject psObj)
        {
            return psObj;
        }
        else
        {
            return PSObject.AsPSObject(obj);
        }
    }

    public static string GetInstanceString(object value) => value switch
    {
        DateTime dt => dt.ToString("o", CultureInfo.InvariantCulture),
        DateTimeOffset dto => dto.ToString("o", CultureInfo.InvariantCulture),
        _ => LanguagePrimitives.ConvertTo<string>(value),
    };

    public static YayamlFormat? GetYayamlFormatProperty(PSObject obj)
        => obj.Properties
            .Match(YAYAML_FORMAT_ID)
            .Select(p => p.Value)
            .Cast<YayamlFormat>()
            .FirstOrDefault();

    public static ScalarStyle GetScalarStyle(object obj)
    {
        PSObject psObj = GetPSObject(obj);
        YayamlFormat? formatProp = GetYayamlFormatProperty(psObj);
        return formatProp?.ScalarStyle ?? ScalarStyle.Any;
    }
}
