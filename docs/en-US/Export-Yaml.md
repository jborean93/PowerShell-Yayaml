---
external help file: Yayaml.dll-Help.xml
Module Name: Yayaml
online version: https://www.github.com/jborean93/PowerShell-Yayaml/blob/main/docs/en-US/Export-Yaml.md
schema: 2.0.0
---

# Export-Yaml

## SYNOPSIS
Exports PowerShell objects to YAML-formatted files.

## SYNTAX

### Path (Default)
```
Export-Yaml [-Path] <String[]> [-InputObject] <PSObject> [-Encoding <Encoding>] [-Append] [-Force] [-NoClobber]
 [-AsArray] [-Depth <Int32>] [-IndentSequence] [-Schema <YamlSchema>] [-Stream]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### LiteralPath
```
Export-Yaml [-LiteralPath <String[]>] [-InputObject] <PSObject> [-Encoding <Encoding>] [-Append] [-Force]
 [-NoClobber] [-AsArray] [-Depth <Int32>] [-IndentSequence] [-Schema <YamlSchema>] [-Stream]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
The `Export-Yaml` cmdlet converts PowerShell objects to YAML format and saves them to one or more files.
The output format depends on the input object being serialized.
The [Add-YamlFormat](./Add-YamlFormat.md) cmdlet can be used to control the format of individual values.

By default, the YAML 1.2 core schema will be used when creating the values.
Use the `-Schema` parameter to control what schema is used or to provide a custom schema handler.

To import YAML data from files, use the [Import-Yaml](./Import-Yaml.md) cmdlet.
See [about_YamlEmitting](./about_YamlEmitting.md) for more information on creating YAML strings.

## EXAMPLES

### Example 1 - Export a hashtable to a YAML file
```powershell
PS C:\> @{database = @{host = 'localhost'; port = 5432}} | Export-Yaml -Path config.yml
```

Creates a YAML file `config.yml` containing the database configuration.

### Example 2 - Export with specific encoding
```powershell
PS C:\> $data | Export-Yaml -Path data.yaml -Encoding UTF8Bom
```

Exports the data to a YAML file using UTF-8 encoding with BOM (byte order mark).

### Example 3 - Append to an existing file
```powershell
PS C:\> $newEntry | Export-Yaml -Path log.yaml -Append
```

Appends the new entry to the end of the existing `log.yaml` file.

### Example 4 - Export multiple objects from pipeline
```powershell
PS C:\> Get-Process | Select-Object -First 5 Name, Id | Export-Yaml -Path processes.yaml
```

Exports the first 5 processes to a YAML file.
Each process will be written as a separate YAML document.

### Example 5 - Export with increased depth
```powershell
PS C:\> Get-Item $PSCommandPath | Export-Yaml -Path file.yaml -Depth 5
```

Exports a `FileInfo` object with a depth of 5 levels to serialize more nested properties.

### Example 6 - Prevent overwriting with NoClobber
```powershell
PS C:\> $data | Export-Yaml -Path important.yaml -NoClobber
```

Exports data to a file but fails if the file already exists, preventing accidental overwrites.

### Example 7 - Force overwrite of read-only file
```powershell
PS C:\> $data | Export-Yaml -Path readonly.yaml -Force
```

Exports data to a file, temporarily removing the read-only attribute if necessary, then restoring it after writing.

### Example 8 - Export with indented sequences
```powershell
PS C:\> @{items = 1, 2, 3} | Export-Yaml -Path data.yaml -IndentSequence
```

Exports data with array/list items indented under their parent key rather than at the same indentation level as the key.

### Example 9 - Export to multiple files
```powershell
PS C:\> $config | Export-Yaml -Path config.yaml, backup.yaml
```

Exports the same configuration to both `config.yaml` and `backup.yaml`.

### Example 10 - Export with LiteralPath
```powershell
PS C:\> $data | Export-Yaml -LiteralPath '.\output[1].yaml'
```

Exports to a file with special characters in the filename using `-LiteralPath` to prevent wildcard expansion.

## PARAMETERS

### -Append
Adds the YAML output to the end of an existing file.
Without this parameter, `Export-Yaml` replaces the file contents without warning.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -AsArray
Used when pipeling a single object, this ensures the output is an array/list rather than that individual object.
Use this to ensure the data provided will be a list string even if only 1 value was supplied.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Depth
Specifies how many levels of contained objects are included in the YAML representation.
The default value is `2`.
`Export-Yaml` emits a warning if the number of levels in an input object exceeds this number.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 2
Accept pipeline input: False
Accept wildcard characters: False
```

### -Encoding
Specifies the encoding for the output file.
The default is UTF-8 without BOM.

The acceptable values for this parameter are:

+ `ASCII` - Uses the encoding for the ASCII (7-bit) character set
+ `ANSI` - Uses the encoding for the current culture's ANSI code page
+ `OEM` - Uses the encoding for the current console's code page
+ `Unicode` - Encodes in UTF-16 format using the little-endian byte order
+ `UTF8` - Encodes in UTF-8 format without Byte Order Mark (BOM)
+ `UTF8Bom` - Encodes in UTF-8 format with Byte Order Mark (BOM)
+ `UTF8NoBom` - Encodes in UTF-8 format without Byte Order Mark (BOM)

You can also specify an encoding by code page number (e.g., `437`) or by passing an `Encoding` object.

```yaml
Type: Encoding
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Force
Forces the cmdlet to overwrite an existing read-only file.
When used with `-Force`, the read-only attribute is temporarily removed to allow writing, then restored after the operation completes.
Even with `-Force`, the cmdlet cannot override security restrictions.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
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
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -InputObject
The objects to convert to YAML format and write to the file.
This can be null (`$null`) or an empty string.
The input objects can also be passed through the pipeline.
It can be dangerous to use any dotnet object as it could contain a lot of properties or cyclic references that slow down the serialization process.
Try and use your own custom objects created from a dictionary/list/PSCustomObject with only the properties/values that are needed.

```yaml
Type: PSObject
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -LiteralPath
Specifies the path to the output file.
Unlike `-Path`, the value of `-LiteralPath` is used exactly as typed.
No characters are interpreted as wildcards.

```yaml
Type: String[]
Parameter Sets: LiteralPath
Aliases: PSPath

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -NoClobber
Prevents overwriting an existing file.
By default, if a file exists in the specified path, `Export-Yaml` overwrites the file without warning.
With `-NoClobber`, `Export-Yaml` does not overwrite the file and displays an error message.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Path
Specifies the path to the output file.
Wildcards are permitted but typically not useful for output operations.

```yaml
Type: String[]
Parameter Sets: Path
Aliases:

Required: True
Position: 0
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

### -Schema
The custom YAML schema to use when creating the YAML output.
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
Default value: Yaml12
Accept pipeline input: False
Accept wildcard characters: False
```

### -Stream
{{ Fill Stream Description }}

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

### -Confirm
Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIf
Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

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
The objects to convert to a YAML string and write to file.

## OUTPUTS

### None
This cmdlet does not produce any output.

## NOTES
This cmdlet does not support anchors/aliases in the output representation.

## RELATED LINKS

[Import-Yaml](./Import-Yaml.md)

[ConvertTo-Yaml](./ConvertTo-Yaml.md)

[about_YamlEmitting](./about_YamlEmitting.md)
