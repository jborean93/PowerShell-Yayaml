@{
    DotnetProject = 'Yayaml.Module'
    InvokeBuildVersion = '5.14.23'
    PesterVersion = '5.8.0'
    BuildRequirements = @(
        @{
            ModuleName = 'Microsoft.PowerShell.PSResourceGet'
            ModuleVersion = '1.2.0'
        }
        @{
            ModuleName = 'OpenAuthenticode'
            RequiredVersion = '0.6.3'
        }
        @{
            ModuleName = 'platyPS'
            RequiredVersion = '0.14.2'
        }
    )
    TestRequirements = @()
}
