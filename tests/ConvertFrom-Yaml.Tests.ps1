. ([IO.Path]::Combine($PSScriptRoot, 'common.ps1'))

$global:n = [System.Environment]::NewLine

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
            $actual[0] | Should -Be bar

            $actual.test | Should -Be 1
            $actual['test'] | Should -Be 1
            $actual[1] | Should -Be 1

            $actual.1 | Should -Be abc
            $actual[2] | Should -Be abc

            $actual[[object]1] | Should -Be abc
            $actual."2" | Should -Be def
            $actual['2'] | Should -Be def
            $actual[3] | Should -Be def
        }

        It "Parses single array value" {
            $actual = ConvertFrom-Yaml @'
- 1
'@

            Should -ActualValue $actual -BeOfType ([int])
            $actual | Should -Be 1
            $actual[0] | Should -Be 1
        }

        It "Parses single array value with -NoEnumerate" {
            $actual = ConvertFrom-Yaml @'
- 1
'@ -NoEnumerate

            Should -ActualValue $actual -BeOfType ([object[]])
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
            if ($PSVersionTable.PSVersion -lt [Version]'7.3') {
                $actual.Keys[0].GetEnumerator().Count | Should -Be 2
                @($actual.Keys.GetEnumerator())[0][0] | Should -Be 1
                @($actual.Keys.GetEnumerator())[0][1] | Should -Be 2
            }
            else {
                $actual.Keys[0].Count | Should -Be 2
                $actual.Keys[0][0] | Should -Be 1
                $actual.Keys[0][1] | Should -Be 2
            }

            $actual[$actual.Keys] | Should -Be value
        }

        It "Parses with null map key" {
            $actual = ConvertFrom-Yaml 'null: value'

            $actual.Keys.Count | Should -Be 1
            $actual.Keys[0] | Should -Be ([Yayaml.NullKey]::Value)
            $actual.([Yayaml.NullKey]::Value) | Should -Be value
            $actual[[Yayaml.NullKey]::Value] | Should -Be value
        }

        It "Parses YAML with anchors" {
            $actual = ConvertFrom-Yaml @'
dict:
  entry1: &anchor
    key1: value 1
    key2: value 2
  entry2: *anchor

list:
- &flag Apple
- Beachball
- Cartoon
- Duckface
- *flag
'@

            $actual.Keys.Count | Should -Be 2

            $actual.dict.Keys.Count | Should -Be 2
            $actual.dict.entry1.Keys.Count | Should -Be 2
            $actual.dict.entry1.key1 | Should -Be 'value 1'
            $actual.dict.entry1.key2 | Should -Be 'value 2'
            $actual.dict.entry2.Keys.Count | Should -Be 2
            $actual.dict.entry2.key1 | Should -Be 'value 1'
            $actual.dict.entry2.key2 | Should -Be 'value 2'

            $actual.list.Count | Should -Be 5
            $actual.list[0] | Should -Be Apple
            $actual.list[1] | Should -Be Beachball
            $actual.list[2] | Should -Be Cartoon
            $actual.list[3] | Should -Be Duckface
            $actual.list[4] | Should -Be Apple
        }

        It "Treats non-plain values as a string <Value>" -TestCases @(
            @{Value = "foo: |$n  true"; Expected = "true`n"}
            @{Value = "foo: |-$n  true"; Expected = "true"}
            @{Value = "foo: >$n  true"; Expected = "true`n"}
            @{Value = "foo: >-$n  true"; Expected = "true"}
        ) {
            param ($Value, $Expected)

            $actual = ConvertFrom-Yaml -InputObject $Value
            $actual.foo | Should -Be $Expected
            $actual.foo | Should -BeOfType ([string])
        }
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
        It "Parses binary <Value>" -TestCases @(
            @{Value = 'foo: !!binary dGVzdA=='; Expected = '74657374'}
            @{Value = 'foo: !!binary dG VzdA=='; Expected = '74657374'}
            @{Value = "foo: !!binary |$n  dG`r  Vz`r$n  dA$n  =="; Expected = '74657374'}
        ) {
            param ($Value, $Expected)

            $actual = (ConvertFrom-Yaml -InputObject $Value -Schema Yaml11).foo
            Should -ActualValue $actual -BeOfType ([byte[]])
            [System.Convert]::ToHexString($actual) | Should -Be $Expected
        }
        It "Parses bool <Value>" -TestCases @(
            @{Value = 'n'; Expected = $false}
            @{Value = 'N'; Expected = $false}
            @{Value = 'no'; Expected = $false}
            @{Value = 'No'; Expected = $false}
            @{Value = 'NO'; Expected = $false}
            @{Value = 'false'; Expected = $false}
            @{Value = 'False'; Expected = $false}
            @{Value = 'FALSE'; Expected = $false}
            @{Value = 'off'; Expected = $false}
            @{Value = 'Off'; Expected = $false}
            @{Value = 'OFF'; Expected = $false}
            @{Value = '!!bool "false"'; Expected = $false}
            @{Value = 'y'; Expected = $true}
            @{Value = 'Y'; Expected = $true}
            @{Value = 'yes'; Expected = $true}
            @{Value = 'Yes'; Expected = $true}
            @{Value = 'YES'; Expected = $true}
            @{Value = 'true'; Expected = $true}
            @{Value = 'True'; Expected = $true}
            @{Value = 'TRUE'; Expected = $true}
            @{Value = 'on'; Expected = $true}
            @{Value = 'On'; Expected = $true}
            @{Value = 'ON'; Expected = $true}
            @{Value = '!!bool "True"'; Expected = $true }
        ) {
            param ($Value, $Expected)

            $actual = ConvertFrom-Yaml -InputObject $Value -Schema Yaml11
            $actual | Should -Be $Expected
            $actual | Should -BeOfType ([bool])
        }

        It "Fails to parse tagged bool" {
            $res = ConvertFrom-Yaml -InputObject '!!bool TruE' -Schema Yaml11 -ErrorAction SilentlyContinue -ErrorVariable err
            $res | Should -BeNullOrEmpty
            $err.Count | Should -Be 1
            [string]$err[0] | Should -Be "Failed to unpack yaml node 'TruE' with tag 'tag:yaml.org,2002:bool': Does not match expected bool values"
        }

        It "Parses integer <Value>" -TestCases @(
            @{Value = '0b0'; Expected = 0}
            @{Value = '0b1'; Expected = 1}
            @{Value = '+0b1'; Expected = 1}
            @{Value = '-0b1'; Expected = -1}
            @{Value = '0b1010_0111_0100_1010_1110'; Expected = 685230}
            @{Value = '+0b1010_0111_0100_1010_1110'; Expected = 685230}
            @{Value = '-0b1010_0111_0100_1010_1110'; Expected = -685230}

            @{Value = '00'; Expected = 0}
            @{Value = '01'; Expected = 1}
            @{Value = '0_1'; Expected = 1}
            @{Value = '-01'; Expected = -1}
            @{Value = '017777777777'; Expected = 2147483647}
            @{Value = '+017777_777777'; Expected = 2147483647}
            @{Value = '-017777777777'; Expected = -2147483647}
            @{Value = '020000_000000'; Expected = 2147483648}
            @{Value = '+020000000000'; Expected = 2147483648}
            @{Value = '-020000000000'; Expected = -2147483648}
            @{Value = '077777777777_7777777777'; Expected = 9223372036854775807}
            @{Value = '+0777777_777777777777777'; Expected = 9223372036854775807}
            @{Value = '-0777777777777777777777'; Expected = -9223372036854775807}
            @{Value = '01000000000000000000000'; Expected = [System.Numerics.BigInteger]::Parse("9223372036854775808")}
            @{Value = '+01000000000000000000000'; Expected = [System.Numerics.BigInteger]::Parse("9223372036854775808")}
            @{Value = '01_000_000_000_000_000_000_000'; Expected = [System.Numerics.BigInteger]::Parse("9223372036854775808")}

            @{Value = '0'; Expected = 0}
            @{Value = '!!int "0"'; Expected = 0}
            @{Value = '1'; Expected = 1}
            @{Value = '+1'; Expected = 1}
            @{Value = '-1'; Expected = -1}
            @{Value = '-2147483648'; Expected = -2147483648}
            @{Value = '-2147483649'; Expected = -2147483649}
            @{Value = '-9223372036854775808'; Expected = -9223372036854775808}
            @{Value = '-9223372036854775809'; Expected = [System.Numerics.BigInteger]::Parse("-9223372036854775809")}
            @{Value = '1'; Expected = 1}
            @{Value = '2147483647'; Expected = 2147483647}
            @{Value = '2147483648'; Expected = 2147483648}
            @{Value = '2_147_483_648'; Expected = 2147483648}
            @{Value = '9223372036854775807'; Expected = 9223372036854775807}
            @{Value = '9223372036854775808'; Expected = [System.Numerics.BigInteger]::Parse("9223372036854775808")}

            @{Value = '0x0'; Expected = 0}
            @{Value = '0x1'; Expected = 1}
            @{Value = '0xF'; Expected = 15}
            @{Value = '+0xF'; Expected = 15}
            @{Value = '-0xF'; Expected = -15}
            @{Value = '0x80000000'; Expected = -2147483648}
            @{Value = '+0x80000000'; Expected = 2147483648}
            @{Value = '-0x80000000'; Expected = -2147483648}
            @{Value = '0xFFFFFFFF7FFFFFFF'; Expected = -2147483649}
            @{Value = '0xFFFFFFFF_7FFFFFFF'; Expected = -2147483649}
            @{Value = '0x8000000000000000'; Expected = -9223372036854775808}
            @{Value = '0x7FFFFFFF'; Expected = 2147483647}
            @{Value = '0xF00000000'; Expected = 64424509440}
            @{Value = '0x7FFFFFFFFFFFFFFF'; Expected = 9223372036854775807}
            @{Value = '0x7_FFFFFFFFFFFFFFF'; Expected = 9223372036854775807}

            @{Value = '1:0'; Expected = 60}
            @{Value = '+1:0'; Expected = 60}
            @{Value = '-1:0'; Expected = -60}
            @{Value = '1:1'; Expected = 61}
            @{Value = '+1:1'; Expected = 61}
            @{Value = '-1:1'; Expected = -61}
            @{Value = '1:0:59'; Expected = 3659}
            @{Value = '+1:0:59'; Expected = 3659}
            @{Value = '-1:0:59'; Expected = -3659}
            @{Value = '190:20:30'; Expected = 685230}
            @{Value = '1_9_0:20:30'; Expected = 685230}
            @{Value = '+190:20:30'; Expected = 685230}
            @{Value = '-190:20:30'; Expected = -685230}
            @{Value = '80:41:26:53:24:11'; Expected = 62745168251}
            @{Value = '+80:41:26:53:24:11'; Expected = 62745168251}
            @{Value = '-80:41:26:53:24:11'; Expected = -62745168251}
        ) {
            param ($Value, $Expected)

            $actual = ConvertFrom-Yaml -InputObject $Value -Schema Yaml11
            $actual | Should -Be $Expected
            $actual | Should -BeOfType $Expected.GetType()
        }

        It "Fails to parse tagged integer" {
            $res = ConvertFrom-Yaml -InputObject '!!int a' -Schema Yaml11 -ErrorAction SilentlyContinue -ErrorVariable err
            $res | Should -BeNullOrEmpty
            $err.Count | Should -Be 1
            [string]$err[0] | Should -BeLike "Failed to unpack yaml node 'a' with tag 'tag:yaml.org,2002:int': Does not match expected int value pattern*"
        }

        It "Parses float <Value>" -TestCases @(
            @{Value = '0.'; Expected = [Double]'0'}
            @{Value = '-0.0'; Expected = [Double]'-0'}
            @{Value = '.5'; Expected = [Double]'0.5'}
            @{Value = '+12.e+03'; Expected = [Double]'12000'}
            @{Value = '-2.0E+05'; Expected = [Double]'-200000'}
            @{Value = '2.0E+1000'; Expected = [Double]::PositiveInfinity}
            @{Value = '-2.0E+1000'; Expected = [Double]::NegativeInfinity}
            @{Value = '6.8523015e+5'; Expected = [Double]'685230.15'}
            @{Value = '685.230_15e+03'; Expected = [Double]'685230.15'}
            @{Value = '190:20:30.15'; Expected = [Double]'685230.15'}
            @{Value = '.inf'; Expected = [Double]::PositiveInfinity}
            @{Value = '.InF'; Expected = [Double]::PositiveInfinity}
            @{Value = '.INF'; Expected = [Double]::PositiveInfinity}
            @{Value = '+.inf'; Expected = [Double]::PositiveInfinity}
            @{Value = '+.InF'; Expected = [Double]::PositiveInfinity}
            @{Value = '+.INF'; Expected = [Double]::PositiveInfinity}
            @{Value = '-.inf'; Expected = [Double]::NegativeInfinity}
            @{Value = '-.InF'; Expected = [Double]::NegativeInfinity}
            @{Value = '-.INF'; Expected = [Double]::NegativeInfinity}
            @{Value = '.nan'; Expected = [Double]::NaN}
            @{Value = '.NaN'; Expected = [Double]::NaN}
            @{Value = '.NAN'; Expected = [Double]::NaN}
        ) {
            param ($Value, $Expected)

            $actual = ConvertFrom-Yaml -InputObject $Value -Schema Yaml11
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
            $res = ConvertFrom-Yaml -InputObject '!!float a' -Schema Yaml11 -ErrorAction SilentlyContinue -ErrorVariable err
            $res | Should -BeNullOrEmpty
            $err.Count | Should -Be 1
            [string]$err[0] | Should -Be "Failed to unpack yaml node 'a' with tag 'tag:yaml.org,2002:float': Does not match expected float value pattern"
        }

        It "Parses timestamp <Value>" -TestCases @(
            @{
                Value = '2001-12-15T02:59:43.1Z'
                Expected = [DateTimeOffset]::new(2001, 12, 15, 2, 59, 43, 100, (New-TimeSpan))
            }
            @{
                Value = '2001-12-15t02:59:43.1Z'
                Expected = [DateTimeOffset]::new(2001, 12, 15, 2, 59, 43, 100, (New-TimeSpan))
            }
            @{
                Value = '2001-12-15 02:59:43.1Z'
                Expected = [DateTimeOffset]::new(2001, 12, 15, 2, 59, 43, 100, (New-TimeSpan))
            }
            @{
                Value = "2001-12-15`t02:59:43.1Z"
                Expected = [DateTimeOffset]::new(2001, 12, 15, 2, 59, 43, 100, (New-TimeSpan))
            }
            @{
                Value = "2001-12-15`t02:59:43.1`tZ"
                Expected = [DateTimeOffset]::new(2001, 12, 15, 2, 59, 43, 100, (New-TimeSpan))
            }
            @{
                Value = '2001-12-14t21:59:43.10-05:00'
                Expected = [DateTimeOffset]::new(2001, 12, 14, 21, 59, 43, 100, (New-TimeSpan -Hours -5))
            }
            @{
                Value = '2001-12-14t21:59:43.10+05:00'
                Expected = [DateTimeOffset]::new(2001, 12, 14, 21, 59, 43, 100, (New-TimeSpan -Hours 5))
            }
            @{
                Value = '2001-12-14 21:59:43.10 -5'
                Expected = [DateTimeOffset]::new(2001, 12, 14, 21, 59, 43, 100, (New-TimeSpan -Hours -5))
            }
            @{
                Value = '2001-12-14 21:59:43.10 +5'
                Expected = [DateTimeOffset]::new(2001, 12, 14, 21, 59, 43, 100, (New-TimeSpan -Hours 5))
            }
            @{
                Value = "2001-12-14 21:59:43.10`t+5"
                Expected = [DateTimeOffset]::new(2001, 12, 14, 21, 59, 43, 100, (New-TimeSpan -Hours 5))
            }
            @{
                Value = '2001-12-15 2:59:43.10'
                Expected = [DateTimeOffset]::new(2001, 12, 15, 2, 59, 43, 100, (New-TimeSpan))
            }
            @{
                Value = '2002-12-14'
                Expected = [DateTimeOffset]::new(2002, 12, 14, 0, 0, 0, 0, (New-TimeSpan))
            }
            @{
                Value = '2023-06-21T08:37:20.3557246+10:00'
                Expected = [DateTimeOffset]::new(2023, 6, 21, 8, 37, 20, 355, (New-TimeSpan -Hours 10)).AddTicks(7246)
            }
            @{
                # Dotnet only supports up to 100s of nanoseconds, so the remaining values are ignored
                Value = '2023-06-21T08:37:20.35572465+10:00'
                Expected = [DateTimeOffset]::new(2023, 6, 21, 8, 37, 20, 355, (New-TimeSpan -Hours 10)).AddTicks(7246)
            }
        ) {
            param ($Value, $Expected)

            $actual = ConvertFrom-Yaml -InputObject $Value -Schema Yaml11
            $actual.ToString('o') | Should -Be $Expected.ToString('o')
            $actual | Should -BeOfType ([DateTimeOffset])
        }

        It "Fails to parse tagged timestamp" {
            $res = ConvertFrom-Yaml -InputObject '!!timestamp yes' -Schema Yaml11 -ErrorAction SilentlyContinue -ErrorVariable err
            $res | Should -BeNullOrEmpty
            $err.Count | Should -Be 1
            [string]$err[0] | Should -Be "Failed to unpack yaml node 'yes' with tag 'tag:yaml.org,2002:timestamp': Does not match expected timestamp value"
        }

        It "Parses string <Value>" -TestCases @(
            @{Value = 'abc'; Expected = 'abc'}
            @{Value = '!!str 1'; Expected = '1'}
            @{Value = '"1"'; Expected = '1'}
            @{Value = '""'; Expected = ''}
            @{Value = "''"; Expected = ''}
            @{Value = '"yes"'; Expected = 'yes'}
            @{Value = "$([Char]::ConvertFromUtf32(0x1F4A9))"; Expected = "$([Char]::ConvertFromUtf32(0x1F4A9))"}
            @{Value = '"\U0001F4A9"'; Expected = "$([Char]::ConvertFromUtf32(0x1F4A9))"}
            @{Value = '\U0001F4A9'; Expected = "\U0001F4A9"}
        ) {
            param ($Value, $Expected)
            $actual = ConvertFrom-Yaml -InputObject $Value
            $actual | Should -Be $Expected
            $actual | Should -BeOfType ([string])
        }

        It "Parses YAML with merged values" {
            $actual = ConvertFrom-Yaml @'
dict:
  entry1: &anchor
    key1: value 1
    key2: value 2
  entry2:
    <<: *anchor
    key2: other value
    key3: final value
  entry3:
    key2: other value
    key3: final value
    <<: *anchor
'@ -Schema Yaml11

            $actual.Keys.Count | Should -Be 1

            $actual.dict.Keys.Count | Should -Be 3
            $actual.dict.entry1.Keys.Count | Should -Be 2
            $actual.dict.entry1.key1 | Should -Be 'value 1'
            $actual.dict.entry1[0] | Should -Be 'value 1'
            $actual.dict.entry1.key2 | Should -Be 'value 2'
            $actual.dict.entry1[1] | Should -Be 'value 2'

            $actual.dict.entry2.Keys.Count | Should -Be 3
            $actual.dict.entry2.key1 | Should -Be 'value 1'
            $actual.dict.entry2[0] | Should -Be 'value 1'
            $actual.dict.entry2.key2 | Should -Be 'other value'
            $actual.dict.entry2[1] | Should -Be 'other value'
            $actual.dict.entry2.key3 | Should -Be 'final value'
            $actual.dict.entry2[2] | Should -Be 'final value'

            $actual.dict.entry3.Keys.Count | Should -Be 3
            $actual.dict.entry3.key2 | Should -Be 'other value'
            $actual.dict.entry3[0] | Should -Be 'other value'
            $actual.dict.entry3.key3 | Should -Be 'final value'
            $actual.dict.entry3[1] | Should -Be 'final value'
            $actual.dict.entry3.key1 | Should -Be 'value 1'
            $actual.dict.entry3[2] | Should -Be 'value 1'
        }
    }

    Context "YAML 1.2 Schema" {
        It "Parses bool <Value>" -TestCases @(
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
            @{Value = '0.'; Expected = [Double]'0'}
            @{Value = '!!float 1'; Expected = [Double]'1'}
            @{Value = '-0.0'; Expected = [Double]'-0'}
            @{Value = '.5'; Expected = [Double]'0.5'}
            @{Value = '+12e03'; Expected = [Double]'12000'}
            @{Value = '-2E+05'; Expected = [Double]'-200000'}
            @{Value = '2E+1000'; Expected = [Double]::PositiveInfinity}
            @{Value = '-2E+1000'; Expected = [Double]::NegativeInfinity}
            @{Value = '.inf'; Expected = [Double]::PositiveInfinity}
            @{Value = '-.Inf'; Expected = [Double]::NegativeInfinity}
            @{Value = '+.INF'; Expected = [Double]::PositiveInfinity}
            @{Value = '.NAN'; Expected = [Double]::NaN}
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

        It "Parses YAML with merged key name" {
            # YAML 1.1 is the only spec that includes merge support.
            # All other specs treat '<<' as a literal key name.
            $actual = ConvertFrom-Yaml @'
dict:
  entry1: &anchor
    key1: value 1
    key2: value 2
  entry2:
    <<: *anchor
    key2: other value
    key3: final value
  entry3:
    key2: other value
    key3: final value
    <<: *anchor
'@

            $actual.Keys.Count | Should -Be 1

            $actual.dict.Keys.Count | Should -Be 3
            $actual.dict.entry1.Keys.Count | Should -Be 2
            $actual.dict.entry1.key1 | Should -Be 'value 1'
            $actual.dict.entry1[0] | Should -Be 'value 1'
            $actual.dict.entry1.key2 | Should -Be 'value 2'
            $actual.dict.entry1[1] | Should -Be 'value 2'

            $actual.dict.entry2.Keys.Count | Should -Be 3
            $actual.dict.entry2.'<<'.Keys.Count | Should -Be 2
            $actual.dict.entry2.'<<'.key1 | Should -Be 'value 1'
            $actual.dict.entry2.'<<'.key2 | Should -Be 'value 2'
            $actual.dict.entry2[0] | Should -Be $actual.dict.entry2.'<<'
            $actual.dict.entry2.key2 | Should -Be 'other value'
            $actual.dict.entry2[1] | Should -Be 'other value'
            $actual.dict.entry2.key3 | Should -Be 'final value'
            $actual.dict.entry2[2] | Should -Be 'final value'

            $actual.dict.entry3.Keys.Count | Should -Be 3
            $actual.dict.entry3.key2 | Should -Be 'other value'
            $actual.dict.entry3[0] | Should -Be 'other value'
            $actual.dict.entry3.key3 | Should -Be 'final value'
            $actual.dict.entry3[1] | Should -Be 'final value'
            $actual.dict.entry3.'<<'.Keys.Count | Should -Be 2
            $actual.dict.entry3.'<<'.key1 | Should -Be 'value 1'
            $actual.dict.entry3.'<<'.key2 | Should -Be 'value 2'
            $actual.dict.entry3[2] | Should -Be $actual.dict.entry3.'<<'
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
            @{Value = '1.5'; Expected = [Double]'1.5'}
            @{Value = '-2e+5'; Expected = [Double]'-200000'}
            @{Value = '-2e-5'; Expected = [Double]'-2E-05'}
            @{Value = '-2E-5'; Expected = [Double]'-2E-05'}
            @{Value = '2e+1000'; Expected = [Double]::PositiveInfinity}
            @{Value = '-2e+1000'; Expected = [Double]::NegativeInfinity}
            @{Value = '!!float .inf'; Expected = [Double]::PositiveInfinity}
            @{Value = '!!float -.inf'; Expected = [Double]::NegativeInfinity}
            @{Value = '!!float .nan'; Expected = [Double]::NaN}
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
            $res = ConvertFrom-Yaml -InputObject '!!float a' -Schema Yaml12JSON -ErrorAction SilentlyContinue -ErrorVariable err
            $res | Should -BeNullOrEmpty
            $err.Count | Should -Be 1
            [string]$err[0] | Should -Be "Failed to unpack yaml node 'a' with tag 'tag:yaml.org,2002:float': Does not match expected JSON float value pattern"
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
            @{Value = '"abc"'; Expected = 'abc'}
            @{Value = '!!str 1'; Expected = '1'}
            @{Value = '"1"'; Expected = '1'}
            @{Value = '"0x1"'; Expected = '0x1'}
            @{Value = '""'; Expected = ''}
            @{Value = "''"; Expected = ''}
            @{Value = '"yes"'; Expected = 'yes'}
            @{Value = '!!str true'; Expected = 'true'}
            @{Value = """$([Char]::ConvertFromUtf32(0x1F4A9))"""; Expected = "$([Char]::ConvertFromUtf32(0x1F4A9))"}
            @{Value = '"\U0001F4A9"'; Expected = "$([Char]::ConvertFromUtf32(0x1F4A9))"}
            @{Value = "'\U0001F4A9'"; Expected = "\U0001F4A9"}
        ) {
            param ($Value, $Expected)
            $actual = ConvertFrom-Yaml -InputObject $Value -Schema Yaml12JSON
            $actual | Should -Be $Expected
            $actual | Should -BeOfType ([string])
        }

        It "Fails to parse unknown plain scalar value" {
            $res = ConvertFrom-Yaml -InputObject 'abc' -Schema Yaml12JSON -ErrorAction SilentlyContinue -ErrorVariable err
            $res | Should -BeNullOrEmpty
            $err.Count | Should -Be 1
            [string]$err[0] | Should -Be "Failed to unpack yaml node 'abc' with tag '?': Does not match JSON bool, int, float, or null literals"
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
            $schema = New-YamlSchema -ParseScalar {
                param ($Value, $Schema)

                if ($Value.Tag -eq 'tag:yaml.org,2002:my_tag') {
                    2
                }
                else {
                    $Schema.ParseScalar($Value)
                }
            }

            $actual = ConvertFrom-Yaml -InputObject "foo: 1${n}test: !!my_tag 2" -Schema $schema
            $actual.Keys.Count | Should -Be 2
            $actual['foo'] | Should -Be 1
            $actual['foo'] | Should -BeOfType ([int])
            $actual['test'] | Should -Be 2
            $actual['test'] | Should -BeOfType ([int])
        }

        It "Parses with custom tag handler with base schema" {
            $schema = New-YamlSchema -ParseScalar {
                param ($Value, $Schema)

                if ($Value.Tag -eq 'tag:yaml.org,2002:int') {
                    1
                }
                else {
                    $Schema.ParseScalar($Value)
                }
            } -BaseSchema Yaml12JSON

            $actual = ConvertFrom-Yaml -InputObject """foo"": !!int 2$n""test"": 'True'" -Schema $schema
            $actual.Keys.Count | Should -Be 2
            $actual.foo | Should -Be 1
            $actual.test | Should -Be True
            $actual.test | Should -BeOfType ([string])
        }

        It "Parses with custom tag handler" {
            $schema = New-YamlSchema -ParseScalar {
                param ($Value, $Schema)

                '{0}|{1}|{2}' -f $Value.Tag, $Value.Style, $Value.Value
            }

            $actual = ConvertFrom-Yaml -InputObject "foo: 1${n}test: !!my_tag 2${n}other: 'quoted'" -Schema $schema
            $actual.Keys.Count | Should -Be 3
            $actual['?|Plain|foo'] | Should -Be '?|Plain|1'
            $actual['?|Plain|test'] | Should -Be 'tag:yaml.org,2002:my_tag|Plain|2'
            $actual['?|Plain|other'] | Should -Be '?|SingleQuoted|quoted'
        }

        It "Parses with custom map" {
            $schema = New-YamlSchema -ParseMap {
                param ($Value, $Schema)

                @($Value.Values.GetEnumerator())
            }

            $actual = ConvertFrom-Yaml -InputObject "foo: 1${n}bar: hello" -Schema $schema
            $actual.Length | Should -Be 2
            $actual[0].Key | Should -Be foo
            $actual[0].Value | Should -Be 1
            $actual[1].Key | Should -Be bar
            $actual[1].Value | Should -Be hello
        }

        It "Parses with custom sequence" {
            $schema = New-YamlSchema -ParseSequence {
                param ($Value, $Schema)

                $res = @{}
                for ($i = 0; $i -lt $Value.Values.Length; $i++) {
                    $res[$i] = $Value.Values[$i]
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
            $actual = ConvertFrom-Yaml -InputObject '!!str True' -Schema $schema
            $actual | Should -Be 'True'
            $actual | Should -BeOfType ([string])
        }
    }
}
