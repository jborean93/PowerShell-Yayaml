# Copyright: (c) 2023, Jordan Borean (@jborean93) <jborean93@gmail.com>
# MIT License (see LICENSE or https://opensource.org/licenses/MIT)

$importModule = Get-Command -Name Import-Module -Module Microsoft.PowerShell.Core
$moduleName = [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)

if (-not $IsCoreClr) {
    # PowerShell 5.1 has no concept of an Assembly Load Context so it will
    # just load the module assembly directly.

    $innerMod = if ('Yayaml.Module.NewYamlSchemaCommand' -as [type]) {
        $modAssembly = [Yayaml.Module.NewYamlSchemaCommand].Assembly
        &$importModule -Assembly $modAssembly -Force -PassThru
    }
    else {
        $modPath = [System.IO.Path]::Combine($PSScriptRoot, 'bin', 'net472', "$moduleName.Module.dll")
        &$importModule -Name $modPath -ErrorAction Stop -PassThru
    }
}
else {
    # This is used to load the shared assembly in the Default ALC which then sets
    # an ALC for the moulde and any dependencies of that module to be loaded in
    # that ALC.

    $isReload = $true
    if (-not ('Yayaml.LoadContext' -as [type])) {
        $isReload = $false

        Add-Type -Path ([System.IO.Path]::Combine($PSScriptRoot, 'bin', 'net6.0', "$moduleName.dll"))
    }

    $mainModule = [Yayaml.LoadContext]::Initialize()
    $innerMod = &$importModule -Assembly $mainModule -PassThru:$isReload
}

if ($innerMod) {
    # Bug in pwsh, Import-Module in an assembly will pick up a cached instance
    # and not call the same path to set the nested module's cmdlets to the
    # current module scope.
    # https://github.com/PowerShell/PowerShell/issues/20710
    $addExportedCmdlet = [System.Management.Automation.PSModuleInfo].GetMethod(
        'AddExportedCmdlet',
        [System.Reflection.BindingFlags]'Instance, NonPublic'
    )
    foreach ($cmd in $innerMod.ExportedCommands.Values) {
        $addExportedCmdlet.Invoke($ExecutionContext.SessionState.Module, @(, $cmd))
    }
}

# Use this for testing that the dlls are loaded correctly and outside the Default ALC.
# [System.AppDomain]::CurrentDomain.GetAssemblies() |
#     Where-Object { $_.GetName().Name -like "*yaml*" } |
#     ForEach-Object {
#         $alc = [Runtime.Loader.AssemblyLoadContext]::GetLoadContext($_)
#         [PSCustomObject]@{
#             Name = $_.FullName
#             Location = $_.Location
#             ALC = $alc
#         }
#     } | Format-List
