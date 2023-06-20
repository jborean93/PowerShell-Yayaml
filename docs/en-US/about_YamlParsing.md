# YAML Parsing
## about_YamlParsing

# SHORT DESCRIPTION
Short description here.

# LONG DESCRIPTION

```powershell
$yaml[[Yayaml.Nullkey]::Value]

# or

$yaml.([Yayaml.NullKey]::Value)
```

Numeric keys need to be retrieved using the property syntax or using an explicitly casted `[object]` item value.
This is because an int value will lookup the key at that index instead of by the key value.

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
