# Copyright: (c) 2023, Jordan Borean (@jborean93) <jborean93@gmail.com>
# MIT License (see LICENSE or https://opensource.org/licenses/MIT)

$moduleName = [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)
Add-Type -Path ([System.IO.Path]::Combine($PSScriptRoot, 'bin', 'net6.0', "$moduleName.Shared.dll"))

$mainModule = [Yayaml.Shared.LoadContext]::Initialize()
Import-Module -Assembly $mainModule

# Export-ModuleMember -Cmdlet Test-MyCommand
