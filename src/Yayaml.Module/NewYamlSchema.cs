using System;
using System.Collections;
using System.Collections.Generic;
using System.Management.Automation;

namespace Yayaml.Module;

[Cmdlet(VerbsCommon.New, "YamlSchema")]
[OutputType(typeof(YamlSchema))]
public sealed class NewYamlSchemaCommand : PSCmdlet
{
    [Parameter]
    public MapParser? ParseMap { get; set; }

    [Parameter]
    public ScalarParser? ParseScalar { get; set; }

    [Parameter]
    public SequenceParser? ParseSequence { get; set; }

    [Parameter]
    public IDictionary? ParseTag { get; set; }

    [Parameter]
    [YamlSchemaCompletions]
    [SchemaParameterTransformer]
    public YamlSchema? BaseSchema { get; set; }

    protected override void EndProcessing()
    {
        YamlSchema? baseSchema = BaseSchema ?? YamlSchema.CreateDefault();

        if (ParseMap == null && ParseScalar == null && ParseSequence == null && ParseTag == null)
        {
            WriteObject(baseSchema);
        }
        else
        {
            Dictionary<string,TagTransformer> tagParser = new();
            if (ParseTag != null)
            {
                foreach (DictionaryEntry entry in ParseTag)
                {
                    string tag = entry.Key.ToString() ?? "";

                    if (entry.Value is TagTransformer func)
                    {
                        tagParser[tag] = func;
                    }
                    else if (entry.Value is ScriptBlock sbk)
                    {
                        func = LanguagePrimitives.ConvertTo<TagTransformer>(sbk);
                        tagParser[tag] = func;
                    }
                    else
                    {
                        ErrorRecord err = new(
                            new ArgumentException($"ParseTag value for '{tag}' must be a ScriptBlock"),
                            "InvalidParseTagValue",
                            ErrorCategory.InvalidArgument,
                            entry.Value
                        );
                        WriteError(err);
                    }
                }
            }

            CustomSchema finalSchema = new(
                baseSchema,
                tagParser,
                map: ParseMap,
                scalar: ParseScalar,
                sequence: ParseSequence
            );
            WriteObject(finalSchema);
        }
    }
}
