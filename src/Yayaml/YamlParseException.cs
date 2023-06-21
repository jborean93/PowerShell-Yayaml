using System;

namespace Yayaml;

public class YamlParseException : FormatException
{
    /// <summary>
    /// The line number where the error starts (starts at 1).
    /// </summary>
    public int StartLine { get; }

    /// <summary>
    /// THe column number where the error starts (starts at 1).
    /// </summary>
    public int StartColumn { get; }

    /// <summary>
    /// The line number where the error ends (starts at 1).
    /// </summary>
    public int EndLine { get; }

    /// <summary>
    /// The column number where the error ends (starts at 1).
    /// </summary>
    public int EndColumn { get; }

    public YamlParseException(string message, int startLine, int startColumn,
        int endLine, int endColumn)
        : base(message)
    {
        StartLine = startLine;
        StartColumn = startColumn;
        EndLine = endLine;
        EndColumn = endColumn;
    }

    public YamlParseException(string message, int startLine, int startColumn,
        int endLine, int endColumn, Exception innerException)
        : base(message, innerException)
    {
        StartLine = startLine;
        StartColumn = startColumn;
        EndLine = endLine;
        EndColumn = endColumn;
    }
}
