. ([IO.Path]::Combine($PSScriptRoot, 'common.ps1'))

$global:n = [System.Environment]::NewLine

Describe "Add-YamlFormat" {
    It "Emits error when using null as input" {
        $actual = $null | Add-YamlFormat -ScalarStyle DoubleQuoted -ErrorAction SilentlyContinue -ErrorVariable err
        $actual | Should -BeNullOrEmpty
        $err.Count | Should -Be 1
        [string]$err[0] | Should -Be "Cannot bind argument to parameter 'InputObject' because it is null."
    }
}
