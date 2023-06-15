# PowerShell-Yayaml

[![Test workflow](https://github.com/jborean93/PowerShell-yayaml/workflows/Test%20yayaml/badge.svg)](https://github.com/jborean93/PowerShell-yayaml/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/jborean93/PowerShell-yayaml/branch/main/graph/badge.svg?token=b51IOhpLfQ)](https://codecov.io/gh/jborean93/PowerShell-yayaml)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/PowerShell-yayaml.svg)](https://www.powershellgallery.com/packages/PowerShell-yayaml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/jborean93/PowerShell-yayaml/blob/main/LICENSE)

Yet Another PowerShell YAML parser and writer.
While there are a few other YAML modules out on the gallery this is designed to take advantage of Assembly Load Contexts (ALC) to avoid being impacted by other modules already loading YamlDotNet like platyPS.

See [Yayaml index](docs/en-US/Yayaml.md) for more details.

## Requirements

These cmdlets have the following requirements

* PowerShell v7.2 or newer

## Examples

TODO

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
