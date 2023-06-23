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
$schema = New-YamlSchema -ParseScalar {
    param ($Value, $Schema)

    if ($Value.Tag -eq 'tag:yaml.org,2002:my_tag') {
        $bytes = [System.Convert]::FromHexString($Value.Value)
        [System.Text.Encoding]::UTF8.GetString($bytes)
    }
    else {
        # Call the base schema for the other values
        $Schema.ParseScalar($Value)
    }
}
$obj = ConvertFrom-Yaml -InputObject $yaml -Schema $schema
$obj.key  # test
```

Anytime an entry with the tag `my_tag` is encountered, the custom provided code is run to create the value.
All other tag/node handling from the schema specified (default is `Yaml12`) will still apply for other values.
The same YAML tag naming standard applies here.

It is also possible to provide custom handlers for all maps and sequence values using the `-ParseMap` and `-ParseSequence` parameters as below:

```powershell
$yaml = @'
key: !!my_tag 74657374
'@
$schema = New-YamlSchema -ParseMap {
    param ($Value, $Schema)

    $Value.Values
} -ParseSequence {
    param ($Value, $Schema)

    $Value.Values
}

$obj = ConvertFrom-Yaml -InputObject $yaml -Schema $schema
```

Each of these ScriptBlocks are called with 2 parameters:

+ `$Value`
+ `$Schema`

The `$Value` is the YAML value being processed.
For a scalar value it has the following properties:

+ `Value` - The raw YAML string value
+ `Tag` - The associated tag or `?` for untagged
+ `Style` - The YAML value style
    + `Plain` - `key: value`
    + `SingleQuoted` - `key: 'value'`
    + `Literal` - `key: |\n  value`
    + `Folded` - `key: >\n  value`

For a map value is has the following properties:

+ `Values` - An `OrderedDictionary` containing the key/value pairs for this map
+ `Style` - The YAML value style
    + `Block` - `key: value`
    + `Flow` - `{key: value}`

For a sequence value is has the following properties:

+ `Values` - An object array containing the values of the sequence
+ `Style` - The YAML value style
    + `Block` - `- 1`
    + `Flow` - `[1]`

The `$Schema` references the base schema used by `New-YamlSchema`.
It can be called to process values using the rules of the schema itself rather than the custom rules in the ScriptBlock.

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
