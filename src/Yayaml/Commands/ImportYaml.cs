using System.IO;
using System.Management.Automation;
using System.Diagnostics;
using System.Text;

namespace Yayaml;

[Cmdlet(VerbsData.Import, "Yaml", DefaultParameterSetName = "Path")]
public sealed class ImportYamlCommand : PSCmdlet
{
    private YamlSchema? _schema;

    private bool _expandWildcards = true;
    private string[] _paths = [];

    [Parameter(
        Mandatory = true,
        Position = 0,
        ValueFromPipeline = true,
        ValueFromPipelineByPropertyName = true,
        ParameterSetName = "Path")]
    public string[] Path
    {
        get => _paths;
        set
        {
            _paths = value;
            _expandWildcards = true;
        }
    }

    [Parameter(
        Mandatory = false,
        ValueFromPipelineByPropertyName = true,
        ParameterSetName = "LiteralPath")]
    [Alias("PSPath")]
    public string[] LiteralPath
    {
        get => _paths;
        set
        {
            _paths = value;
            _expandWildcards = false;
        }
    }

    [Parameter]
    [EncodingTransform]
#if NET8_0_OR_GREATER
    [EncodingCompletions]
#else
    [ArgumentCompleter(typeof(EncodingCompletionsAttribute))]
#endif
    public Encoding? Encoding { get; set; }

    [Parameter]
    public SwitchParameter NoEnumerate { get; set; }

    [Parameter]
#if NET6_0_OR_GREATER
    [YamlSchemaCompletions]
#else
    [ArgumentCompleter(typeof(YamlSchemaCompletionsAttribute))]
#endif
    [SchemaParameterTransformer]
    public YamlSchema? Schema { get; set; }

    protected override void BeginProcessing()
    {
        _schema = Schema ?? YamlSchema.CreateDefault();
    }

    protected override void ProcessRecord()
    {
        Debug.Assert(_schema is not null, "Schema should have been initialized in BeginProcessing.");

        Encoding fileEncoding = Encoding ?? new UTF8Encoding();
        bool detectFromBOM = Encoding is null;

        foreach (string path in PathHelper.GetResolvedPaths(this, _paths, _expandWildcards))
        {
            if (!File.Exists(path))
            {
                ErrorRecord err = new(
                    new FileNotFoundException($"Cannot find path '{path}' because it does not exist."),
                    "FileNotFound",
                    ErrorCategory.ObjectNotFound,
                    path);
                WriteError(err);
                continue;
            }

            using FileStream fs = File.OpenRead(path);
            using StreamReader sr = new(fs, fileEncoding, detectFromBOM);
            YamlReader.EmitYaml(sr, _schema, this, NoEnumerate);
        }
    }
}
