---
external help file: Yayaml.dll-Help.xml
Module Name: Yayaml
online version: https://www.github.com/jborean93/PowerShell-Yayaml/blob/main/docs/en-US/Import-Yaml.md
schema: 2.0.0
---

# Import-Yaml

## SYNOPSIS
Imports YAML data from a file and converts it to PowerShell objects.

## SYNTAX

### Path (Default)
```
Import-Yaml [-Path] <String[]> [-Encoding <Encoding>] [-NoEnumerate] [-Schema <YamlSchema>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### LiteralPath
```
Import-Yaml [-LiteralPath <String[]>] [-Encoding <Encoding>] [-NoEnumerate] [-Schema <YamlSchema>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
The `Import-Yaml` cmdlet imports YAML data from one or more files and converts the YAML-formatted content to PowerShell objects.
Dictionary values are outputted as an `OrderedDictionary` and list values are outputted as an `Object[]`.

By default, the YAML 1.2 core schema will be used when parsing values.
Use the `-Schema` parameter to control what schema is used or to provide a custom schema handler.

To export PowerShell objects to YAML files, use the [Export-Yaml](./Export-Yaml.md) cmdlet.
See [about_YamlParsing](./about_YamlParsing.md) for more information on parsing YAML data.

## EXAMPLES

### Example 1 - Import YAML from a file
```powershell
PS C:\> $config = Import-Yaml -Path config.yml
PS C:\> $config.database.host  # localhost
```

Imports the YAML data from `config.yml` and stores it in the `$config` variable.
The YAML keys can be accessed like any other dictionary object in PowerShell.

### Example 2 - Import YAML files using wildcards
```powershell
PS C:\> $configs = Import-Yaml -Path .\configs\*.yml
```

Imports all `.yml` files from the `configs` directory.
Each file's contents will be a separate object in the `$configs` array.

### Example 3 - Import with specific encoding
```powershell
PS C:\> Import-Yaml -Path data.yaml -Encoding UTF8Bom
```

Imports the YAML file using UTF-8 encoding with BOM (byte order mark).

### Example 4 - Import using LiteralPath for special characters
```powershell
PS C:\> Import-Yaml -LiteralPath '.\file[1].yaml'
```

Imports a YAML file with special characters in the filename using `-LiteralPath` to prevent wildcard expansion.

### Example 5 - Import with NoEnumerate
```powershell
PS C:\> $yaml = @'
- entry
'@
PS C:\> $yaml | Set-Content single.yaml
PS C:\> $obj1 = Import-Yaml single.yaml
PS C:\> $obj2 = Import-Yaml single.yaml -NoEnumerate
PS C:\> $obj1.GetType()  # String
PS C:\> $obj2.GetType()  # object[]
```

Imports a YAML file containing a single array element with and without `-NoEnumerate`.
The `$obj1` will contain just `entry` as a string as the output was enumerated internally.
The `$obj2` will be the array with a single entry of `entry` as the output was not enumerated internally.

### Example 6 - Import using YAML 1.1 schema
```powershell
PS C:\> $obj = Import-Yaml config.yaml -Schema Yaml11
PS C:\> $obj.enabled  # $true (boolean in YAML 1.1)
```

Imports a YAML file using the YAML 1.1 schema, which has different boolean parsing rules (e.g., 'yes'/'no' are booleans).

### Example 7 - Import multiple files from pipeline
```powershell
PS C:\> Get-ChildItem *.yaml | Import-Yaml
```

Imports all YAML files in the current directory by piping `FileInfo` objects to `Import-Yaml`.

## PARAMETERS

### -Encoding
Specifies the encoding of the YAML file.
The default is UTF-8 without BOM.
The cmdlet automatically detects the encoding if a BOM is present.

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

### -LiteralPath
Specifies the path to one or more YAML files.
Unlike `-Path`, the value of `-LiteralPath` is used exactly as typed.
No characters are interpreted as wildcards.

```yaml
Type: String[]
Parameter Sets: LiteralPath
Aliases: PSPath

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -NoEnumerate
Specifies that the output from the YAML parse operation is not enumerated.
If the YAML file has a root object that is a list/array, each entry will be enumerated as individual objects.
By specifying `-NoEnumerate`, the list/array itself is output as an individual object preserving the raw array type.

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
Specifies the path to one or more YAML files to import.
Wildcards are permitted.

```yaml
Type: String[]
Parameter Sets: Path
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
The custom YAML schema to use when parsing the YAML file.
Defaults to `Yaml12`.
This can be a custom schema generated by [New-YamlSchema](./New-YamlSchema.md) or one of the following strings:

+ `Blank` - no schema data is used, scalar values are read as strings

+ `Yaml11` - YAML 1.1 rules

+ `Yaml12` - YAML 1.2 rules

+ `Yaml12JSON` - Subset of YAML 1.2 that are stricter for JSON compatibility

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String[]
You can pipe file paths to this cmdlet.

## OUTPUTS

### System.Object
The .NET objects that were created from the YAML file contents.

## NOTES
This cmdlet reads the entire file content into memory before parsing.
For very large files, consider using `Get-Content | ConvertFrom-Yaml` with streaming if memory is a concern.

## RELATED LINKS

[Export-Yaml](./Export-Yaml.md)

[ConvertFrom-Yaml](./ConvertFrom-Yaml.md)

[about_YamlParsing](./about_YamlParsing.md)
