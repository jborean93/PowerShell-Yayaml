using System;
using System.Collections.Generic;
using System.IO;
using System.Management.Automation;
using System.Text;

namespace Yayaml;

[Cmdlet(VerbsData.Export, "Yaml", DefaultParameterSetName = "Path", SupportsShouldProcess = true)]
[OutputType(typeof(void))]
public sealed class ExportYamlCommand : ToYamlBaseCommand, IDisposable
{
    private List<TextWriter> _writers = [];
    private List<(string path, FileAttributes originalAttributes)> _resetReadOnlyPaths = [];

    private bool _expandWildcards = true;
    private string[] _paths = [];

    [Parameter(
        Mandatory = true,
        Position = 0,
        ParameterSetName = "Path")]
    public string[] Path
    {
        set
        {
            _paths = value;
            _expandWildcards = true;
        }
    }

    [Parameter(
        Mandatory = false,
        ParameterSetName = "LiteralPath")]
    [Alias("PSPath")]
    public string[] LiteralPath
    {
        set
        {
            _paths = value;
            _expandWildcards = false;
        }
    }

    [Parameter(
        Mandatory = true,
        Position = 1,
        ValueFromPipeline = true,
        ValueFromPipelineByPropertyName = true
    )]
    [AllowNull]
    public override PSObject? InputObject { get; set; } = null;

    [Parameter]
    [EncodingTransform]
#if NET8_0_OR_GREATER
    [EncodingCompletions]
#else
    [ArgumentCompleter(typeof(EncodingCompletionsAttribute))]
#endif
    public Encoding? Encoding { get; set; }

    [Parameter]
    public SwitchParameter Append { get; set; }

    [Parameter]
    public SwitchParameter Force { get; set; }

    [Parameter]
    public SwitchParameter NoClobber { get; set; }

    protected override void BeginProcessing()
    {
        base.BeginProcessing();

        FileMode fileMode = FileMode.Create;
        if (Append)
        {
            fileMode = FileMode.Append;
        }
        else if (NoClobber)
        {
            fileMode = FileMode.CreateNew;
        }
        FileShare fileShare = Force ? FileShare.ReadWrite : FileShare.Read;
        Encoding fileEncoding = Encoding ?? new UTF8Encoding();

        foreach (string path in PathHelper.GetResolvedPaths(this, _paths, _expandWildcards, mustExist: false))
        {
            string action = Append ? "Append" : "Create";
            if (!ShouldProcess(path, action))
            {
                continue;
            }

            try
            {
                StreamWriter sw = CreateFileWriter(path, fileMode, fileShare, fileEncoding);
                _writers.Add(sw);
            }
            catch (Exception e)
            {
                ErrorRecord err = new(
                    e,
                    "FileOpenFailed",
                    ErrorCategory.OpenError,
                    path)
                {
                    ErrorDetails = new($"Failed to open '{path}' for writing: {e.Message}"),
                };
                WriteError(err);
            }
        }
    }

    protected override void EndProcessing()
    {
        base.EndProcessing();

        foreach (TextWriter writer in _writers)
        {
            writer.Dispose();
        }

        ResetReadOnlyPaths(ignoreErrors: true);
    }

    protected override void ProcessYaml(string yaml)
    {
        foreach (TextWriter writer in _writers)
        {
            writer.WriteLine(yaml);
        }
    }

    public void Dispose()
    {
        foreach (TextWriter writer in _writers)
        {
            writer.Dispose();
        }

        ResetReadOnlyPaths(ignoreErrors: true);
    }

    private StreamWriter CreateFileWriter(
        string path,
        FileMode fileMode,
        FileShare fileShare,
        Encoding encoding)
    {
        if (Force && (Append || !NoClobber) && File.Exists(path))
        {
            FileAttributes fa = File.GetAttributes(path);
            if (fa.HasFlag(FileAttributes.ReadOnly))
            {
                File.SetAttributes(path, fa & ~FileAttributes.ReadOnly);
                _resetReadOnlyPaths.Add((path, fa));
            }
        }

        FileStream fs = new(path, fileMode, FileAccess.Write, fileShare);
        return new StreamWriter(fs, encoding);
    }

    private void ResetReadOnlyPaths(bool ignoreErrors)
    {
        while (_resetReadOnlyPaths.Count > 0)
        {
            (string path, FileAttributes originalAttributes) = _resetReadOnlyPaths[0];
            _resetReadOnlyPaths.RemoveAt(0);

            try
            {
                File.SetAttributes(path, originalAttributes);
            }
            catch (Exception e)
            {
                if (ignoreErrors)
                {
                    continue;
                }

                string msg = $"Failed to reset the read-only attribute on '{path}': {e.Message}";

                ErrorRecord err = new(
                    e,
                    "ResetReadOnlyFailed",
                    ErrorCategory.NotSpecified,
                    path)
                {
                    ErrorDetails = new(msg),
                };
                WriteError(err);
            }
        }
    }
}
