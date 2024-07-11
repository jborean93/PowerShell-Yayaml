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

## Comments
It is possible to emit comments alongside an object when using `ConvertTo-Yaml`.
Comments cannot be parsed through `ConvertFrom-Yaml`, the only way to emit a comment is by explicitly adding it to the object metadata before calling `ConvertTo-Yaml`.
Comments come in three forms:

+ Pre - Added on the preceding line of the value
+ Inline - Added at the end of the line of the value
+ Post - Added on the next line of the value

Each of these comments can be added through the [Add-YamlFormat](./Add-YamlFormat.md) cmdlet through the `-PreComment`, `-Comment`, and `-PostComment` parameters respectively.

Due to the YAML parsing rules, there are some cases where comments may not be supported, for example:

+ Folded or Literal scalar values cannot have an inline comment
+ Flow maps/sequences (dicts/lists) will ingore any comments in any child values, the map/sequence itself can still have a pre, inline, and post comment though
+ Block maps/sequences cannot have an inline comment, the comment should be set on the inner value that is desired instead
+ Map (dicts) keys cannot have comments applied, they should be set on the value instead

Here is an example of how a pre, inline, and post comment works on a simple scalar value:

```powershell
$value = 'value' | Add-YamlFormat -PreComment pre -Comment inline -PostComment post -PassThru
$value | ConvertTo-Yaml
```

```yaml
# pre
value # inline
# post
```

Attempting to set an inline comment on a folded or literal scalar will emit a warning

```powershell
$value = 'value' | Add-YamlFormat -PreComment pre -Comment inline -PostComment post -PassThru -ScalarStyle Literal
$value | ConvertTo-Yaml
# WARNING: Scalar value 'value' has a style of Literal and contained inline comment but will be ignored. Inline comment cannot be used for the Folded or Literal scalar values.
```

```yaml
# pre
|-
  value
# post
```

The same logic applies when serializing a scalar value inside a map or sequence.

```powershell
$value = [Ordered]@{
    Map = [Ordered]@{
        First = 'first'
        Key = 'value' | Add-YamlFormat -PreComment pre -Comment inline -PostComment post -PassThru
        Last = 'last'
    }
    Sequence = @(
        'first'
        'value' | Add-YamlFormat -PreComment pre -Comment inline -PostComment post -PassThru
        'last'
    )
}
$value | ConvertTo-Yaml
```

```yaml
Map:
  First: first
  # pre
  Key: value # inline
  # post
  Last: last
Sequence:
- first
# pre
- value # inline
# post
- last
```

When adding a comment to a map/dict value itself, it can contain a pre and post comment but not an inline comment.
For example this is how the pre/post comments work alongside a key that also has a pre/post comment.

```powershell
$value = [Ordered]@{
    First = 'value' | Add-YamlFormat -PreComment "value pre" -PostComment "value post" -PassThru
}
$value | Add-YamlFormat -PreComment "map pre" -PostComment "map post"
$value | ConvertTo-Yaml
```

```yaml
# map pre
# value pre
First: value
# value post
# map post
```

A flow map/dict will ignore any comments in the child values but can have an inline comment on it.
The comment rules work similar to a scalar value where the inline comment comes after the flow map.

```powershell
$value = [Ordered]@{
    First = 'value' | Add-YamlFormat -PreComment "value pre" -Comment "value inline" -PostComment "value post" -PassThru
}
$value | Add-YamlFormat -PreComment "map pre" -Comment "map inline" -PostComment "map post" -CollectionStyle Flow
$value | ConvertTo-Yaml
```

```yaml
# map pre
{First: value} # map inline
# map post
```

The same restrictions also apply to sequences where a block sequence cannot have an inline comment while flow sequences will ignore any comment inside the sequence itself.

```powershell
$block = @(
    'first'
    'value block' | Add-YamlFormat -PreComment "value block pre" -Comment "value block inline" -PostComment "value block post" -PassThru
    'last'
)
Add-YamlFormat -InputObject $block -PreComment "block pre" -PostComment "block post"

$flow = @(
    'first'
    'value flow' | Add-YamlFormat -PreComment "value flow pre" -Comment "value flow inline" -PostComment "value flow post" -PassThru
    'last'
)
Add-YamlFormat -InputObject $flow -PreComment "flow pre" -Comment "flow inline" -PostComment "flow post" -CollectionStyle Flow
$value = [Ordered]@{ Block = $block; Flow = $flow }
ConvertTo-Yaml $value
```

```yaml
# block pre
Block:
- first
# value block pre
- value block # value block inline
# value block post
- last
# block post
# flow pre
Flow: [first, value flow, last] # flow inline
# flow post
```

If you wish to apply a comment to all instances of a specific type, you can combine custom schema emit transformer with `Add-YamlFormat` to add the comment.
For example:

```powershell
class MyClass {
    [int]$Id
    [string]$Title
    [Object]$MetaData
}

$schema = New-YamlSchema -EmitTransformer {
    param ($Value, $Schema)

    if ($Value -is [MyClass]) {
        $meta = $Value.MetaData | Add-YamlFormat -Comment "type: $($Value.MetaData.GetType().Name)" -PassThru
        $obj = [Ordered]@{
            Title = $Value.Title
            MetaData = $meta
        }
        $obj | Add-YamlFormat -PreComment "id: $($Value.Id)"

        $obj
    }
    else {
        $Schema.EmitTransformer($Value)
    }
}

@(
    [MyClass]@{
        Id = 1
        Title = 'Foo'
        MetaData = 'meta'
    }
    [MyClass]@{
        Id = 2
        Title = 'Bar'
        MetaData = 1
    }
) | ConvertTo-Yaml -Schema $schema
```

```yaml
# id: 1
- Title: Foo
  MetaData: meta # type: String
# id: 2
- Title: Bar
  MetaData: 1 # type: Int32
```

In the above example we use a custom transformer to emit the `Id` property as a pre comment and add the .NET type name of the `MetaData` value as an inline comment.
As the transformer is run on each instance to serialize, it will do this transformation on any instance of that type, whether it's a root value or part of an inner map/sequence.
