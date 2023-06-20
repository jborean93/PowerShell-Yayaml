namespace Yayaml.Shared;

// This is just a copy of the YamlDotNet enum to avoid ALC problems
public enum ScalarStyle
{
    Any = YamlDotNet.Core.ScalarStyle.Any,
    Plain = YamlDotNet.Core.ScalarStyle.Plain,
    SingleQuoted = YamlDotNet.Core.ScalarStyle.SingleQuoted,
    DoubleQuoted = YamlDotNet.Core.ScalarStyle.DoubleQuoted,
    Literal = YamlDotNet.Core.ScalarStyle.Literal,
    Folded = YamlDotNet.Core.ScalarStyle.Folded,
}
