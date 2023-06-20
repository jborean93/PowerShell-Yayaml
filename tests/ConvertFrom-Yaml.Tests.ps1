. ([IO.Path]::Combine($PSScriptRoot, 'common.ps1'))

Describe "ConvertFrom-Yaml" {
    Context "General Parsing" {
        It "Parses dictionary value" {
            $actual = ConvertFrom-Yaml @'
foo: bar
test: 1
1: abc
'2': def
'@

            $actual.Keys.Count | Should -Be 4
            $actual.foo | Should -Be bar
            $actual['foo'] | Should -Be bar
            $actual.test | Should -Be 1
            $actual['test'] | Should -Be 1
            $actual.1 | Should -Be abc
            $actual."2" | Should -Be def
            $actual['2'] | Should -Be def
        }

        It "Parses single array value" {
            $actual = ConvertFrom-Yaml @'
- 1
'@

            $actual | Should -BeOfType ([int])
            $actual | Should -Be 1
            $actual[0] | Should -Be 1
        }

        It "Parses single array value with -NoEnumerate" {
            $actual = ConvertFrom-Yaml @'
- 1
'@ -NoEnumerate

            $actual | Should -BeOfType ([object[]])
            $actual.Count | Should -Be 1
            $actual[0] | Should -Be 1
        }

        It "Parses multiple documents" {
            $actual = ConvertFrom-Yaml @'
---
doc: 1

---
doc: 2
'@

            $actual.Count | Should -Be 2
            $actual[0].Keys.Count | Should -Be 1
            $actual[0].doc | Should -Be 1
            $actual[1].Keys.Count | Should -Be 1
            $actual[1].doc | Should -Be 2
        }

        It "Parses with pipeline input" {
            $actual = 'foo: bar', 'test: 1' | ConvertFrom-Yaml
            $actual.Keys.Count | Should -Be 2
            $actual.foo | Should -Be bar
            $actual.test | Should -Be 1
        }

        It "Fails with parse error" {
            $actual = ConvertFrom-Yaml 'foo: bar: 1' -ErrorAction SilentlyContinue -ErrorVariable err
            $actual | Should -BeNullOrEmpty
            $err.Count | Should -Be 1
            [string]$err[0] | Should -Be 'While scanning a plain scalar value, found invalid mapping.'
            $err[0].CategoryInfo.Category | Should -Be ParserError
        }

        It "Parses with complex map key" {
            $actual = ConvertFrom-Yaml '[1, 2]: value'

            $actual.Keys.Count | Should -Be 1
            $actual.Keys[0].Count | Should -Be 2
            $actual.Keys[0][0] | Should -Be 1
            $actual.Keys[0][1] | Should -Be 2
            $actual[$actual.Keys] | Should -Be value
        }

        # FIXME: Implement this
        # It "Parses with null map key" {
        #     $actual = ConvertFrom-Yaml 'null: value'

        #     $actual.Keys.Count | Should -Be 1
        #     $actual.Keys[0] | Should -BeNullOrEmpty
        #     $actual.$null | Should -Be value
        #     $actual[$null] | Should -Be value
        # }
    }

    Context "Blank Schema" {
        It "Parses with blank schema <Value>" -TestCases @(
            @{Value = 'a'; Expected = 'a'}
            @{Value = '1'; Expected = '1'}
            @{Value = 'true'; Expected = 'true'}
            @{Value = 'null'; Expected = 'null'}
        ) {
            $actual = ConvertFrom-Yaml -InputObject $Value -Schema Blank
            $actual | Should -Be $Expected
            $actual | Should -BeOfType([string])
        }
    }

    Context "YAML 1.1 Schema" {

    }

    Context "YAML 1.2 Schema" {
        It "Parsed bool <Value>" -TestCases @(
            @{Value = 'false'; Expected = $false}
            @{Value = 'False'; Expected = $false}
            @{Value = 'FALSE'; Expected = $false}
            @{Value = '!!bool "false"'; Expected = $false}
            @{Value = 'true'; Expected = $true}
            @{Value = 'True'; Expected = $true}
            @{Value = 'TRUE'; Expected = $true}
            @{Value = '!!bool "True"'; Expected = $true}
        ) {
            param ($Value, $Expected)

            $actual = ConvertFrom-Yaml -InputObject $Value
            $actual | Should -Be $Expected
            $actual | Should -BeOfType ([bool])
        }

        It "Fails to parse tagged bool" {
            $res = ConvertFrom-Yaml -InputObject '!!bool yes' -ErrorAction SilentlyContinue -ErrorVariable err
            $res | Should -BeNullOrEmpty
            $err.Count | Should -Be 1
            [string]$err[0] | Should -BeLike "Failed to unpack yaml node 'yes' with tag 'tag:yaml.org,2002:bool': Does not match expected bool values *"
        }

        It "Parses integer <Value>" -TestCases @(
            @{Value = '0o0'; Expected = 0}
            @{Value = '0o1'; Expected = 1}
            @{Value = '0o17777777777'; Expected = 2147483647}
            @{Value = '0o20000000000'; Expected = 2147483648}
            @{Value = '0o777777777777777777777'; Expected = 9223372036854775807}
            @{Value = '0o1000000000000000000000'; Expected = [System.Numerics.BigInteger]::Parse("9223372036854775808")}

            @{Value = '0'; Expected = 0}
            @{Value = '!!int "0"'; Expected = 0}
            @{Value = '-1'; Expected = -1}
            @{Value = '-2147483648'; Expected = -2147483648}
            @{Value = '-2147483649'; Expected = -2147483649}
            @{Value = '-9223372036854775808'; Expected = -9223372036854775808}
            @{Value = '-9223372036854775809'; Expected = [System.Numerics.BigInteger]::Parse("-9223372036854775809")}
            @{Value = '1'; Expected = 1}
            @{Value = '2147483647'; Expected = 2147483647}
            @{Value = '2147483648'; Expected = 2147483648}
            @{Value = '9223372036854775807'; Expected = 9223372036854775807}
            @{Value = '9223372036854775808'; Expected = [System.Numerics.BigInteger]::Parse("9223372036854775808")}

            @{Value = '0x0'; Expected = 0}
            @{Value = '0x1'; Expected = 1}
            @{Value = '0xF'; Expected = 15}
            @{Value = '0x80000000'; Expected = -2147483648}
            @{Value = '0xFFFFFFFF7FFFFFFF'; Expected = -2147483649}
            @{Value = '0x8000000000000000'; Expected = -9223372036854775808}
            @{Value = '0x7FFFFFFF'; Expected = 2147483647}
            @{Value = '0xF00000000'; Expected = 64424509440}
            @{Value = '0x7FFFFFFFFFFFFFFF'; Expected = 9223372036854775807}

        ) {
            param ($Value, $Expected)

            $actual = ConvertFrom-Yaml -InputObject $Value
            $actual | Should -Be $Expected
            $actual | Should -BeOfType $Expected.GetType()
        }

        It "Fails to parse tagged integer" {
            $res = ConvertFrom-Yaml -InputObject '!!int a' -ErrorAction SilentlyContinue -ErrorVariable err
            $res | Should -BeNullOrEmpty
            $err.Count | Should -Be 1
            [string]$err[0] | Should -BeLike "Failed to unpack yaml node 'a' with tag 'tag:yaml.org,2002:int': Does not match expected int value pattern*"
        }

        It "Parses float <Value>" -TestCases @(
            @{Value = '0.'; Expected = [Double]'0' }
            @{Value = '!!float 1'; Expected = [Double]'1'}
            @{Value = '-0.0'; Expected = [Double]'-0' }
            @{Value = '.5'; Expected = [Double]'0.5' }
            @{Value = '+12e03'; Expected = [Double]'12000' }
            @{Value = '-2E+05'; Expected = [Double]'-200000' }
            @{Value = '2E+1000'; Expected = [Double]::PositiveInfinity }
            @{Value = '-2E+1000'; Expected = [Double]::NegativeInfinity }
            @{Value = '.inf'; Expected = [Double]::PositiveInfinity }
            @{Value = '-.Inf'; Expected = [Double]::NegativeInfinity }
            @{Value = '+.INF'; Expected = [Double]::PositiveInfinity }
            @{Value = '.NAN'; Expected = [Double]::NaN }
        ) {
            param ($Value, $Expected)

            $actual = ConvertFrom-Yaml -InputObject $Value
            if ($Expected.ToString() -eq 'NaN') {
                # Normal comparison doesn't work with NaN
                $actual.ToString() | Should -Be 'NaN'
            }
            else {
                $actual | Should -Be $Expected
            }
            $actual | Should -BeOfType ([Double])
        }

        It "Fails to parse tagged float" {
            $res = ConvertFrom-Yaml -InputObject '!!float a' -ErrorAction SilentlyContinue -ErrorVariable err
            $res | Should -BeNullOrEmpty
            $err.Count | Should -Be 1
            [string]$err[0] | Should -Be "Failed to unpack yaml node 'a' with tag 'tag:yaml.org,2002:float': Does not match expected float value pattern"
        }

        It "Parses null <Value>" -TestCases @(
            @{Value = ''}
            @{Value = '~'}
            @{Value = 'null'}
            @{Value = 'Null'}
            @{Value = 'NULL'}
            @{Value = '!!null ""'}
        ) {
            param ($Value)

            $actual = ConvertFrom-Yaml -InputObject $Value
            $actual | Should -Be $null
        }

        It "Fails to parse tagged null" {
            $res = ConvertFrom-Yaml -InputObject '!!null a' -ErrorAction SilentlyContinue -ErrorVariable err
            $res | Should -BeNullOrEmpty
            $err.Count | Should -Be 1
            [string]$err[0] | Should -BeLike "Failed to unpack yaml node 'a' with tag 'tag:yaml.org,2002:null': Does not match expected null values *"
        }

        It "Parses string <Value>" -TestCases @(
            @{Value = 'abc'; Expected = 'abc'}
            @{Value = '!!str 1'; Expected = '1'}
            @{Value = '"1"'; Expected = '1'}
            @{Value = '""'; Expected = ''}
            @{Value = "''"; Expected = ''}
            @{Value = 'yes'; Expected = 'yes'}
            @{Value = "$([Char]::ConvertFromUtf32(0x1F4A9))"; Expected = "$([Char]::ConvertFromUtf32(0x1F4A9))"}
            @{Value = '"\U0001F4A9"'; Expected = "$([Char]::ConvertFromUtf32(0x1F4A9))"}
            @{Value = '\U0001F4A9'; Expected = "\U0001F4A9"}
        ) {
            param ($Value, $Expected)
            $actual = ConvertFrom-Yaml -InputObject $Value
            $actual | Should -Be $Expected
            $actual | Should -BeOfType ([string])
        }

        It "Parses unknown tagged value <Value>" -TestCases @(
            @{Value = '!!random 1'; Expected = '1'}
            @{Value = '!namespace:tag def'; Expected = 'def'}
        ) {
            $actual = ConvertFrom-Yaml -InputObject $Value
            $actual | Should -Be $expected
            $actual | Should -BeOfType ([string])
        }
    }

    Context "YAML 1.2 JSON Schema" {
        It "Parsed bool <Value>" -TestCases @(
            @{Value = 'false'; Expected = $false}
            @{Value = '!!bool "false"'; Expected = $false}
            @{Value = 'true'; Expected = $true}
            @{Value = '!!bool "true"'; Expected = $true}
        ) {
            param ($Value, $Expected)

            $actual = ConvertFrom-Yaml -InputObject $Value -Schema Yaml12JSON
            $actual | Should -Be $Expected
            $actual | Should -BeOfType ([bool])
        }

        It "Fails to parse tagged bool" {
            $res = ConvertFrom-Yaml -InputObject '!!bool True' -Schema Yaml12JSON -ErrorAction SilentlyContinue -ErrorVariable err
            $res | Should -BeNullOrEmpty
            $err.Count | Should -Be 1
            [string]$err[0] | Should -BeLike "Failed to unpack yaml node 'True' with tag 'tag:yaml.org,2002:bool': Does not match expected JSON bool values *"
        }

        It "Parses integer <Value>" -TestCases @(
            @{Value = '0'; Expected = 0}
            @{Value = '!!int "0"'; Expected = 0}
            @{Value = '-1'; Expected = -1}
            @{Value = '-2147483648'; Expected = -2147483648}
            @{Value = '-2147483649'; Expected = -2147483649}
            @{Value = '-9223372036854775808'; Expected = -9223372036854775808}
            @{Value = '-9223372036854775809'; Expected = [System.Numerics.BigInteger]::Parse("-9223372036854775809")}
            @{Value = '1'; Expected = 1}
            @{Value = '2147483647'; Expected = 2147483647}
            @{Value = '2147483648'; Expected = 2147483648}
            @{Value = '9223372036854775807'; Expected = 9223372036854775807}
            @{Value = '9223372036854775808'; Expected = [System.Numerics.BigInteger]::Parse("9223372036854775808")}
        ) {
            param ($Value, $Expected)

            $actual = ConvertFrom-Yaml -InputObject $Value -Schema Yaml12JSON
            $actual | Should -Be $Expected
            $actual | Should -BeOfType $Expected.GetType()
        }

        It "Fails to parse tagged integer" {
            $res = ConvertFrom-Yaml -InputObject '!!int 0x1' -Schema yaml12json -ErrorAction SilentlyContinue -ErrorVariable err
            $res | Should -BeNullOrEmpty
            $err.Count | Should -Be 1
            [string]$err[0] | Should -BeLike "Failed to unpack yaml node '0x1' with tag 'tag:yaml.org,2002:int': Does not match expected JSON int value pattern *"
        }

        It "Parses float <Value>" -TestCases @(
            @{Value = '!!float -1'; Expected = [Double]'-1'}
            @{Value = '!!float 1'; Expected = [Double]'1'}
            @{Value = '1.5'; Expected = [Double]'1.5' }
            @{Value = '-2e+5'; Expected = [Double]'-200000' }
            @{Value = '-2e-5'; Expected = [Double]'-2E-05' }
            @{Value = '2e+1000'; Expected = [Double]::PositiveInfinity }
            @{Value = '-2e+1000'; Expected = [Double]::NegativeInfinity }
            @{Value = '.inf'; Expected = [Double]::PositiveInfinity }
            @{Value = '-.inf'; Expected = [Double]::NegativeInfinity }
            @{Value = '.nan'; Expected = [Double]::NaN }
        ) {
            param ($Value, $Expected)

            $actual = ConvertFrom-Yaml -InputObject $Value -Schema Yaml12JSON
            if ($Expected.ToString() -eq 'NaN') {
                # Normal comparison doesn't work with NaN
                $actual.ToString() | Should -Be 'NaN'
            }
            else {
                $actual | Should -Be $Expected
            }
            $actual | Should -BeOfType ([Double])
        }

        It "Fails to parse tagged float" {
            $res = ConvertFrom-Yaml -InputObject '!!float 1E1' -Schema Yaml12JSON -ErrorAction SilentlyContinue -ErrorVariable err
            $res | Should -BeNullOrEmpty
            $err.Count | Should -Be 1
            [string]$err[0] | Should -Be "Failed to unpack yaml node '1E1' with tag 'tag:yaml.org,2002:float': Does not match expected JSON float value pattern"
        }

        It "Parses null <Value>" -TestCases @(
            @{Value = 'null'}
            @{Value = '!!null null'}
            @{Value = '!!null "null"'}
        ) {
            param ($Value)

            $actual = ConvertFrom-Yaml -InputObject $Value -Schema Yaml12JSON
            $actual | Should -Be $null
        }

        It "Fails to parse tagged null" {
            $res = ConvertFrom-Yaml -InputObject '!!null a' -Schema Yaml12JSON -ErrorAction SilentlyContinue -ErrorVariable err
            $res | Should -BeNullOrEmpty
            $err.Count | Should -Be 1
            [string]$err[0] | Should -Be "Failed to unpack yaml node 'a' with tag 'tag:yaml.org,2002:null': Does not match expected JSON null value null"
        }

        It "Parses string <Value>" -TestCases @(
            @{Value = 'abc'; Expected = 'abc'}
            @{Value = '!!str 1'; Expected = '1'}
            @{Value = '"1"'; Expected = '1'}
            @{Value = '0x1'; Expected = '0x1'}
            @{Value = '""'; Expected = ''}
            @{Value = "''"; Expected = ''}
            @{Value = 'yes'; Expected = 'yes'}
            @{Value = "$([Char]::ConvertFromUtf32(0x1F4A9))"; Expected = "$([Char]::ConvertFromUtf32(0x1F4A9))"}
            @{Value = '"\U0001F4A9"'; Expected = "$([Char]::ConvertFromUtf32(0x1F4A9))"}
            @{Value = '\U0001F4A9'; Expected = "\U0001F4A9"}
        ) {
            param ($Value, $Expected)
            $actual = ConvertFrom-Yaml -InputObject $Value -Schema Yaml12JSON
            $actual | Should -Be $Expected
            $actual | Should -BeOfType ([string])
        }

        It "Parses unknown tagged value <Value>" -TestCases @(
            @{Value = '!!random 1'; Expected = '1'}
            @{Value = '!namespace:tag def'; Expected = 'def'}
        ) {
            $actual = ConvertFrom-Yaml -InputObject $Value -Schema Yaml12JSON
            $actual | Should -Be $expected
            $actual | Should -BeOfType ([string])
        }
    }

    Context "Custom Schema" {
        It "Parses with custom tag handler" {
            $schema = New-YamlSchema -ParseTag @{
                'tag:yaml.org,2002:my_tag' = { 2 }
            }

            $actual = ConvertFrom-Yaml -InputObject "foo: 1`ntest: !!my_tag 2" -Schema $schema
            $actual.Keys.Count | Should -Be 2
            $actual['foo'] | Should -Be 1
            $actual['test'] | Should -Be 2
        }

        It "Parses with custom tag handler with base schema" {
            $schema = New-YamlSchema -ParseTag @{
                'tag:yaml.org,2002:int' = { 1 }
            } -BaseSchema Yaml12JSON

            $actual = ConvertFrom-Yaml -InputObject "foo: !!int 2`ntest: True" -Schema $schema
            $actual.Keys.Count | Should -Be 2
            $actual.foo | Should -Be 1
            $actual.test | Should -Be True
            $actual.test | Should -BeOfType ([string])
        }

        It "Parses with custom tag handler" {
            $schema = New-YamlSchema -ParseScalar {
                param ($Value, $Tag)

                "$Tag|$Value"
            }

            $actual = ConvertFrom-Yaml -InputObject "foo: 1`ntest: !!my_tag 2" -Schema $schema
            $actual.Keys.Count | Should -Be 2
            $actual['?|foo'] | Should -Be '?|1'
            $actual['?|test'] | Should -Be 'tag:yaml.org,2002:my_tag|2'
        }

        It "Parses with custom map" {
            $schema = New-YamlSchema -ParseMap {
                param ($Values, $Tag)

                $Values
            }

            $actual = ConvertFrom-Yaml -InputObject "foo: 1`nbar: hello" -Schema $schema
            $actual.Length | Should -Be 2
            $actual[0].Key | Should -Be foo
            $actual[0].Value | Should -Be 1
            $actual[1].Key | Should -Be bar
            $actual[1].Value | Should -Be hello
        }

        It "Parses with custom sequence" {
            $schema = New-YamlSchema -ParseSequence {
                param ($Values, $Tag)

                $res = @{}
                for ($i = 0; $i -lt $Values.Length; $i++) {
                    $res[$i] = $Values[$i]
                }

                $res
            }

            $actual = ConvertFrom-Yaml -InputObject "['foo', 'bar']" -Schema $schema
            $actual | Should -BeOfType ([Hashtable])
            $actual.Keys.Count | Should -Be 2
            $actual[0] | Should -Be foo
            $actual[1] | Should -Be bar
        }

        It "Parses with generated schema" {
            $schema = New-YamlSchema -BaseSchema Yaml12JSON
            $actual = ConvertFrom-Yaml -InputObject 'True' -Schema $schema
            $actual | Should -Be 'True'
            $actual | Should -BeOfType ([string])
        }
    }
}
