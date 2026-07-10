using System;
using System.Collections;
using System.Collections.Generic;
using System.Management.Automation;
using System.Management.Automation.Language;
using System.Text;
using System.Globalization;

namespace Yayaml;

public sealed class EncodingTransformAttribute : ArgumentTransformationAttribute
{
    internal static string[] KnownEncodings = [
        "UTF8",
        "ASCII",
        "ANSI",
        "OEM",
        "Unicode",
        "UTF8Bom",
        "UTF8NoBom"
    ];

    public override object Transform(EngineIntrinsics engineIntrinsics, object inputData)
    {
        if (inputData is PSObject psObj)
        {
            inputData = psObj.BaseObject;
        }

        return inputData switch
        {
            Encoding e => e,
            string s => GetEncodingFromString(s, s.ToUpperInvariant()),
            int i => Encoding.GetEncoding(i),
            _ => throw new ArgumentTransformationMetadataException($"Could not convert input '{inputData}' to a valid Encoding object."),
        };
    }

    private static Encoding GetEncodingFromString(string encoding, string encodingUpper) => encodingUpper switch
    {
        "ASCII" => new ASCIIEncoding(),
        "ANSI" => Encoding.GetEncoding(CultureInfo.CurrentCulture.TextInfo.ANSICodePage),
        "OEM" => Console.OutputEncoding,
        "UNICODE" => new UnicodeEncoding(),
        "UTF8" => new UTF8Encoding(),
        "UTF8BOM" => new UTF8Encoding(true),
        "UTF8NOBOM" => new UTF8Encoding(),
        _ => Encoding.GetEncoding(encoding),
    };
}

#if NET8_0_OR_GREATER
public class EncodingCompletionsAttribute : ArgumentCompletionsAttribute
{
    public EncodingCompletionsAttribute() : base(EncodingTransformAttribute.KnownEncodings)
    { }
}
#else
public class EncodingCompletionsAttribute : IArgumentCompleter {
    public IEnumerable<CompletionResult> CompleteArgument(
        string commandName,
        string parameterName,
        string wordToComplete,
        CommandAst commandAst,
        IDictionary fakeBoundParameters
    )
    {
        if (string.IsNullOrWhiteSpace(wordToComplete))
        {
            wordToComplete = "";
        }

        WildcardPattern pattern = new($"{wordToComplete}*");
        foreach (string encoding in EncodingTransformAttribute.KnownEncodings)
        {
            if (pattern.IsMatch(encoding))
            {
                yield return new CompletionResult(encoding);
            }
        }
    }
}
#endif
