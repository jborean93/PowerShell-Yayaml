---
external help file: Yayaml.Module.dll-Help.xml
Module Name: Yayaml
online version: https://www.github.com/jborean93/PowerShell-Yayaml/blob/main/docs/en-US/New-YamlSchema.md
schema: 2.0.0
---

# New-YamlSchema

## SYNOPSIS
Creates a YAML schema definition.

## SYNTAX

```
New-YamlSchema [-EmitMap <MapEmitter>] [-EmitScalar <ScalarEmitter>] [-EmitSequence <SequenceEmitter>]
 [-EmitTransformer <TransformEmitter>] [-IsScalar <IsScalarCheck>] [-ParseMap <MapParser>]
 [-ParseScalar <ScalarParser>] [-ParseSequence <SequenceParser>] [-BaseSchema <YamlSchema>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
The `New-YamlSchema` can be used to create a custom schema for use with YAML parsing and emitting.
A schema has finer control over how individual objects are serialized or how the raw YAML values are parsed as an object.
The [about_YamlEmitting](./about_YamlEmitting.md) and [about_YamlParsing](./about_YamlParsing.md) have more in depth examples of creating and using custom schemas.

## EXAMPLES

### Example 1 - Change how DateTime values are emitted
```powershell
PS C:\> $schema = New-YamlSchema -EmitScalar {
    param ($Value, $Schema)

    if ($Value -is [DateTime] -or $Value -is [DateTimeOffset]) {
        $Value.ToString("yyyy-MM-dd")
    }
    else {
        $Schema.EmitScalar($Value)
    }
}
PS C:\> ConvertTo-Yaml @{key = (Get-Date)} -Schema $schema
# key: 2023-06-23
```

Changes the way that `[DateTime]` and `[DateTimeOffset]` values are serialized to emit just `yyyy-MM-dd`.
All other scalar types will use the base schema''s rules.

### Example 2 - Emit strings that are longer than 20 chars with the literal style
```powershell
PS C:\> $schema = New-YamlSchema -EmitScalar {
    param ($Value, $Schema)

    if ($Value -is [string] -and $Value.Length -gt 20) {
        [Yayaml.ScalarValue]@{
            Value = $Value
            Style = 'Literal'
        }
    }
    else {
        $Schema.EmitScalar($Value)
    }
}
PS C:\> $longString = "test`n" * 10
PS C:\> ConvertTo-Yaml -InputObject @{long = $longString; short = 'short'} -Schema $schema
# short: short
# long: |
#   test
#   test
#   test
#   test
#   test
#   test
#   test
#   test
#   test
#   test
```

Will emit any string value that is longer than 20 characters in the literal block format.

### Example 3 - Change the list style with a different Schema
```powershell
PS C:\> $schema = New-YamlSchema -BaseSchema Yaml11 -EmitSequence {
    param ($Values, $Schema)

    $toEmit = $Schema.EmitSequence($Values)
    $toEmit.Style = 'Flow'
    $toEmit
}
PS C:\> $value1 = [System.Text.Encoding]::UTF8.GetBytes("value1")
PS C:\> $value2 = [System.Text.Encoding]::UTF8.GetBytes("value2")
PS C:\> ConvertTo-Yaml -InputObject @{foo = $value1, $value2} -Schema $schema
# foo: [!!binary dmFsdWUx, !!binary dmFsdWUy]
```

Creates a new schema based on the YAML 1.1 rules and a custom sequence emitter that changes the style to `Flow`.

### Example 4 - Change the dict style to add a new key to each value
```powershell
PS C:\> $schema = New-YamlSchema -EmitMap {
    param ($Values, $Schema)

    $Values.Id = Get-Random
    $Schema.EmitMap($Values)
}
PS C:\> ConvertTo-Yaml -InputObject @{entry1 = @{foo = 'bar'}; entry2 = @{foo = 'bar'}} -Schema $schema
# entry2:
#   foo: bar
#   Id: 1663235921
# entry1:
#   foo: bar
#   Id: 33594040
# Id: 1517166188
```

Creates a new schema that adds a key `Id` to each dict value that will be emitted.

### Example 5 - Emit a specific type as a scalar value
```powershell
PS C:\> $schema = New-YamlSchema -IsScalar {
    param ($Value)

    $Value -is [System.IO.FileSystemInfo]
}
PS C:\> ConvertTo-Yaml -InputObject @{foo = Get-Item $pwd} -Schema $schema
# foo: C:\
```

Will treat any `FileSystemInfo` objects as a scalar type.
The default behaviour for Scalar values is to stringify the value.
A custom `-EmitScalar` ScriptBlock can also be used if custom rules for stringifying the new types is desired.

### Example 6 - Provide a custom transformer for a custom type
```powershell
PS C:\> class MyClass {
    [string]$Title
    [string]$Description
}
PS C:\> $schema = New-YamlSchema -EmitTransformer {
    param($Value, $Schema)

    if ($Value -is [MyClass]) {
        [Ordered]@{
            Title = $Value.Title
            Description = $Value.Description | Add-YamlFormat -ScalarStyle Literal -PassThru
        }
    }
    else {
        $Schema.EmitTransformer($Value)
    }
}
PS C:\> $obj = [MyClass]@{Title = 'Module'; Description = 'Information for the module'}
PS C:\> $obj | ConvertTo-Yaml -Schema $schema
# Title: Module
# Description: |-
#   Information for the module
```

Applies a custom transformation for any `MyClass` object that is being converted.
This transformation ensures the `$Description` property is emitted in the literal scalar style.
Any other object is treated as normal.

### Example 7 - Provide a custom transformer without further processing
```powershell
PS C:\> $schema = New-YamlSchema -EmitTransformer {
    param($Value, $Schema)

    if ($Value -is [string]) {

        $style = if ($Value.Length -ge 60) {
            'Literal'
        }
        else {
            'DoubleQuoted'
        }

        [Yayaml.ScalarValue]@{
            Value = $Value
            Style = $style
        }
    }
    else {
        $Schema.EmitTransformer($Value)
    }
}
PS C:\> $obj = @(
    "$('a' * 20)`n$('b' * 20)`n"
    "$('a' * 20)`n$('b' * 20)`n$('c' * 20)`n$('d' * 20)"
)
PS C:\> $obj | ConvertTo-Yaml -Schema $schema -AsArray
# - "aaaaaaaaaaaaaaaaaaaa\nbbbbbbbbbbbbbbbbbbbb\n"
# - |-
#   aaaaaaaaaaaaaaaaaaaa
#   bbbbbbbbbbbbbbbbbbbb
#   cccccccccccccccccccc
#   dddddddddddddddddddd
```

Applies a custom transformation to transform any string to a specific scalar format.
Any string less than 60 characters will be enclosed in double quotes while any greater than 60 will use the literal style.
As the transformer outputs the `Yayaml.ScalarValue` there will be no more transformation done on the value during serialization.

### Example 8 - Parse YAML with a custom map handler
```powershell
PS C:\> $schema = New-YamlSchema -ParseMap {
    param ($Value, $Schema)

    # $Value.Values is an OrderedDictionary of the raw mapping value.
    # $Value.Style is the YAML style - Block or Flow.

    if ($Value.Values.SpecialKey -eq 'test') {
        'override'
    }
    else {
        $Schema.ParseMap($Value)
    }
}
PS C:\> $yaml = @'
root:
  entry1:
    SpecialKey: test
    ignore: abc
  entry2:
    SpecialKey: other
    keep: abc
