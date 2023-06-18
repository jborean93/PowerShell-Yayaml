. ([IO.Path]::Combine($PSScriptRoot, 'common.ps1'))

Describe "ConvertFrom-Yaml" {
    It "Converts string" {
        $actual = ConvertFrom-Yaml -InputObject 'foo'
        $actual | Should -BeOfType ([string])
        $actual | Should -Be foo
    }

    It "Converts int <Value>" -TestCases @(
        @{Value = 1 }
    ) {
        param($Value)
        $actual = ConvertFrom-Yaml -InputObject $Value.ToString()
        $actual | Should -BeOfType $Value.GetType()
        $actual | Should -Be $Value
    }

    It "Converts dict" {
        $actual = ConvertFrom-Yaml -InputObject @'
foo: bar
testing: 123
nested:
  key1: 1
  key2: 2
  abc: def
  bool: true
'@
        $a = ""
    }

    It "Converts list" {

    }

    It "Converts 1.2 spec text" {

    }

    It "Converts multiple documents" {
        $actual = ConvertFrom-Yaml -InputObject @'
---
key: value

---
key: value
'@

    }

    It "Fails on invalid yaml" {

    }
}
