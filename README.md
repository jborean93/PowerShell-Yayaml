# PowerShell-Yayaml

[![Test workflow](https://github.com/jborean93/PowerShell-Yayaml/workflows/Test%20Yayaml/badge.svg)](https://github.com/jborean93/PowerShell-Yayaml/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/jborean93/PowerShell-Yayaml/branch/main/graph/badge.svg?token=b51IOhpLfQ)](https://codecov.io/gh/jborean93/PowerShell-Yayaml)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/Yayaml.svg)](https://www.powershellgallery.com/packages/Yayaml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/jborean93/PowerShell-Yayaml/blob/main/LICENSE)

Yet Another YAML PowerShell parser and writer.
While there are a few other YAML modules out on the gallery this module includes the following features:

+ YAML 1.2 parser and emitter
+ YAML 1.2 JSON parser and emitter
+ Support for custom schemas
+ Finer control over scalar, map, and sequence styles
+ Loads `YamlDotNet` in an Assembly Load Context to avoid DLL hell and cross assembly conflicts (PowerShell 7+ only)

There are schemas that support YAML 1.2 (default), 1.2 JSON, 1.1, and failsafe values.

See [Yayaml index](docs/en-US/Yayaml.md) for more details.

## Requirements

These cmdlets have the following requirements

* PowerShell v5.1 or newer

## Examples

Creating a YAML string is as simple as providing an object to serialize:

```powerhell
$obj = [PSCustomObject]@{
    Key = 'value'
    Testing = 1, 2, 3
}

$obj | ConvertTo-Yaml
```

Produces

```yaml
Key: value
Testing:
- 1
- 2
- 3
```

Parsing a YAML string to an object:

```powershell
$obj = $yaml | ConvertFrom-Yaml
$obj.Key
$obj.Testing
```

The behaviour of these two cmdlets try to follow the `ConvertTo-Json` and `ConvertFrom-Json` cmdlets.

## Installing

The easiest way to install this module is through [PowerShellGet](https://docs.microsoft.com/en-us/powershell/gallery/overview).

You can install this module by running;

```powershell
# Install for only the current user
Install-Module -Name Yayaml -Scope CurrentUser

# Install for all users
Install-Module -Name Yayaml -Scope AllUsers
```

## Contributing

Contributing is quite easy, fork this repo and submit a pull request with the changes.
To build this module run `.\build.ps1 -Task Build` in PowerShell.
To test a build run `.\build.ps1 -Task Test` in PowerShell.
This script will ensure all dependencies are installed before running the test suite.