'@
PS C:\> (ConvertFrom-Yaml $yaml -Schema $schema).root
# Name                           Value
# ----                           -----
# entry1                         override
# entry2                         {[SpecialKey, other], [keep, abc]}
```

Creates a custom map parser that will change the output value if it contains a specific key value.
In this case `entry1` will be changed to the value `override` whereas `entry2` is untouched.

### Example 9 - Parse YAML with a custom sequence handler
```powershell
PS C:\> $schema = New-YamlSchema -ParseSequence {
    param ($Values, $Schema)

    $Values.Values -join "|"
}
PS C:\> ConvertFrom-Yaml -InputObject 'foo: [1, 2, 3]' -Schema $schema
# Name                           Value
# ----                           -----
# foo                            1|2|3
```

Parses all sequence values and changes them to be a string delimited by `|`.

### Example 10 - Parse YAML with a custom scalar handler
```powershell
PS C:\> $schema = New-YamlSchema -ParseScalar {
    param ($Value, $Schema)

    if ($Value.Tag -eq 'tag:yaml.org,2002:my_tag') {
        $bytes = [System.Convert]::FromHexString($Value.Value)
        [System.Text.Encoding]::UTF8.GetString($bytes)
    }
    else {
        $Schema.ParseScalar($Value)
    }
}
PS C:\> ConvertFrom-Yaml @'
foo: value 1
bar: !!my_tag 76616C75652032
'@ -Schema $schema
# Name                           Value
# ----                           -----
# foo                            value 1
# bar                            value 2
```

Adds a handler for scalar values that are tagged with `tag:yaml.org,2002:my_tag`.
All other scalar values will continue to use the default schema rules.

## PARAMETERS

### -BaseSchema
The schema to use as the base rules for the schema.
Defaults to `Yaml12`.
This can be another custom schema generated by [New-YamlSchema](./New-YamlSchema.md) or one of the following strings:

+ `Blank` - no schema data is used, scalar values are emitted as string

+ `Yaml11` - YAML 1.1 rules

+ `Yaml12` - YAML 1.2 rules

+ `Yaml12JSON` - Subset of YAML 1.2 but contains stricter plain scalar rules for better JSON compatibility

```yaml
Type: YamlSchema
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -EmitMap
A ScriptBlock that is called when `ConvertTo-Yaml` needs to create a mapping/dictionary value.
The ScriptBlock is called with 2 arguments:

+ `[System.Collections.IDictionary]$Values`

The dictionary value that needs to be emitted.

+ `[Yayaml.YamlSchema]$Schema`

The base schema that was associated with the custom schema.
The `$Schema.EmitMap($Values)` function can be called to get the base schema to emit the map value using its rules.
The ScriptBlock needs to return a ` [Yayaml.MapValue]` object that represents the final value to be serialized to YAML.

