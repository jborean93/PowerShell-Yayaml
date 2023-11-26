using System.Collections;
using System.Collections.Generic;
using System.Management.Automation;
using System.Management.Automation.Language;

namespace Yayaml.Module;

#if CORE
public class YamlSchemaCompletionsAttribute : ArgumentCompletionsAttribute
{
    public YamlSchemaCompletionsAttribute()
        : base(SchemaParameterTransformer.KNOWN_SCHEMAS)
    { }
}
#else
public class YamlSchemaCompletionsAttribute : IArgumentCompleter {
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
        foreach (string encoding in SchemaParameterTransformer.KNOWN_SCHEMAS)
        {
            if (pattern.IsMatch(encoding))
            {
                yield return new CompletionResult(encoding);
            }
        }
    }
}
#endif

public sealed class SchemaParameterTransformer : ArgumentTransformationAttribute
{
    internal static string[] KNOWN_SCHEMAS = new[] {
        "Blank",
        "Yaml11",
        "Yaml12",
        "Yaml12JSON"
    };

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
