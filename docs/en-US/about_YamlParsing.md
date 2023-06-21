# YAML Parsing
## about_YamlParsing

# SHORT DESCRIPTION
YAML documents can contain complex data structures which require special handling in PowerShell.
This guide will outline some of the parsing rules and how the output object can be handled in PowerShell.

# LONG DESCRIPTION
## Schemas
Schemas are a new feature added in YAML 1.2 and is designed to handle how tagged values are handled in YAML documents.
In Yayaml, a schema is used to transform the raw YamlNode created by `YamlDotNet` into an object that can be used in PowerShell.
There are 4 schemas that have been implemented in this module:

+ `Yaml12` - Default [YAML 1.2 Core Schema](https://yaml.org/spec/1.2.2/#103-core-schema).
+ `Yaml12JSON` - [YAML 1.2 JSON Schema](https://yaml.org/spec/1.2.2/#102-json-schema)
+ `Yaml11` - [YAML 1.1 Tags](https://yaml.org/spec/1.1/#id858600)
+ `Blank` - [YAML 1.2 Failsafe Schema](https://yaml.org/spec/1.2.2/#101-failsafe-schema)

Use the `-Schema ...` parameter, i.e. `-Schema Yaml11`, to use a different schema when parsing a YAML string.
It is also possible to use a custom schema from scratch or by extending an existing one using the [New-YamlSchema](./New-YamlSchema.md) cmdlet.
This provides full flexibility in choosing how maps, sequences, and scalar types are converted from the raw YAML node value as well as adding support for specific tags.

Here is an example that can process values with the tag `tag:yaml.org,2002:my_tag`:

```powershell
$yaml = @'
key: !!my_tag 74657374
'@
$schema = New-YamlSchema -ParseTag @{
    'tag:yaml.org,2002:my_tag' = {
        param ([string]$Value)
        $bytes = [System.Convert]::FromHexString($Value)
        [System.Text.Encoding]::UTF8.GetString($bytes)
    }
}
$obj = ConvertFrom-Yaml -InputObject $yaml -Schema $schema
$obj.key  # test
```

Anytime an entry with the tag `my_tag` is encountered, the custom provided code is run to create the value.
All other tag/node handling from the schema specified (default is `Yaml12`) will still apply for other values.
The same YAML tag naming standard applies here.

It is also possible to provide custom handlers for all maps, scalar, and sequence values:

```powershell
$yaml = @'
key: !!my_tag 74657374
'@
$schema = New-YamlSchema -ParseMap {
    param ($Values, $Tag)

    # $Values - an array of KeyValuePair<object?, object?>
    # $Tag - the tag for this node

    $Values
} -ParseScalar {
    param ($Value, $Tag, $ScalarType)

    # $Value - raw string for the node
    # $Tag - the tag for this node
    # $ScalarType - The type of scalar
    #   Plain - key: value
    #   SingleQuoted - key: 'value'
    #   DoubleQuoted - key: "value"
    #   Literal - key: |\n  value
    #   Folded - key: >\n  value

    $Value
} -ParseSequence {
    param ($Values, $Tag)

    # $Values - array of values
    # $Tag - the tag for this node

    $Values
}

$obj = ConvertFrom-Yaml -InputObject $yaml -Schema $schema
```

This will overwrite the handling of any of the 3 raw types with the ScriptBlock specified.

## Integer Values
As PowerShell is based on dotnet, it has fixed length integer types.
This makes it hard to create a consistent output type when encountering `int` values.
The type of integers that will be parsed natively vary from schema to schema but the rules for how the integer value translates into a dotnet type stay the same.
The code will first try to fit the value into an `Int32`, then `Int64`, before finally falling back to `System.Numerics.BigInteger`.

## Float Values
Float values are output as a `Double` type.
If the raw value in the YAML entry is too large to fit into a `Double`, it becomes `[Double]::PositiveInfinity`.

## Null Keys
YAML maps can have a null value as a key.
These keys will be converted to `[Yayaml.NullKey]::Value` and can be referenced as such in PowerShell.
Here is how to access the value of the YAML string `null: value`

```powershell
$yaml[[Yayaml.Nullkey]::Value]

# or

$yaml.([Yayaml.NullKey]::Value)
```

## Numeric Keys
Numeric keys need to be retrieved using the property syntax or using an explicitly casted `[object]` item value.
The item lookup needs to be casted as an `[object]` as using the integer value itself will find the key of the index specified instead.

```powershell
$yaml = ConvertFrom-Yaml -InputObject @'
foo: value 0
hello: value 1
1: value 2
'@

# Gets the value 'value 1' as it's the value at index 1
$yaml[1]

# Gets the value 'value 2' as it's the value for the key 1
$yaml.1
$yaml[[object]1]
$yaml.([object]1)
```

## Merging
The YAML 1.1 schema support merging keys using the `>>: ...` syntax.
This is done automatically as long as the `-Schema Yaml11` parameter is specified.
Using a different schema will just create a key called `>>` with the values specified.
For example:

```powershell
$yaml = @'
foo:
  entry1: &anchor
    key1: value 1
    key2: value 2
  entry2:
    <<: *anchor
    key2: other value
'@

$yaml11 = ConvertFrom-Yaml $yaml -Schema Yaml11
$yaml11.foo.entry2

# Name                           Value
# ----                           -----
# key1                           value 1
# key2                           other value

$yaml12 = ConvertFrom-Yaml $yaml
$yaml12.foo.,entry2

# Name                           Value
# ----                           -----
# <<                             {[key1, value 1], [key2, value 2]}
# key2                           other value
```
