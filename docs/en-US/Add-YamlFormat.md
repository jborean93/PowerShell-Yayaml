---
external help file: Yayaml.Module.dll-Help.xml
Module Name: Yayaml
online version: https://www.github.com/jborean93/PowerShell-Yayaml/blob/main/docs/en-US/Add-YamlFormat.md
schema: 2.0.0
---

# Add-YamlFormat

## SYNOPSIS
Adds formatting info for use with `ConvertTo-Yaml` to an object.

## SYNTAX

```
Add-YamlFormat [-InputObject] <PSObject> [-ScalarStyle <ScalarStyle>] [-CollectionStyle <CollectionStyle>]
 [-PassThru] [-Comment <String>] [-PreComment <String>] [-PostComment <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
The `Add-YamlFormat` cmdlet can be used to add YAML formatting information to an object to be serialized.
Currently the only formatting information that can be set are scalar and collection styles.

Scalar values (simple types like strings, ints, etc) can be set to the following styles:

+ `Any` - Uses the schema rules

+ `Plain` - The value will not be quoted `foo: bar`

+ `SingleQuoted` - The value will be quoted with single quotes `foo: 'bar'`

+ `DoubleQuoted` - The value will be quoted with double quotes `foo: "bar"`

+ `Literal` - The value will use a literal block `foo: |-\n  bar`

+ `Folded` - The value will use a folding block `foo: >-\n  bar`

Depending on the value, the emitter might add a tag to the value to avoid any ambiguity when parsing the YAML string.
It is not currently possible to control the chomping and indentation values used in the `Literal` and `Folded` styles due to limitations in the underlying dotnet library.

Collections values can be set to the following styles:

+ `Any` - Uses the schema rules

+ `Block` - Dicts become `foo: bar` and lists become `- 1`

+ `Flow` - Dicts become `{foo: bar}` and lists become `[1]`

## EXAMPLES

### Example 1 - Set a string to be emitted with a literal block
```powershell
PS C:\> $str = 'value' | Add-YamlFormat -ScalarStyle Literal -PassThru
PS C:\> ConvertTo-Yaml $str
# |-
#   value
```

Sets the string variable to be emitted as a literal block.
It is important to pipe string values into this cmdlet and use `-PassThru` to capture the formatting value.

### Example 2 - Set a dictionary like value to be emitted as a flow block
```powershell
PS C:\> $obj = [PSCustomObject]@{Foo = 1}
PS C:\> $obj | Add-YamlFormat -CollectionStyle Flow
PS C:\> $obj | ConvertTo-Yaml
# {Foo: 1}
```

Sets the dictionary like value to be emitted as a flow collection.
Unlike the string type, `-PassThru` isn't needed for this to work although it can still be used if desired.

### Example 3 - Add comments to the serialized YAML string
```powershell
PS C:\> $obj = [Ordered]@{
    Key1 = 'value' | Add-YamlFormat -PreComment "Comment before key" -PassThru
    Key2 = 'value' | Add-YamlFormat -Comment "Comment inline" -PassThru
    Key3 = 'value' | Add-YamlFormat -PostComment "Comment after key" -PassThru
    Key4 = 'value'
}
PS C:\> $obj | ConvertTo-Yaml
# # Comment before key
# Key1: value
# Key2: value # Comment inline
# Key3: value
# # Comment after key
# Key4: value
```

Adds comments to an object for serialization.
See [about_YamlEmitting](./about_YamlEmitting.md) for more details around how comments are serialized and the rules around them.

## PARAMETERS

### -CollectionStyle
The style to use for collections (dictionaries and lists).
Can be:

+ `Any`

+ `Block`

+ `Flow`

```yaml
Type: CollectionStyle
Parameter Sets: (All)
Aliases:
Accepted values: Any, Block, Flow

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Comment
Serializes the input value with an inline comment.
An inline comment is a comment placed at the end of the value.
See [about_YamlEmitting](./about_YamlEmitting.md) for more information around comment serialization.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -InputObject
The object to add the YAML formatting information to.

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

### -PassThru
Returns an object representing the item with which you are working.
By default, this cmdlet doesn't generate any output.

Typically this does not need to be set for reference types like dictionaries or arrays but it is recommended to use this for simple types like strings or integers.
Strings especially can be problematic as they need to be implicitly wrapped as a `PSObject` which this cmdlet will do and output as needed.

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

### -PostComment
Serializes the input value with a comment placed after the value on the newline.
See [about_YamlEmitting](./about_YamlEmitting.md) for more information around comment serialization.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PreComment
Serializes the input value with a comment placed before the value with the value on the next line after the comment.
See [about_YamlEmitting](./about_YamlEmitting.md) for more information around comment serialization.

```yaml
Type: String
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

### -ScalarStyle
The style used for scalar values (not dictionaries or lists).
Can be:

+ `Any`

+ `Plain`

+ `SingleQuoted`

+ `DoubleQuoted`

+ `Literal`

+ `Folded`

```yaml
Type: ScalarStyle
Parameter Sets: (All)
Aliases:
Accepted values: Any, Plain, SingleQuoted, DoubleQuoted, Literal, Folded

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
Any objects piped into this cmdlet will have the formatting information applied.

## OUTPUTS

### System.Object
By default, this cmdlet returns no output. When the `-PassThru` switch is specified, the cmdlet will return the extended input value.

## NOTES

## RELATED LINKS
