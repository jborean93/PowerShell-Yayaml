# YAML Emitting
## about_YamlEmitting

# SHORT DESCRIPTION
YAML documents can express quite complex structures and the rules `Yayaml` uses to build these structures tries to be as intuitive as possible.
This guide will outline these behaviours and provide more information on how to adjust them.

# LONG DESCRIPTION
## Schemas
Schemas are a new feature added in YAML 1.2 and is designed to contain the rules on how values are emitted in YAML documents.
There are 4 schemas that have been implemented in this module:

+ `Yaml12` - Default [YAML 1.2 Core Schema](https://yaml.org/spec/1.2.2/#103-core-schema).
+ `Yaml12JSON` - [YAML 1.2 JSON Schema](https://yaml.org/spec/1.2.2/#102-json-schema)
+ `Yaml11` - [YAML 1.1 Tags](https://yaml.org/spec/1.1/#id858600)
+ `Blank` - [YAML 1.2 Failsafe Schema](https://yaml.org/spec/1.2.2/#101-failsafe-schema)

Use the `-Schema ...` parameter, i.e `-Schema Yaml11`, to use a different schema when emitting a YAML string.
It is also possible to use a custom schema from scratch or by extending an existing one using the [New-YamlSchema](./New-YamlSchema.md) cmdlet.
A schema can be used when emitting a YAML string to:

+ Change was values are treated as scalars if they don't match the existing rules
+ Change how scalar values are emitted, either by adjusting the raw string, setting a tag, or changing the style
+ Change how map values are emitted, either by adjusting the map contents or changing the style
+ Change how sequence values are emitted, either by adjusting the sequence contents or changing the style

The [New-YamlSchema](./New-YamlSchema.md) cmdlet documents a few examples for these parameters and how they can be used.

## Scalar Values
Currently the following types are treated as scalar values:

+ `[bool]` - emitted as `true` or `false`
+ `[char]` - emitted as a string
+ `[DateTime]` - The YAML 1.1 schema emits this using the 1.1 timestamp rules, YAML 1.2 and 1.2 JSON will emit using the `ToString("o")` format
+ `[DateTimeOffset]` - Same as `[DateTimeOffset]`
+ `[Guid]` - emitted as the GUID value
+ `[string]` - emitted as a string
+ `[sbyte], [byte], [int16], [uint16], [int32], [uint32], [int64], [uint64], [System.Numerics.BigInteger]` - emitted as an integer
+ `[float], [double], [decimal]` - emitted as a float with a significand, base, and exponent

A scalar value can be emitted with the following styles:

|Style|Example|
|-|-|
|Any|Schema default|
|Plain|`foo: value`|
|SingleQuoted|`foo: 'value'`|
|DoubleQuoted|`foo: "value"`|
|Literal|`foo: |\n  value`|
|Folded|`foo: >\n  value`|

The [Add-YamlFormat](./Add-YamlFormat.md) cmdlet can be used to apply a custom style to a specific object.

## Map and Sequence Values
Map values are dictionary like values and sequence values are list like values.
Any type that implements `[System.Collections.IList]` will be treated as a sequence.
Any type that implements `[System.Collections.IDictionary]` will use the dictionary key value pairs as the map.
All other types that aren't scalars or sequences will also be treated as maps.
The instance's properties will be used as the key value pair as the maps contents.

A map and sequence value can be emitted with the following styles:

|Style|Example|
|-|-|
|Any|Schema default|
|Block|`foo: bar` - `- 1\n- 2`|
|Flow|`{foo: bar}` - `[1, 2]`|

The [Add-YamlFormat](./Add-YamlFormat.md) cmdlet can be used to apply a custom style to a specific object.

## Null Keys
It is possible for a YAML map/dict value to contain a null value as a key.
Unfortunately the builtin dictionary types in dotnet do not allow `$null` to be used as a key.
An alternative is to use `[Yayaml.NullKey]::Value` to represent a null key.

```powershell
ConvertTo-Yaml @{
    [Yayaml.NullKey]::Value = 'abc'
}
```

```yaml
null: abc
```
