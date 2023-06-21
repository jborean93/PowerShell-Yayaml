using System.Management.Automation;

namespace Yayaml.Module;

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
