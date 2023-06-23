using System.Collections;

namespace Yayaml;

/// <summary>
/// Delegate signature for a custom scalar check ScriptBlock
/// </summary>
/// <param name="value">The value to check</param>
/// <param name="schema">The base schema that can be used as a fallback.</param>
/// <returns>true if the value is to be treated as a scalar or not.</returns>
public delegate bool IsScalarCheck(object? value, YamlSchema schema);

/// <summary>
/// Delegate signature for a custom schema map handler.
/// </summary>
/// <param name="value">The raw map value that is being parsed.</param>
/// <param name="schema">The base schema that can be used as a fallback.</param>
/// <returns>The desired object result to return for this map.</returns>
public delegate object? MapParser(MapValue value, YamlSchema schema);

/// <summary>
/// Delegate signature for a custom map emitter ScriptBlock.
/// </summary>
/// <param name="values">The map value to be emitted.</param>
/// <param name="schema">The base schema that can be used as a fallback.</param>
/// <returns>The final MapValue to emit.</returns>
public delegate MapValue MapEmitter(IDictionary values, YamlSchema schema);

/// <summary>
/// Delegate signature for a custom schema scalar handler.
/// </summary>
/// <param name="value">The raw scalar value that is being parsed.</param>
/// <param name="schema">The base schema that can be used as a fallback.</param>
/// <returns>The desired object result to return for this scalar.</returns>
public delegate object? ScalarParser(ScalarValue value, YamlSchema schema);

/// <summary>
/// Delegate signature for a custom scalar emitter ScriptBlock.
/// </summary>
/// <param name="value">The scalar value to be emitted.</param>
/// <param name="schema">The base schema that can be used as a fallback.</param>
/// <returns>The final ScalarValue to emit.</returns>
public delegate ScalarValue ScalarEmitter(object? value, YamlSchema schema);

/// <summary>
/// Delegate signature for a custom schema sequence handler.
/// </summary>
/// <param name="value">The raw sequence value that is being parsed.</param>
/// <param name="schema">The base schema that can be used as a fallback.</param>
/// <returns>The desired object result to return for this sequence.</returns>
public delegate object? SequenceParser(SequenceValue value, YamlSchema schema);

/// <summary>
/// Delegate signature for a custom sequence emitter ScriptBlock.
/// </summary>
/// <param name="values">The sequence values to be emitted.</param>
/// <param name="schema">The base schema that can be used as a fallback.</param>
/// <returns>The final Sequence value to emit.</returns>
public delegate SequenceValue SequenceEmitter(object?[] values, YamlSchema schema);

public sealed class CustomSchema : YamlSchema
{
    private YamlSchema _baseSchema;
    private IsScalarCheck? _isScalar;
    private MapEmitter? _mapEmitter;
    private MapParser? _mapParser;
    private ScalarEmitter? _scalarEmitter;
    private ScalarParser? _scalarParser;
    private SequenceEmitter? _sequenceEmitter;
    private SequenceParser? _sequenceParser;

    internal CustomSchema(
        YamlSchema baseSchema,
        MapEmitter? mapEmitter = null,
        ScalarEmitter? scalarEmitter = null,
        SequenceEmitter? sequenceEmitter = null,
        IsScalarCheck? isScalar = null,
        MapParser? mapParser = null,
        ScalarParser? scalarParser = null,
        SequenceParser? sequenceParser = null
    )
    {
        _baseSchema = baseSchema;
        _isScalar = isScalar;
        _mapEmitter = mapEmitter;
        _mapParser = mapParser;
        _scalarEmitter = scalarEmitter;
        _scalarParser = scalarParser;
        _sequenceEmitter = sequenceEmitter;
        _sequenceParser = sequenceParser;
    }

    public override bool IsScalar(object? value)
        => _isScalar == null
            ? _baseSchema.IsScalar(value)
            : _isScalar(value, _baseSchema);

    public override MapValue EmitMap(IDictionary values)
        => _mapEmitter == null
            ? _baseSchema.EmitMap(values)
            : _mapEmitter(values, _baseSchema);

    public override ScalarValue EmitScalar(object? value)
        => _scalarEmitter == null
            ? _baseSchema.EmitScalar(value)
            : _scalarEmitter(value, _baseSchema);

    public override SequenceValue EmitSequence(object?[] values)
        => _sequenceEmitter == null
            ? _baseSchema.EmitSequence(values)
            : _sequenceEmitter(values, _baseSchema);

    public override object? ParseScalar(ScalarValue value)
        => _scalarParser == null
            ? _baseSchema.ParseScalar(value)
            : _scalarParser(value, _baseSchema);

    public override object? ParseMap(MapValue value)
        => _mapParser == null
            ? _baseSchema.ParseMap(value)
            : _mapParser(value, _baseSchema);

    public override object? ParseSequence(SequenceValue value)
        => _sequenceParser == null
            ? _baseSchema.ParseSequence(value)
            : _sequenceParser(value, _baseSchema);
}