```yaml
Type: MapEmitter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -EmitScalar
A ScriptBlock that is called when `ConvertTo-Yaml` needs to create a scalar value.
The ScriptBlock is called with 2 arguments:

+ `[object?]$Value`

The scalar value that needs to be emitted.

+ `[Yayaml.YamlSchema]$Schema`

The base schema that was associated with the custom schema.
The `$Schema.EmitScalar($Value)` function can be called to get the base schema to emit the schema value using its rules.
The ScriptBlock needs to return a string value that would be used in the YAML node or a `[Yayaml.ScalarValue]` object.

```yaml
Type: ScalarEmitter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -EmitSequence
A ScriptBlock that is called when `ConvertTo-Yaml` needs to create a sequence/list value.
The ScriptBlock is called with 2 arguments:

+ `[object?[]]$Values`

The list of values that need to be emitted.

+ `[Yayaml.YamlSchema]$Schema`

The base schema that was associated with the custom schema.
The `$Schema.EmitSequence($Values)` function can be called to get the base schema to emit the sequence value using its rules.
The ScriptBlock needs to return a `[Yayaml.SequenceValue]` object that represents the final value to be serialized to YAML.

```yaml
Type: SequenceEmitter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -EmitTransformer
A ScriptBlock that is called when `ConvertTo-Yaml` goes to emit a value and can be used to transform the input object into another value for emitting.
This is useful for apply a custom serialization format for specific types rather than relying on the default behaviour.

The ScriptBlock is called with 2 arguments:

+ `[object?]$Value`

The value that needs to be emitted.

+ `[Yayaml.YamlSchema]$Schema`

The base schema that was associated with the custom schema.
The `$Schema.EmitSequence($Values)` function can be called to get the base schema to emit the sequence value using its rules.
The default schema will emit the value as is without any transformation.

It is possible to emit a `[Yayaml.MapValue]`, `[Yayaml.ScalarValue]`, or `[Yayaml.SequenceValue]` object which can specify custom YAML formatting options for the object.
Returning one of these values will bypass any futher emit actions as it represents the final value to serialize.
Otherwise the `-EmitMap`, `-EmitScalar`, and `-EmiSequence` parameters can be used to process the returned value in a more generic fashion for each node type.

```yaml
Type: TransformEmitter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -IsScalar
A ScriptBlock that is called when `ConvertTo-Yaml` needs to check if a value is a scalar value.
The ScriptBlock is called with 2 arguments:

+ `[object?]$Value`

The value that is used by the ScriptBlock to determine if it's a scalar value.

+ `[Yayaml.YamlSchema]$Schema`

The base schema that was associated with the custom schema.
The `$Schema.IsScalar($Value)` function can be called to get the base schema to perform the scalar type check using its rules.
The ScriptBlock needs to return a bool value that determines if it's a scalar value.
If `$true`, the codebase will call `EmitScalar` with that value and expect the result to be a scalar value rather than a collection.

```yaml
Type: IsScalarCheck
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ParseMap
A ScriptBlock that is called when `ConvertFrom-Yaml` needs to parse a mapping/dictionary value.
The ScriptBlock is called with 2 values:

+ `[Yayaml.MapValue]$Value`

The raw map value that is being parsed.

+ `[Yayaml.YamlSchema]$Schema`

The base schema that was associated with the custom schema.
The ScriptBlock needs to return an object that represents the `MapValue` that was being processed.
This object is what will be returned by `ConvertFrom-Yaml` for that YAML entry.

```yaml
Type: MapParser
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ParseScalar
A ScriptBlock that is called when `ConvertFrom-Yaml` needs to parse a scalar value.
The ScriptBlock is called with 2 values:

+ `[Yayaml.ScalarValue]$Value`

The raw scalar value that is being parsed.
This object contains the raw YAML string, the tag, and the scalar style.

+ `[Yayaml.YamlSchema]$Schema`

The base schema that was associated with the custom schema.
The ScriptBlock needs to return an object that represents the `ScalarValue` that was being processed.
This object is what will be returned by `ConvertFrom-Yaml` for that YAML entry.

```yaml
Type: ScalarParser
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ParseSequence
A ScriptBlock that is called when `ConvertFrom-Yaml` needs to parse a sequence/list value.
The ScriptBlock is called with 2 values:

+ `[Yayaml.SequenceValue]$Value`

The raw sequence value that is being parsed.

+ `[Yayaml.YamlSchema]$Schema`

The base schema that was associated with the custom schema.
The ScriptBlock needs to return an object that represents the `SequenceValue` that was being processed.
This object is what will be returned by `ConvertFrom-Yaml` for that YAML entry.

```yaml
Type: SequenceParser
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProgressAction
New common parameter introduced in PowerShell 7.4.

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None
This cmdlet does not accept any pipeline input.

## OUTPUTS

### Yayaml.YamlSchema
The YAML schema that contains the custom handlers that was provided with it. This schema can be used with the `-Schema` parameter on `ConvertFrom-Yaml` and `ConvertTo-Yaml`.

## NOTES

## RELATED LINKS
