using namespace System.IO

[CmdletBinding()]
param(
    [Parameter()]
    [switch]
    $NoExit
)

$ErrorActionPreference = 'Stop'

$projectRoot = [Path]::GetFullPath([Path]::Combine($PSScriptRoot, '..'))
$moduleName = (Get-Item ([Path]::Combine($projectRoot, 'module', '*.psd1'))).BaseName
$modulePath = [Path]::Combine($projectRoot, 'output', $moduleName)

Import-Module -Name $modulePath

if ($NoExit) {
    $Host.EnterNestedPrompt()
}
