using System.Collections.Generic;

namespace Yayaml.Shared;

public delegate object? MapParser(KeyValuePair<object?, object?>[] values, string tag);

public delegate object? ScalarParser(string value, string tag);

public delegate object? SequenceParser(object?[] values, string tag);

public sealed class YamlTransformer
{
    internal MapParser MappingParser { get; }
    internal ScalarParser ScalarParser { get; }
    internal SequenceParser SequenceParser { get; }

    public YamlTransformer(
        MapParser mappingParser,
        ScalarParser scalarParser,
        SequenceParser sequenceParser
    )
    {
        MappingParser = mappingParser;
        ScalarParser = scalarParser;
        SequenceParser = sequenceParser;
    }
}
