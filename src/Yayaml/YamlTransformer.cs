using System;
using System.Management.Automation;

namespace Yayaml;

[Cmdlet(VerbsCommon.New, "YamlTransformer")]
[OutputType(typeof(YamlTransformer))]
public sealed class NewYamlTransformerCommand : PSCmdlet
{
    [Parameter]
    public Func<(object?, object?)[], object?>? ParseMapping { get; set; }

    [Parameter]
    public Func<string, string, object?>? ParseScalar { get; set; }

    [Parameter]
    public Func<object?[], object?>? ParseSequence { get; set; }

    [Parameter]
    [ArgumentCompletions(nameof(Yaml11), nameof(Yaml12), nameof(Yaml12JSON))]
    [SchemaTransformer]
    public YamlSchema? BaseSchema { get; set; }

    protected override void EndProcessing()
    {
        base.EndProcessing();
    }
}

public sealed class YamlTransformer
{

}
