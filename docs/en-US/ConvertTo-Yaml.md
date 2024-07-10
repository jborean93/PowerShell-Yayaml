---
external help file: Yayaml.Module.dll-Help.xml
Module Name: Yayaml
online version: https://www.github.com/jborean93/PowerShell-Yayaml/blob/main/docs/en-US/ConvertTo-Yaml.md
schema: 2.0.0
---

# ConvertTo-Yaml

## SYNOPSIS
Converts an object to a YAML-formatted string.

## SYNTAX

```
ConvertTo-Yaml [-InputObject] <PSObject> [-AsArray] [-Depth <Int32>] [-IndentSequence] [-Schema <YamlSchema>]
 [-Stream] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
The `ConvertTo-Yaml` cmdlet converts any .NET object to a string in the YAML format.
The output format depends on the input object being serialized.
The [Add-YamlFormat](./Add-YamlFormat.md) cmdlet can be used to control the format of individual values.

By default, the YAML 1.2 core schema will be used when creating the values.
Use the `-Schema` parameter to control what schema is used or to provide a custom schema handler.

To parse a YAML string into an object, use the [ConvertFrom-Yaml](./ConvertFrom-Yaml.md) cmdlet.
See [about_YamlEmitting](./about_yamlEmitting.md) for more information on creating YAML strings.

## EXAMPLES

### Example 1 - Create YAML string from a hashtable
```powershell
PS C:\> @{foo = 'bar'} | ConvertTo-Yaml
# foo: bar
```

Creates a YAML string `foo: bar` from the hashtable provided.
Note hashtables don't have a defined order, use `[Ordered]@{...}` or `[PSCustomObject]@{...}` if the order is important.

### Example 2 - Create YAML string from dotnet object with custom depth
```powershell
PS C:\> $item = Get-Item $PSCommandPath
PS C:\> $item | ConvertTo-Yaml -Depth 1 -WarningAction SilentlyContinue
```

Creates a YAML string representing the `FileInfo` object of the current script.
The depth is also lowered to `1` to avoid serializing multiple properties and the warning about the depth being exceeded has been silenced.

### Example 3 - Serialize string with a literal style
```powershell
PS C:\> $str = @'
Lorem ipsum dolor sit amet, consectetur adipiscing elit.
Cras rutrum nisl elit, sed elementum tellus porta facilisis.
Suspendisse potenti. In tempus lectus et lacus accumsan commodo vel vitae tortor.
'@ | Add-YamlFormat -ScalarStyle Literal -PassThru
PS C:\> ConvertTo-Yaml @{Key = $str}
# Key: |-
#   Lorem ipsum dolor sit amet, consectetur adipiscing elit.
#   Cras rutrum nisl elit, sed elementum tellus porta facilisis.
#   Suspendisse potenti. In tempus lectus et lacus accumsan commodo vel vitae tortor.
```

Sets the value format to a `Literal` block (`|-`) for a string in a hashtable.
It is important to use `-PassThru` on `Add-YamlFormat` when dealing with string types.
See [Add-YamlFormat](./Add-YamlFormat.md) for more information.

### Example 4 - Serialize using the JSON schema
```powershell
PS C:\> ConvertTo-Yaml @{foo = @(1, 2, 3)} -Schema Yaml12JSON
# {"foo": [1, 2, 3]}
```

Serializes the value using the YAML 1.2 JSON schema.
This schema uses very similar rules to JSON with dicts/lists using the flow style and scalar values being quoted unless they match a JSON literal like a number.

### Example 5 - Serialize list inside a dictionary
```powershell
PS C:\> @{foo = 1, 2, 3} | ConvertTo-Yaml
# foo:
# - 1
# - 2
# - 3
```

Serializes a list of values inside a dictionary.
By default the list values are not indented.

### Example 6 - Serialize list with indented entries
```powershell
PS C:\> @{foo = 1, 2, 3} | ConvertTo-Yaml -IndentSequence
# foo:
#   - 1
#   - 2
#   - 3
```

Serializes a list of values inside a dictionary that are indented.

### Example 7 - Treat input as a list
```powershell
PS C:\> 1 | ConvertTo-Yaml -AsArray
# - 1
```

Treats the input as a single array value to serialize.
Without the `-AsArray` switch, the `1` would be serialized as an integer rather than a list.
This is only needed if there is a single value specified for `-InputObject`.

### Example 8 - Serialize input as stream
```powershell
PS C:\> Get-ExpensiveValue | ConvertTo-Yaml -Stream
# Key: value 1
# Key: value 2

PS C:\> Get-ExpensiveValue | ConvertTo-Yaml -Stream -AsArray
# - Key: value 1
# - Key: value 2
```

Serializes the input as an output YAML string as it is received rather than wait until `Get-ExpensiveValue` is done.
This is useful if the input generator is long running and you wish to emit an object as it is received.
As each output string from the input is it's own distinct YAML string, use `-AsArray` to output YAML sequence friendly values.

## PARAMETERS

### -AsArray
Will create a YAML list string from the input objects as an array.
Use this to ensure the data provided will be a list string even if only 1 value was supplied.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Depth
Specifies how many levels of contained objects are included in the YAML representation.
The default value is `2`.
`ConvertTo-Yaml` emits a warning if the number of levels in an input object exceeds this number.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -IndentSequence
Output block lists with values indented 2 spaces.
The default will be to keep the `-` at the same level as the list declaration.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -InputObject
The objects to convert to YAML format.
This can be null (`$null`) or an empty string.
The input objects can also be passed through the pipeline.
It can be dangerous to use any dotnet object as it could contain a lot of properties or cyclic references that slow down the serialization process.
Try and use your own custom objects created from a dictionary/list/PSCustomObject with only the properties/values that are needed.

```yaml
Type: PSObject
Parameter Sets: (All)
Aliases:

Required: True
Position: 0
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
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

### -Schema
The custom YAML schema to use when parsing the YAML string.
Defaults to `Yaml12`.
This can be a custom schema generated by [New-YamlSchema](./New-YamlSchema.md) or one of the following strings:

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

### -Stream
Serialize each input object as an individual object.
This allows the caller to stream the serialized YAML string as individual output objects rather than wait for the final input to be given before serializating.
Use `-AsArray` to emit each input object as a YAML sequence entry.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.Management.Automation.PSObject
The objects to convert to a YAML string.

## OUTPUTS

### System.String
The YAML string created from the objects provided.

## NOTES
This cmdlet does not support anchors/aliases in the output representation.

## RELATED LINKS
