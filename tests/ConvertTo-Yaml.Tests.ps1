. ([IO.Path]::Combine($PSScriptRoot, 'common.ps1'))

$global:n = [System.Environment]::NewLine

Describe "ConvertTo-Yaml" {
    Context "General emitting" {
        It "Emits array" {
            $value = 1, 2, 3
            $actual = ConvertTo-Yaml -InputObject $value
            $actual | Should -Be "- 1$n- 2$n- 3"
        }

        It "Emits array in dict" {
            $actual = ConvertTo-Yaml -InputObject @{ foo = 1, 2, 3 }
            $actual | Should -Be "foo:$n- 1$n- 2$n- 3"
        }

        It "Emits array in dict with indent" {
            $actual = ConvertTo-Yaml -InputObject @{ foo = 1, 2, 3 } -IndentSequence
            $actual | Should -Be "foo:$n  - 1$n  - 2$n  - 3"
        }

        It "Emits typed array" {
            [string[]]$value = 1, 2, 3
            $value = 1, 2, 3
            $actual = ConvertTo-Yaml -InputObject $value
            $actual | Should -Be "- ""1""$n- ""2""$n- ""3"""
        }

        It "Emits ArrayList" {
            $value = [System.Collections.ArrayList]@(1, 2, 3)
            $actual = ConvertTo-Yaml -InputObject $value
            $actual | Should -Be "- 1$n- 2$n- 3"
        }

        It "Emits List" {
            $value = [System.Collections.Generic.List[Object]]@(1, 2, 3)
            $actual = ConvertTo-Yaml -InputObject $value
            $actual | Should -Be "- 1$n- 2$n- 3"
        }

        It "Emits typed List" {
            $value = [System.Collections.Generic.List[string]]@(1, 2, 3)
            $actual = ConvertTo-Yaml -InputObject $value
            $actual | Should -Be "- ""1""$n- ""2""$n- ""3"""
        }

        It "Emits hashtable" {
            $value = @{ Foo = 'bar' }
            $actual = ConvertTo-Yaml -InputObject $value
            $actual | Should -Be 'foo: bar'
        }

        It "Emits Dictionary" {
            $value = [System.Collections.Generic.Dictionary[[object], [object]]]::new()
            $value['Foo'] = 1
            $actual = ConvertTo-Yaml -InputObject $value
            $actual | Should -Be 'Foo: 1'
        }

        It "Emits type Dictionary" {
            $value = [System.Collections.Generic.Dictionary[[int], [bool]]]::new()
            $value[1] = $true
            $actual = ConvertTo-Yaml -InputObject $value
            $actual | Should -Be '1: true'
        }

        It "Emits OrderedDictionary" {
            $value = [Ordered]@{ Foo = 'bar' }
            $actual = ConvertTo-Yaml -InputObject $value
            $actual | Should -Be 'foo: bar'
        }

        It "Emits PSCustomObject" {
            $value = [PSCustomObject]@{
                1 = 'foo'
            }
            $actual = ConvertTo-Yaml -InputObject $value
            $actual | Should -Be '"1": foo'
        }

        It "Emits PSObject" {
            $value = New-Object -TypeName PSObject -Property @{
                1 = $false
            }
            $actual = ConvertTo-Yaml -InputObject $value
            $actual | Should -Be '"1": false'
        }

        It "Emits Guid" {
            $value = [Guid]::NewGuid()
            $actual = ConvertTo-Yaml -InputObject $value
            $actual | Should -Be "$($value.Guid)"
        }

        It "Emits null key" {
            $value = @{ [Yayaml.NullKey]::Value = 'foo' }
            $actual = ConvertTo-Yaml -InputObject $value
            $actual | Should -Be 'null: foo'
        }

        It "Emits IntPtr value <Value>" -TestCases @(
            @{ Value = [IntPtr]::Zero; Expected = 0 }
            @{ Value = [UIntPtr]::Zero; Expected = 0 }
            @{ Value = [IntPtr]1; Expected = 1 }
            @{ Value = [UIntPtr][UInt32]1; Expected = 1 }
            @{ Value = [IntPtr]2147483647; Expected = 2147483647 }
            @{ Value = [UIntPtr][UInt32]4294967295; Expected = 4294967295 }
        ) {
            param ($Value, $Expected)
            $actual = ConvertTo-Yaml $Value
            $actual | Should -Be $Expected
        }

        It "Uses pipeline input single" {
            $actual = 1 | ConvertTo-Yaml
            $actual | Should -Be '1'
        }

        It "Uses pipeline input single -AsArray" {
            $actual = 1 | ConvertTo-Yaml -AsArray
            $actual | Should -Be '- 1'
        }

        It "Uses pipeline input multiple" {
            $actual = 1, 2, 'a', '2', $true | ConvertTo-Yaml
            $actual | Should -Be "- 1$n- 2$n- a$n- ""2""$n- true"
        }

        It "Emits warning for depth for dict" {
            $actual = ConvertTo-Yaml -InputObject @{ 1 = @{ 2 = @{ 3 = @{ 4 = 'value' } } } } -WarningVariable warn -WarningAction SilentlyContinue
            $actual | Should -Be "1:$n  2:$n    3: System.Collections.Hashtable"
            $warn.Count | Should -Be 1
            [string]$warn[0] | Should -Be "Resulting YAML is truncated as serialization has exceeded the set depth of 2"
        }

        It "Emits warning for depth for list" {
            $actual = ConvertTo-Yaml -InputObject @(1, @(2, @(3, @(4, 5)))) -WarningVariable warn -WarningAction SilentlyContinue
            $actual | Should -Be "- 1$n- - 2$n  - - 3$n    - 4 5"
            $warn.Count | Should -Be 1
            [string]$warn[0] | Should -Be "Resulting YAML is truncated as serialization has exceeded the set depth of 2"
        }

        It "Extends the depth for dict" {
            $actual = ConvertTo-Yaml -InputObject @{ 1 = @{ 2 = @{ 3 = @{ 4 = 1 } } } } -WarningVariable warn -Depth 3
            $warn | Should -BeNullOrEmpty
            $actual | Should -Be "1:$n  2:$n    3:$n      4: 1"
        }

        It "Extends the depth for list" {
            $actual = ConvertTo-Yaml -InputObject @(1, @(2, @(3, @(4, 5)))) -WarningVariable warn -Depth 3
            $warn | Should -BeNullOrEmpty
            $actual | Should -Be "- 1$n- - 2$n  - - 3$n    - - 4$n      - 5"
        }

        It "Emits dict with custom style <Style>" -TestCases @(
            @{ Style = "Block"; Expected = "foo: bar" }
            @{ Style = "Flow"; Expected = "{foo: bar}" }
        ) {
            param ($Style, $Expected)

            $value = @{ foo = 'bar' } | Add-YamlFormat -CollectionStyle $Style -PassThru
            $actual = ConvertTo-Yaml -InputObject $value
            $actual | Should -Be $Expected
        }

        It "Emits list with custom style <Style>" -TestCases @(
            @{ Style = "Block"; Expected = "- 1$n- 2" }
            @{ Style = "Flow"; Expected = "[1, 2]" }
        ) {
            param ($Style, $Expected)

            $value = Add-YamlFormat -InputObject @(1, 2) -CollectionStyle $Style -PassThru
            $actual = ConvertTo-Yaml -InputObject $value
            $actual | Should -Be $Expected
        }

        It "Emits string with custom style <Style>" -TestCases @(
            @{ Style = "Any"; Expected = "abc" }
            @{ Style = "Plain"; Expected = "abc" }
            @{ Style = "SingleQuoted"; Expected = "'abc'" }
            @{ Style = "DoubleQuoted"; Expected = '"abc"' }
            @{ Style = "Literal"; Expected = "|-$n  abc" }
            @{ Style = "Folded"; Expected = ">-$n  abc" }
        ) {
            param ($Style, $Expected)

            $value = 'abc' | Add-YamlFormat -ScalarStyle $Style -PassThru
            $actual = ConvertTo-Yaml -InputObject $value
            $actual | Should -Be $Expected
        }

        It "Emits dictionary like value with custom formatting" {
            $obj = [PSCustomObject]@{ Foo = 1 }
            $obj | Add-YamlFormat -CollectionStyle Flow
            $actual = $obj | ConvertTo-Yaml
            $actual | Should -Be '{Foo: 1}'
        }

        It "Emits Memory" {
            $mem = [System.Memory[byte]]::new([byte[]]@(1, 2))

            $value = @{ mem = $mem }
            $actual = ConvertTo-Yaml -InputObject $value
            $actual | Should -Be "mem:$n- 1$n- 2"
        }

        It "Emits ReadOnlyMemory" {
            $mem = [System.ReadOnlyMemory[byte]]::new([byte[]]@(1, 2))

            $value = @{ mem = $mem }
            $actual = ConvertTo-Yaml -InputObject $value
            $actual | Should -Be "mem:$n- 1$n- 2"
        }

        It "Emits Span and ReadOnlySpan properties" -Skip:(-not $IsCoreCLR) {
            Add-Type -TypeDefinition @'
using System;

namespace Yayaml.Tests;

public class SpanTest
{
    private byte[] _data = new byte[] { 1, 2 };

    public string Foo;
    public Span<byte> SpanProp
    {
        get => _data.AsSpan();
    }

    public ReadOnlySpan<byte> ReadOnlySpanProp
    {
        get => _data.AsSpan();
    }

    public SpanTest()
    {
        Foo = "value";
    }
}
'@

            $obj = [Yayaml.Tests.SpanTest]::New()
            $actual = $obj | ConvertTo-Yaml
            $actual | Should -Be "SpanProp:$n- 1$n- 2${n}ReadOnlySpanProp:$n- 1$n- 2${n}Foo: value"

            # Ensure we don't cause a type conflict when generating the delegate method
            $actual2 = $obj | ConvertTo-Yaml
            $actual2 | Should -Be $actual
        }
    }

    Context "Blank Schema" {
        It "Emits null value" {
            $actual = ConvertTo-Yaml -InputObject $null -Schema Blank
            $actual | Should -Be 'null'
        }

        It "Emits <Value.GetType().Name> value <Value>" -TestCases @(
            # bool
            @{ Value = $true; Expected = 'True' }
            @{ Value = $false; Expected = 'False' }

            # int
            @{ Value = 0; Expected = '0' }
            @{ Value = 1; Expected = '1' }
            @{ Value = -1; Expected = '-1' }
            @{ Value = [System.IO.FileShare]::Read; Expected = 'Read' }
            @{ Value = [byte]1; Expected = '1' }
            @{ Value = [sbyte]1; Expected = '1' }
            @{ Value = [int16]1; Expected = '1' }
            @{ Value = [uint16]1; Expected = '1' }
            @{ Value = [int32]1; Expected = '1' }
            @{ Value = [uint32]1; Expected = '1' }
            @{ Value = [int64]1; Expected = '1' }
            @{ Value = [uint64]1; Expected = '1' }
            @{ Value = [System.Numerics.BigInteger]::new(1); Expected = '1' }

            # str
            @{ Value = 'abc'; Expected = 'abc' }
            @{ Value = '1'; Expected = '1' }
            @{ Value = '0x1'; Expected = '0x1' }
            @{ Value = '""'; Expected = '''""''' }
            @{ Value = "''"; Expected = '"''''"' }
            @{ Value = 'yes'; Expected = 'yes' }
            @{ Value = 'true'; Expected = 'true' }
            @{ Value = "$([Char]::ConvertFromUtf32(0x1F4A9))"; Expected = '"\U0001F4A9"' }
            @{ Value = '"\U0001F4A9"'; Expected = '''"\U0001F4A9"''' }
            @{ Value = '\U0001F4A9'; Expected = "'\U0001F4A9'" }
        ) {
            param ($Value, $Expected)
            $actual = ConvertTo-Yaml -InputObject $Value -Schema Blank
            $actual | Should -Be $Expected
        }

        It "Emits dict" {
            $actual = ConvertTo-Yaml -InputObject @{ foo = 'bar' } -Schema Blank
            $actual | Should -Be "foo: bar"
        }

        It "Emits list" {
            $actual = ConvertTo-Yaml -InputObject @(1, '2') -Schema Blank
            $actual | Should -Be "- 1$n- 2"
        }
    }

    Context "YAML 1.1 Schema" {
        It "Emits null value" {
            $actual = ConvertTo-Yaml -InputObject $null -Schema Yaml11
            $actual | Should -Be null
        }
        It "Emits <Value.GetType().Name> value <Value>" -TestCases @(
            # bool
            @{ Value = $true; Expected = 'true'; Roundtrip = $true }
            @{ Value = $false; Expected = 'false'; Roundtrip = $false }

            # int
            @{ Value = 0; Expected = '0'; Roundtrip = 0 }
            @{ Value = 1; Expected = '1'; Roundtrip = 1 }
            @{ Value = -1; Expected = '-1'; Roundtrip = -1 }
            @{ Value = [System.IO.FileShare]::Read; Expected = '1'; Roundtrip = 1 }
            @{ Value = [byte]1; Expected = 1; Roundtrip = 1 }
            @{ Value = [sbyte]1; Expected = 1; Roundtrip = 1 }
            @{ Value = [int16]1; Expected = 1; Roundtrip = 1 }
            @{ Value = [uint16]1; Expected = 1; Roundtrip = 1 }
            @{ Value = [int32]1; Expected = 1; Roundtrip = 1 }
            @{ Value = [uint32]1; Expected = 1; Roundtrip = 1 }
            @{ Value = [int64]1; Expected = 1; Roundtrip = 1 }
            @{ Value = [uint64]1; Expected = 1; Roundtrip = 1 }
            @{ Value = [System.Numerics.BigInteger]::new(1); Expected = 1; Roundtrip = 1 }

            # float
            @{ Value = [float]'0'; Expected = '0.0e+0'; Roundtrip = [double]'0' }
            @{ Value = [float]'1'; Expected = '1.0e+0'; Roundtrip = [double]'1' }
            @{ Value = [float]'1.0'; Expected = '1.0e+0'; Roundtrip = [double]'1' }
            @{ Value = [float]'1.1E+20'; Expected = '1.1e+20'; Roundtrip = [double]'1.1e+20' }
            @{ Value = [float]'-1.1E+20'; Expected = '-1.1e+20'; Roundtrip = [double]'-1.1e+20' }
            @{ Value = [float]'1.1E-20'; Expected = '1.1e-20'; Roundtrip = [double]'1.1e-20' }
            @{ Value = [float]'-1.1E-20'; Expected = '-1.1e-20'; Roundtrip = [double]'-1.1e-20' }
            @{ Value = [float]::PositiveInfinity; Expected = '.inf'; Roundtrip = [double]::PositiveInfinity }
            @{ Value = [float]::NegativeInfinity; Expected = '-.inf'; Roundtrip = [double]::NegativeInfinity }
            @{ Value = [float]::NaN; Expected = '.nan'; Roundtrip = [double]::NaN }
            @{ Value = [double]'0'; Expected = '0.0e+0'; Roundtrip = [double]'0' }
            @{ Value = [double]'1.1E+20'; Expected = '1.1e+20'; Roundtrip = [double]'1.1e20' }
            @{ Value = [double]'-1.1E+20'; Expected = '-1.1e+20'; Roundtrip = [double]'-1.1e20' }
            @{ Value = [double]'1.1E-20'; Expected = '1.1e-20'; Roundtrip = [double]'1.1e-20' }
            @{ Value = [double]'-1.1E-20'; Expected = '-1.1e-20'; Roundtrip = [double]'-1.1e-20' }
            @{ Value = [double]::PositiveInfinity; Expected = '.inf'; Roundtrip = [double]::PositiveInfinity }
            @{ Value = [double]::NegativeInfinity; Expected = '-.inf'; Roundtrip = [double]::NegativeInfinity }
            @{ Value = [double]::NaN; Expected = '.nan'; Roundtrip = [double]::NaN }
            @{ Value = [decimal]'0'; Expected = '0.0e+0'; Roundtrip = [double]'0' }
            @{ Value = [decimal][double]'1.1E+20'; Expected = '1.1e+20'; Roundtrip = [double]'1.1e20' }
            @{ Value = [decimal][double]'-1.1E+20'; Expected = '-1.1e+20'; Roundtrip = [double]'-1.1e20' }
            @{ Value = [decimal][double]'1.1E-20'; Expected = '1.1e-20'; Roundtrip = [double]'1.1e-20' }
            @{ Value = [decimal][double]'-1.1E-20'; Expected = '-1.1e-20'; Roundtrip = [double]'-1.1e-20' }

            # str
            @{ Value = 'abc'; Expected = 'abc'; Roundtrip = 'abc' }
            @{ Value = '1'; Expected = '"1"'; Roundtrip = '1' }
            @{ Value = '0x1'; Expected = '"0x1"'; Roundtrip = '0x1' }
            @{ Value = '""'; Expected = '''""'''; Roundtrip = '""' }
            @{ Value = "''"; Expected = '"''''"'; Roundtrip = "''" }
            @{ Value = 'yes'; Expected = '"yes"'; Roundtrip = 'yes' }
            @{ Value = 'true'; Expected = '"true"'; Roundtrip = 'true' }
            @{ Value = "$([Char]::ConvertFromUtf32(0x1F4A9))"; Expected = '"\U0001F4A9"'; Roundtrip = "$([Char]::ConvertFromUtf32(0x1F4A9))" }
            @{ Value = '"\U0001F4A9"'; Expected = '''"\U0001F4A9"'''; Roundtrip = '"\U0001F4A9"' }
            @{ Value = '\U0001F4A9'; Expected = "'\U0001F4A9'"; Roundtrip = '\U0001F4A9' }

            # timestamp
            @{
                Value = [DateTime]::new(2001, 12, 14, 21, 59, 43, 100, [System.DateTimeKind]::Local)
                Expected = "2001-12-14T21:59:43.1$([DateTime]::Now.ToString('zzz'))"
                Roundtrip = [DateTimeOffset]::new(2001, 12, 14, 21, 59, 43, 100, [DateTimeOffset]::Now.Offset)
            }
            @{
                Value = [DateTime]::new(2001, 12, 14, 21, 59, 43, 100, [System.DateTimeKind]::Utc)
                Expected = '2001-12-14T21:59:43.1Z'
                Roundtrip = [DateTimeOffset]::new(2001, 12, 14, 21, 59, 43, 100, (New-TimeSpan -Hours 0))
            }
            @{
                Value = [DateTime]::new(2001, 12, 14, 21, 59, 43, 100, [System.DateTimeKind]::Unspecified)
                Expected = '2001-12-14T21:59:43.1'
                Roundtrip = [DateTimeOffset]::new(2001, 12, 14, 21, 59, 43, 100, (New-TimeSpan -Hours 0))
            }
            @{
                Value = [DateTimeOffset]::new(2001, 12, 14, 21, 59, 43, 100, (New-TimeSpan -Hours 0))
                Expected = '2001-12-14T21:59:43.1+00:00'
                Roundtrip = [DateTimeOffset]::new(2001, 12, 14, 21, 59, 43, 100, (New-TimeSpan -Hours 0))
            }
            @{
                Value = [DateTimeOffset]::new(2001, 12, 14, 21, 59, 43, 100, (New-TimeSpan -Hours 5))
                Expected = '2001-12-14T21:59:43.1+05:00'
                Roundtrip = [DateTimeOffset]::new(2001, 12, 14, 21, 59, 43, 100, (New-TimeSpan -Hours 5))
            }
            @{
                Value = [DateTimeOffset]::new(2001, 12, 14, 21, 59, 43, 100, (New-TimeSpan -Hours -5))
                Expected = '2001-12-14T21:59:43.1-05:00'
                Roundtrip = [DateTimeOffset]::new(2001, 12, 14, 21, 59, 43, 100, (New-TimeSpan -Hours -5))
            }
            @{
                Value = [DateTime]::new(2001, 12, 14, 21, 59, 43, 0, [System.DateTimeKind]::Utc)
                Expected = '2001-12-14T21:59:43Z'
                Roundtrip = [DateTimeOffset]::new(2001, 12, 14, 21, 59, 43, 0, (New-TimeSpan -Hours 0))
            }
            @{
                Value = [DateTime]::new(2001, 12, 14, 21, 59, 43, 100, [System.DateTimeKind]::Utc).AddTicks(12)
                Expected = '2001-12-14T21:59:43.1000012Z'
                Roundtrip = [DateTimeOffset]::new(2001, 12, 14, 21, 59, 43, 100, (New-TimeSpan -Hours 0)).AddTicks(12)
            }

            # binary
            @{
                Value = [byte[]]@(0, 1, 2, 16)
                Expected = '!!binary AAECEA=='
                Roundtrip = [byte[]]@(0, 1, 2, 16)
            }
            @{
                Value = [System.Collections.Generic.List[byte]]@(0, 1, 2, 16)
                Expected = '!!binary AAECEA=='
                Roundtrip = [byte[]]@(0, 1, 2, 16)
            }

            # misc
            @{
                Value = [Guid]::new("1ccddbdb-4815-4457-8054-b3e381268588")
                Expected = '1ccddbdb-4815-4457-8054-b3e381268588'
                Roundtrip = '1ccddbdb-4815-4457-8054-b3e381268588'
            }
        ) {
            param ($Value, $Expected, $Roundtrip)
            $actual = ConvertTo-Yaml -InputObject $Value -Schema Yaml11
            $actual | Should -Be $Expected

            $roundtripActual = ConvertFrom-Yaml $actual -Schema Yaml11
            if ($Roundtrip -is [byte[]]) {
                $expectedStr = [System.Convert]::ToBase64String($Roundtrip)
                $actualStr = [System.Convert]::ToBase64String($roundtripActual)
                $actualStr | Should -Be $expectedStr
                return
            }

            $roundtripActual | Should -BeOfType $Roundtrip.GetType()
            if ($roundTripActual -is [double] -and $roundtripActual.ToString() -eq 'NaN') {
                $roundtripActual.ToString() | Should -Be $Roundtrip.ToString()
            }
            else {
                $roundtripActual | Should -Be $Roundtrip
            }
        }

        It "Emits dict" {
            $actual = ConvertTo-Yaml -InputObject @{ foo = 'bar' } -Schema Yaml11
            $actual | Should -Be 'foo: bar'
        }

        It "Emits list" {
            $actual = ConvertTo-Yaml -InputObject @(1, '2') -Schema Yaml11
            $actual | Should -Be "- 1$n- ""2"""
        }

        It "Emits bool with custom style <Style>" -TestCases @(
            @{ Style = "Any"; Expected = 'true' }
            @{ Style = "Plain"; Expected = 'true' }
            @{ Style = "SingleQuoted"; Expected = "!!bool 'true'" }
            @{ Style = "DoubleQuoted"; Expected = '!!bool "true"' }
            @{ Style = "Literal"; Expected = "!!bool |-$n  true" }
            @{ Style = "Folded"; Expected = "!!bool >-$n  true" }
        ) {
            param ($Style, $Expected)

            $value = $true | Add-YamlFormat -ScalarStyle $Style -PassThru
            $actual = ConvertTo-Yaml -InputObject $value -Schema Yaml11
            $value.PSObject.Properties.Remove("_YayamlFormat")
            $actual | Should -Be $Expected

            $roundtrip = ConvertFrom-Yaml -InputObject $actual -Schema Yaml11
            $roundtrip | Should -BeTrue
            $roundtrip | Should -BeOfType ([bool])
        }

        It "Emits enum with custom style <Style>" -TestCases @(
            @{ Style = "Any"; Expected = '1' }
            @{ Style = "Plain"; Expected = '1' }
            @{ Style = "SingleQuoted"; Expected = "!!int '1'" }
            @{ Style = "DoubleQuoted"; Expected = '!!int "1"' }
            @{ Style = "Literal"; Expected = "!!int |-$n  1" }
            @{ Style = "Folded"; Expected = "!!int >-$n  1" }
        ) {
            param ($Style, $Expected)

            $value = [System.IO.FileShare]::Read | Add-YamlFormat -ScalarStyle $Style -PassThru
            $actual = ConvertTo-Yaml -InputObject $value -Schema Yaml11
            $value.PSObject.Properties.Remove("_YayamlFormat")
            $actual | Should -Be $Expected

            $roundtrip = ConvertFrom-Yaml -InputObject $actual -Schema Yaml11
            $roundtrip | Should -Be 1
            $roundtrip | Should -BeOfType ([int])
        }

        It "Emits int with custom style <Style>" -TestCases @(
            @{ Style = "Any"; Expected = '1' }
            @{ Style = "Plain"; Expected = '1' }
            @{ Style = "SingleQuoted"; Expected = "!!int '1'" }
            @{ Style = "DoubleQuoted"; Expected = '!!int "1"' }
            @{ Style = "Literal"; Expected = "!!int |-$n  1" }
            @{ Style = "Folded"; Expected = "!!int >-$n  1" }
        ) {
            param ($Style, $Expected)

            $value = 1 | Add-YamlFormat -ScalarStyle $Style -PassThru
            $actual = ConvertTo-Yaml -InputObject $value -Schema Yaml11
            $value.PSObject.Properties.Remove("_YayamlFormat")
            $actual | Should -Be $Expected

            $roundtrip = ConvertFrom-Yaml -InputObject $actual -Schema Yaml11
            $roundtrip | Should -Be 1
            $roundtrip | Should -BeOfType ([int])
        }

        It "Emits float with custom style <Style>" -TestCases @(
            @{ Style = "Any"; Expected = '1.1e+0' }
            @{ Style = "Plain"; Expected = '1.1e+0' }
            @{ Style = "SingleQuoted"; Expected = "!!float '1.1e+0'" }
            @{ Style = "DoubleQuoted"; Expected = '!!float "1.1e+0"' }
            @{ Style = "Literal"; Expected = "!!float |-$n  1.1e+0" }
            @{ Style = "Folded"; Expected = "!!float >-$n  1.1e+0" }
        ) {
            param ($Style, $Expected)

            $value = 1.1 | Add-YamlFormat -ScalarStyle $Style -PassThru
            $actual = ConvertTo-Yaml -InputObject $value -Schema Yaml11
            $value.PSObject.Properties.Remove("_YayamlFormat")
            $actual | Should -Be $Expected

            $roundtrip = ConvertFrom-Yaml -InputObject $actual -Schema Yaml11
            $roundtrip | Should -Be 1.1
            $roundtrip | Should -BeOfType ([double])
        }

        It "Emits string with custom style <Style>" -TestCases @(
            @{ Style = "Any"; Expected = 'abc' }
            @{ Style = "Plain"; Expected = "abc" }
            @{ Style = "SingleQuoted"; Expected = "'abc'" }
            @{ Style = "DoubleQuoted"; Expected = '"abc"' }
            @{ Style = "Literal"; Expected = "|-$n  abc" }
            @{ Style = "Folded"; Expected = ">-$n  abc" }
        ) {
            param ($Style, $Expected)

            $value = 'abc' | Add-YamlFormat -ScalarStyle $Style -PassThru
            $actual = ConvertTo-Yaml -InputObject $value -Schema Yaml11
            $actual | Should -Be $Expected

            $roundtrip = ConvertFrom-Yaml -InputObject $actual -Schema Yaml11
            $roundtrip | Should -Be abc
            $roundtrip | Should -BeOfType ([string])
        }

        It "Emits PSCustomObject" {
            $value = [PSCustomObject]@{
                Foo = 'bar'
                1 = 'test'
            }

            $actual = ConvertTo-Yaml -InputObject $value -Schema Yaml11
            $actual | Should -Be "Foo: bar$n""1"": test"
        }
    }

    Context "YAML 1.2 Schema" {
        It "Emits null value" {
            $actual = ConvertTo-Yaml -InputObject $null
            $actual | Should -Be null
        }
        It "Emits <Value.GetType().Name> value <Value>" -TestCases @(
            # bool
            @{ Value = $true; Expected = 'true'; Roundtrip = $true }
            @{ Value = $false; Expected = 'false'; Roundtrip = $false }

            # int
            @{ Value = 0; Expected = '0'; Roundtrip = 0 }
            @{ Value = 1; Expected = '1'; Roundtrip = 1 }
            @{ Value = -1; Expected = '-1'; Roundtrip = -1 }
            @{ Value = [System.IO.FileShare]::Read; Expected = '1'; Roundtrip = 1 }
            @{ Value = [byte]1; Expected = 1; Roundtrip = 1 }
            @{ Value = [sbyte]1; Expected = 1; Roundtrip = 1 }
            @{ Value = [int16]1; Expected = 1; Roundtrip = 1 }
            @{ Value = [uint16]1; Expected = 1; Roundtrip = 1 }
            @{ Value = [int32]1; Expected = 1; Roundtrip = 1 }
            @{ Value = [uint32]1; Expected = 1; Roundtrip = 1 }
            @{ Value = [int64]1; Expected = 1; Roundtrip = 1 }
            @{ Value = [uint64]1; Expected = 1; Roundtrip = 1 }
            @{ Value = [System.Numerics.BigInteger]::new(1); Expected = 1; Roundtrip = 1 }

            # float
            @{ Value = [float]'0'; Expected = '0.0e+0'; Roundtrip = [double]'0' }
            @{ Value = [float]'1'; Expected = '1.0e+0'; Roundtrip = [double]'1' }
            @{ Value = [float]'1.0'; Expected = '1.0e+0'; Roundtrip = [double]'1' }
            @{ Value = [float]'1.1E+20'; Expected = '1.1e+20'; Roundtrip = [double]'1.1e+20' }
            @{ Value = [float]'-1.1E+20'; Expected = '-1.1e+20'; Roundtrip = [double]'-1.1e+20' }
            @{ Value = [float]'1.1E-20'; Expected = '1.1e-20'; Roundtrip = [double]'1.1e-20' }
            @{ Value = [float]'-1.1E-20'; Expected = '-1.1e-20'; Roundtrip = [double]'-1.1e-20' }
            @{ Value = [float]::PositiveInfinity; Expected = '.inf'; Roundtrip = [double]::PositiveInfinity }
            @{ Value = [float]::NegativeInfinity; Expected = '-.inf'; Roundtrip = [double]::NegativeInfinity }
            @{ Value = [float]::NaN; Expected = '.nan'; Roundtrip = [double]::NaN }
            @{ Value = [double]'0'; Expected = '0.0e+0'; Roundtrip = [double]'0' }
            @{ Value = [double]'1.1E+20'; Expected = '1.1e+20'; Roundtrip = [double]'1.1e20' }
            @{ Value = [double]'-1.1E+20'; Expected = '-1.1e+20'; Roundtrip = [double]'-1.1e20' }
            @{ Value = [double]'1.1E-20'; Expected = '1.1e-20'; Roundtrip = [double]'1.1e-20' }
            @{ Value = [double]'-1.1E-20'; Expected = '-1.1e-20'; Roundtrip = [double]'-1.1e-20' }
            @{ Value = [double]::PositiveInfinity; Expected = '.inf'; Roundtrip = [double]::PositiveInfinity }
            @{ Value = [double]::NegativeInfinity; Expected = '-.inf'; Roundtrip = [double]::NegativeInfinity }
            @{ Value = [double]::NaN; Expected = '.nan'; Roundtrip = [double]::NaN }
            @{ Value = [decimal]'0'; Expected = '0.0e+0'; Roundtrip = [double]'0' }
            @{ Value = [decimal][double]'1.1E+20'; Expected = '1.1e+20'; Roundtrip = [double]'1.1e20' }
            @{ Value = [decimal][double]'-1.1E+20'; Expected = '-1.1e+20'; Roundtrip = [double]'-1.1e20' }
            @{ Value = [decimal][double]'1.1E-20'; Expected = '1.1e-20'; Roundtrip = [double]'1.1e-20' }
            @{ Value = [decimal][double]'-1.1E-20'; Expected = '-1.1e-20'; Roundtrip = [double]'-1.1e-20' }

            # str
            @{ Value = 'abc'; Expected = 'abc'; Roundtrip = 'abc' }
            @{ Value = '1'; Expected = '"1"'; Roundtrip = '1' }
            @{ Value = '0x1'; Expected = '"0x1"'; Roundtrip = '0x1' }
            @{ Value = '""'; Expected = '''""'''; Roundtrip = '""' }
            @{ Value = "''"; Expected = '"''''"'; Roundtrip = "''" }
            @{ Value = 'yes'; Expected = 'yes'; Roundtrip = 'yes' }
            @{ Value = 'true'; Expected = '"true"'; Roundtrip = 'true' }
            @{ Value = "$([Char]::ConvertFromUtf32(0x1F4A9))"; Expected = '"\U0001F4A9"'; Roundtrip = "$([Char]::ConvertFromUtf32(0x1F4A9))" }
            @{ Value = '"\U0001F4A9"'; Expected = '''"\U0001F4A9"'''; Roundtrip = '"\U0001F4A9"' }
            @{ Value = '\U0001F4A9'; Expected = "'\U0001F4A9'"; Roundtrip = '\U0001F4A9' }

            # misc
            @{
                Value = [DateTime]::new(2001, 12, 14, 21, 59, 43, 100, [System.DateTimeKind]::Local)
                Expected = "2001-12-14T21:59:43.1000000$([DateTime]::Now.ToString('zzz'))"
                Roundtrip = "2001-12-14T21:59:43.1000000$([DateTime]::Now.ToString('zzz'))"
            }
            @{
                Value = [DateTime]::new(2001, 12, 14, 21, 59, 43, 100, [System.DateTimeKind]::Utc)
                Expected = '2001-12-14T21:59:43.1000000Z'
                Roundtrip = '2001-12-14T21:59:43.1000000Z'
            }
            @{
                Value = [DateTime]::new(2001, 12, 14, 21, 59, 43, 100, [System.DateTimeKind]::Unspecified)
                Expected = '2001-12-14T21:59:43.1000000'
                Roundtrip = '2001-12-14T21:59:43.1000000'
            }
            @{
                Value = [DateTimeOffset]::new(2001, 12, 14, 21, 59, 43, 100, (New-TimeSpan -Hours 0))
                Expected = '2001-12-14T21:59:43.1000000+00:00'
                Roundtrip = '2001-12-14T21:59:43.1000000+00:00'
            }
            @{
                Value = [DateTimeOffset]::new(2001, 12, 14, 21, 59, 43, 100, (New-TimeSpan -Hours 5))
                Expected = '2001-12-14T21:59:43.1000000+05:00'
                Roundtrip = '2001-12-14T21:59:43.1000000+05:00'
            }
            @{
                Value = [DateTimeOffset]::new(2001, 12, 14, 21, 59, 43, 100, (New-TimeSpan -Hours -5))
                Expected = '2001-12-14T21:59:43.1000000-05:00'
                Roundtrip = '2001-12-14T21:59:43.1000000-05:00'
            }
            @{
                Value = [Guid]::new("1ccddbdb-4815-4457-8054-b3e381268588")
                Expected = '1ccddbdb-4815-4457-8054-b3e381268588'
                Roundtrip = '1ccddbdb-4815-4457-8054-b3e381268588'
            }
        ) {
            param ($Value, $Expected, $Roundtrip)
            $actual = ConvertTo-Yaml -InputObject $Value
            $actual | Should -Be $Expected

            $roundtripActual = ConvertFrom-Yaml $actual
            $roundtripActual | Should -BeOfType $Roundtrip.GetType()

            if ($roundTripActual -is [double] -and $roundtripActual.ToString() -eq 'NaN') {
                $roundtripActual.ToString() | Should -Be $Roundtrip.ToString()
            }
            else {
                $roundtripActual | Should -Be $Roundtrip
            }
        }

        It "Emits dict" {
            $actual = ConvertTo-Yaml -InputObject @{ foo = 'bar' }
            $actual | Should -Be 'foo: bar'
        }

        It "Emits list" {
            $actual = ConvertTo-Yaml -InputObject @(1, '2')
            $actual | Should -Be "- 1$n- ""2"""
        }

        It "Emits bool with custom style <Style>" -TestCases @(
            @{ Style = "Any"; Expected = 'true' }
            @{ Style = "Plain"; Expected = 'true' }
            @{ Style = "SingleQuoted"; Expected = "!!bool 'true'" }
            @{ Style = "DoubleQuoted"; Expected = '!!bool "true"' }
            @{ Style = "Literal"; Expected = "!!bool |-$n  true" }
            @{ Style = "Folded"; Expected = "!!bool >-$n  true" }
        ) {
            param ($Style, $Expected)

            $value = $true | Add-YamlFormat -ScalarStyle $Style -PassThru
            $actual = ConvertTo-Yaml -InputObject $value
            $value.PSObject.Properties.Remove("_YayamlFormat")
            $actual | Should -Be $Expected

            $roundtrip = ConvertFrom-Yaml -InputObject $actual
            $roundtrip | Should -BeTrue
            $roundtrip | Should -BeOfType ([bool])
        }

        It "Emits enum with custom style <Style>" -TestCases @(
            @{ Style = "Any"; Expected = '1' }
            @{ Style = "Plain"; Expected = '1' }
            @{ Style = "SingleQuoted"; Expected = "!!int '1'" }
            @{ Style = "DoubleQuoted"; Expected = '!!int "1"' }
            @{ Style = "Literal"; Expected = "!!int |-$n  1" }
            @{ Style = "Folded"; Expected = "!!int >-$n  1" }
        ) {
            param ($Style, $Expected)

            $value = [System.IO.FileShare]::Read | Add-YamlFormat -ScalarStyle $Style -PassThru
            $actual = ConvertTo-Yaml -InputObject $value
            $value.PSObject.Properties.Remove("_YayamlFormat")
            $actual | Should -Be $Expected

            $roundtrip = ConvertFrom-Yaml -InputObject $actual
            $roundtrip | Should -Be 1
            $roundtrip | Should -BeOfType ([int])
        }

        It "Emits int with custom style <Style>" -TestCases @(
            @{ Style = "Any"; Expected = '1' }
            @{ Style = "Plain"; Expected = '1' }
            @{ Style = "SingleQuoted"; Expected = "!!int '1'" }
            @{ Style = "DoubleQuoted"; Expected = '!!int "1"' }
            @{ Style = "Literal"; Expected = "!!int |-$n  1" }
            @{ Style = "Folded"; Expected = "!!int >-$n  1" }
        ) {
            param ($Style, $Expected)

            $value = 1 | Add-YamlFormat -ScalarStyle $Style -PassThru
            $actual = ConvertTo-Yaml -InputObject $value
            $value.PSObject.Properties.Remove("_YayamlFormat")
            $actual | Should -Be $Expected

            $roundtrip = ConvertFrom-Yaml -InputObject $actual
            $roundtrip | Should -Be 1
            $roundtrip | Should -BeOfType ([int])
        }

        It "Emits float with custom style <Style>" -TestCases @(
            @{ Style = "Any"; Expected = '1.1e+0' }
            @{ Style = "Plain"; Expected = '1.1e+0' }
            @{ Style = "SingleQuoted"; Expected = "!!float '1.1e+0'" }
            @{ Style = "DoubleQuoted"; Expected = '!!float "1.1e+0"' }
            @{ Style = "Literal"; Expected = "!!float |-$n  1.1e+0" }
            @{ Style = "Folded"; Expected = "!!float >-$n  1.1e+0" }
        ) {
            param ($Style, $Expected)

            $value = 1.1 | Add-YamlFormat -ScalarStyle $Style -PassThru
            $actual = ConvertTo-Yaml -InputObject $value
            $value.PSObject.Properties.Remove("_YayamlFormat")
            $actual | Should -Be $Expected

            $roundtrip = ConvertFrom-Yaml -InputObject $actual
            $roundtrip | Should -Be 1.1
            $roundtrip | Should -BeOfType ([double])
        }

        It "Emits string with custom style <Style>" -TestCases @(
            @{ Style = "Any"; Expected = 'abc' }
            @{ Style = "Plain"; Expected = "abc" }
            @{ Style = "SingleQuoted"; Expected = "'abc'" }
            @{ Style = "DoubleQuoted"; Expected = '"abc"' }
            @{ Style = "Literal"; Expected = "|-$n  abc" }
            @{ Style = "Folded"; Expected = ">-$n  abc" }
        ) {
            param ($Style, $Expected)

            $value = 'abc' | Add-YamlFormat -ScalarStyle $Style -PassThru
            $actual = ConvertTo-Yaml -InputObject $value
            $actual | Should -Be $Expected

            $roundtrip = ConvertFrom-Yaml -InputObject $actual
            $roundtrip | Should -Be abc
            $roundtrip | Should -BeOfType ([string])
        }

        It "Emits PSCustomObject" {
            $value = [PSCustomObject]@{
                Foo = 'bar'
                1 = 'test'
            }

            $actual = ConvertTo-Yaml -InputObject $value
            $actual | Should -Be "Foo: bar$n""1"": test"
        }
    }

    Context "YAML 1.2 JSON Schema" {
        It "Emits null value" {
            $actual = ConvertTo-Yaml -InputObject $null -Schema Yaml12JSON
            $actual | Should -Be null
        }
        It "Emits <Value.GetType().Name> value <Value>" -TestCases @(
            # bool
            @{ Value = $true; Expected = 'true'; Roundtrip = $true }
            @{ Value = $false; Expected = 'false'; Roundtrip = $false }

            # int
            @{ Value = 0; Expected = '0'; Roundtrip = 0 }
            @{ Value = 1; Expected = '1'; Roundtrip = 1 }
            @{ Value = -1; Expected = '-1'; Roundtrip = -1 }
            @{ Value = [System.IO.FileShare]::Read; Expected = '1'; Roundtrip = 1 }
            @{ Value = [byte]1; Expected = 1; Roundtrip = 1 }
            @{ Value = [sbyte]1; Expected = 1; Roundtrip = 1 }
            @{ Value = [int16]1; Expected = 1; Roundtrip = 1 }
            @{ Value = [uint16]1; Expected = 1; Roundtrip = 1 }
            @{ Value = [int32]1; Expected = 1; Roundtrip = 1 }
            @{ Value = [uint32]1; Expected = 1; Roundtrip = 1 }
            @{ Value = [int64]1; Expected = 1; Roundtrip = 1 }
            @{ Value = [uint64]1; Expected = 1; Roundtrip = 1 }
            @{ Value = [System.Numerics.BigInteger]::new(1); Expected = 1; Roundtrip = 1 }

            # float
            @{ Value = [float]'0'; Expected = '0.0e+0'; Roundtrip = [double]'0' }
            @{ Value = [float]'1'; Expected = '1.0e+0'; Roundtrip = [double]'1' }
            @{ Value = [float]'1.0'; Expected = '1.0e+0'; Roundtrip = [double]'1' }
            @{ Value = [float]'1.1E+20'; Expected = '1.1e+20'; Roundtrip = [double]'1.1e+20' }
            @{ Value = [float]'-1.1E+20'; Expected = '-1.1e+20'; Roundtrip = [double]'-1.1e+20' }
            @{ Value = [float]'1.1E-20'; Expected = '1.1e-20'; Roundtrip = [double]'1.1e-20' }
            @{ Value = [float]'-1.1E-20'; Expected = '-1.1e-20'; Roundtrip = [double]'-1.1e-20' }
            @{ Value = [float]::PositiveInfinity; Expected = '!!float .inf'; Roundtrip = [double]::PositiveInfinity }
            @{ Value = [float]::NegativeInfinity; Expected = '!!float -.inf'; Roundtrip = [double]::NegativeInfinity }
            @{ Value = [float]::NaN; Expected = '!!float .nan'; Roundtrip = [double]::NaN }
            @{ Value = [double]'0'; Expected = '0.0e+0'; Roundtrip = [double]'0' }
            @{ Value = [double]'1.1E+20'; Expected = '1.1e+20'; Roundtrip = [double]'1.1e20' }
            @{ Value = [double]'-1.1E+20'; Expected = '-1.1e+20'; Roundtrip = [double]'-1.1e20' }
            @{ Value = [double]'1.1E-20'; Expected = '1.1e-20'; Roundtrip = [double]'1.1e-20' }
            @{ Value = [double]'-1.1E-20'; Expected = '-1.1e-20'; Roundtrip = [double]'-1.1e-20' }
            @{ Value = [double]::PositiveInfinity; Expected = '!!float .inf'; Roundtrip = [double]::PositiveInfinity }
            @{ Value = [double]::NegativeInfinity; Expected = '!!float -.inf'; Roundtrip = [double]::NegativeInfinity }
            @{ Value = [double]::NaN; Expected = '!!float .nan'; Roundtrip = [double]::NaN }
            @{ Value = [decimal]'0'; Expected = '0.0e+0'; Roundtrip = [double]'0' }
            @{ Value = [decimal][double]'1.1E+20'; Expected = '1.1e+20'; Roundtrip = [double]'1.1e20' }
            @{ Value = [decimal][double]'-1.1E+20'; Expected = '-1.1e+20'; Roundtrip = [double]'-1.1e20' }
            @{ Value = [decimal][double]'1.1E-20'; Expected = '1.1e-20'; Roundtrip = [double]'1.1e-20' }
            @{ Value = [decimal][double]'-1.1E-20'; Expected = '-1.1e-20'; Roundtrip = [double]'-1.1e-20' }

            # str
            @{ Value = 'abc'; Expected = '"abc"'; Roundtrip = 'abc' }
            @{ Value = '1'; Expected = '"1"'; Roundtrip = '1' }
            @{ Value = '0x1'; Expected = '"0x1"'; Roundtrip = '0x1' }
            @{ Value = '""'; Expected = '"\"\""'; Roundtrip = '""' }
            @{ Value = "''"; Expected = '"''''"'; Roundtrip = "''" }
            @{ Value = 'yes'; Expected = '"yes"'; Roundtrip = 'yes' }
            @{ Value = 'true'; Expected = '"true"'; Roundtrip = 'true' }
            @{ Value = "$([Char]::ConvertFromUtf32(0x1F4A9))"; Expected = '"\U0001F4A9"'; Roundtrip = "$([Char]::ConvertFromUtf32(0x1F4A9))" }
            @{ Value = '"\U0001F4A9"'; Expected = '"\"\\U0001F4A9\""'; Roundtrip = '"\U0001F4A9"' }
            @{ Value = '\U0001F4A9'; Expected = '"\\U0001F4A9"'; Roundtrip = '\U0001F4A9' }

            # misc
            @{
                Value = [DateTime]::new(2001, 12, 14, 21, 59, 43, 100, [System.DateTimeKind]::Local)
                Expected = """2001-12-14T21:59:43.1000000$([DateTime]::Now.ToString('zzz'))"""
                Roundtrip = "2001-12-14T21:59:43.1000000$([DateTime]::Now.ToString('zzz'))"
            }
            @{
                Value = [DateTime]::new(2001, 12, 14, 21, 59, 43, 100, [System.DateTimeKind]::Utc)
                Expected = '"2001-12-14T21:59:43.1000000Z"'
                Roundtrip = '2001-12-14T21:59:43.1000000Z'
            }
            @{
                Value = [DateTime]::new(2001, 12, 14, 21, 59, 43, 100, [System.DateTimeKind]::Unspecified)
                Expected = '"2001-12-14T21:59:43.1000000"'
                Roundtrip = '2001-12-14T21:59:43.1000000'
            }
            @{
                Value = [DateTimeOffset]::new(2001, 12, 14, 21, 59, 43, 100, (New-TimeSpan -Hours 0))
                Expected = '"2001-12-14T21:59:43.1000000+00:00"'
                Roundtrip = '2001-12-14T21:59:43.1000000+00:00'
            }
            @{
                Value = [DateTimeOffset]::new(2001, 12, 14, 21, 59, 43, 100, (New-TimeSpan -Hours 5))
                Expected = '"2001-12-14T21:59:43.1000000+05:00"'
                Roundtrip = '2001-12-14T21:59:43.1000000+05:00'
            }
            @{
                Value = [DateTimeOffset]::new(2001, 12, 14, 21, 59, 43, 100, (New-TimeSpan -Hours -5))
                Expected = '"2001-12-14T21:59:43.1000000-05:00"'
                Roundtrip = '2001-12-14T21:59:43.1000000-05:00'
            }
            @{
                Value = [Guid]::new("1ccddbdb-4815-4457-8054-b3e381268588")
                Expected = '"1ccddbdb-4815-4457-8054-b3e381268588"'
                Roundtrip = '1ccddbdb-4815-4457-8054-b3e381268588'
            }
        ) {
            param ($Value, $Expected, $Roundtrip)
            $actual = ConvertTo-Yaml -InputObject $Value -Schema Yaml12JSON
            $actual | Should -Be $Expected

            $roundtripActual = ConvertFrom-Yaml $actual -Schema Yaml12JSON
            $roundtripActual | Should -BeOfType $Roundtrip.GetType()

            if ($roundTripActual -is [double] -and $roundtripActual.ToString() -eq 'NaN') {
                $roundtripActual.ToString() | Should -Be $Roundtrip.ToString()
            }
            else {
                $roundtripActual | Should -Be $Roundtrip
            }
        }

        It "Emits dict" {
            $actual = ConvertTo-Yaml -InputObject @{ foo = 'bar' } -Schema Yaml12JSON
            $actual | Should -Be '{"foo": "bar"}'
        }

        It "Emits list" {
            $actual = ConvertTo-Yaml -InputObject @(1, '2') -Schema Yaml12JSON
            $actual | Should -Be '[1, "2"]'
        }

        It "Emits bool with custom style <Style>" -TestCases @(
            @{ Style = "Any"; Expected = 'true' }
            @{ Style = "Plain"; Expected = 'true' }
            @{ Style = "SingleQuoted"; Expected = "!!bool 'true'" }
            @{ Style = "DoubleQuoted"; Expected = '!!bool "true"' }
            @{ Style = "Literal"; Expected = "!!bool |-$n  true" }
            @{ Style = "Folded"; Expected = "!!bool >-$n  true" }
        ) {
            param ($Style, $Expected)

            $value = $true | Add-YamlFormat -ScalarStyle $Style -PassThru
            $actual = ConvertTo-Yaml -InputObject $value -Schema Yaml12JSON
            $value.PSObject.Properties.Remove("_YayamlFormat")
            $actual | Should -Be $Expected

            $roundtrip = ConvertFrom-Yaml -InputObject $actual -Schema Yaml12JSON
            $roundtrip | Should -BeTrue
            $roundtrip | Should -BeOfType ([bool])
        }

        It "Emits enum with custom style <Style>" -TestCases @(
            @{ Style = "Any"; Expected = '1' }
            @{ Style = "Plain"; Expected = '1' }
            @{ Style = "SingleQuoted"; Expected = "!!int '1'" }
            @{ Style = "DoubleQuoted"; Expected = '!!int "1"' }
            @{ Style = "Literal"; Expected = "!!int |-$n  1" }
            @{ Style = "Folded"; Expected = "!!int >-$n  1" }
        ) {
            param ($Style, $Expected)

            $value = [System.IO.FileShare]::Read | Add-YamlFormat -ScalarStyle $Style -PassThru
            $actual = ConvertTo-Yaml -InputObject $value -Schema Yaml12JSON
            $value.PSObject.Properties.Remove("_YayamlFormat")
            $actual | Should -Be $Expected

            $roundtrip = ConvertFrom-Yaml -InputObject $actual -Schema Yaml12JSON
            $roundtrip | Should -Be 1
            $roundtrip | Should -BeOfType ([int])
        }

        It "Emits int with custom style <Style>" -TestCases @(
            @{ Style = "Any"; Expected = '1' }
            @{ Style = "Plain"; Expected = '1' }
            @{ Style = "SingleQuoted"; Expected = "!!int '1'" }
            @{ Style = "DoubleQuoted"; Expected = '!!int "1"' }
            @{ Style = "Literal"; Expected = "!!int |-$n  1" }
            @{ Style = "Folded"; Expected = "!!int >-$n  1" }
        ) {
            param ($Style, $Expected)

            $value = 1 | Add-YamlFormat -ScalarStyle $Style -PassThru
            $actual = ConvertTo-Yaml -InputObject $value -Schema Yaml12JSON
            $value.PSObject.Properties.Remove("_YayamlFormat")
            $actual | Should -Be $Expected

            $roundtrip = ConvertFrom-Yaml -InputObject $actual -Schema Yaml12JSON
            $roundtrip | Should -Be 1
            $roundtrip | Should -BeOfType ([int])
        }

        It "Emits float with custom style <Style>" -TestCases @(
            @{ Style = "Any"; Expected = '1.1e+0' }
            @{ Style = "Plain"; Expected = '1.1e+0' }
            @{ Style = "SingleQuoted"; Expected = "!!float '1.1e+0'" }
            @{ Style = "DoubleQuoted"; Expected = '!!float "1.1e+0"' }
            @{ Style = "Literal"; Expected = "!!float |-$n  1.1e+0" }
            @{ Style = "Folded"; Expected = "!!float >-$n  1.1e+0" }
        ) {
            param ($Style, $Expected)

            $value = 1.1 | Add-YamlFormat -ScalarStyle $Style -PassThru
            $actual = ConvertTo-Yaml -InputObject $value -Schema Yaml12JSON
            $value.PSObject.Properties.Remove("_YayamlFormat")
            $actual | Should -Be $Expected

            $roundtrip = ConvertFrom-Yaml -InputObject $actual -Schema Yaml12JSON
            $roundtrip | Should -Be 1.1
            $roundtrip | Should -BeOfType ([double])
        }

        It "Emits string with custom style <Style>" -TestCases @(
            @{ Style = "Any"; Expected = '"abc"' }
            @{ Style = "Plain"; Expected = "!!str abc" }
            @{ Style = "SingleQuoted"; Expected = "'abc'" }
            @{ Style = "DoubleQuoted"; Expected = '"abc"' }
            @{ Style = "Literal"; Expected = "|-$n  abc" }
            @{ Style = "Folded"; Expected = ">-$n  abc" }
        ) {
            param ($Style, $Expected)

            $value = 'abc' | Add-YamlFormat -ScalarStyle $Style -PassThru
            $actual = ConvertTo-Yaml -InputObject $value -Schema Yaml12JSON
            $actual | Should -Be $Expected

            $roundtrip = ConvertFrom-Yaml -InputObject $actual -Schema Yaml12JSON
            $roundtrip | Should -Be abc
            $roundtrip | Should -BeOfType ([string])
        }

        It "Emits PSCustomObject" {
            $value = [PSCustomObject]@{
                Foo = 'bar'
                1 = 'test'
            }

            $actual = ConvertTo-Yaml -InputObject $value -Schema Yaml12JSON
            $actual | Should -Be '{"Foo": "bar", "1": "test"}'
        }
    }

    Context "Custom Schema" {
        It "Emits with custom scalar handler with datetime PSObject props" {
            $schema = New-YamlSchema -EmitScalar {
                param ($Value, $Schema)

                # It relies on casting to automatically create the ScalarValue
                $Value.PSObject.Properties.Match('test').Value
            }

            $obj = Get-Date | Add-Member -NotePropertyName test -NotePropertyValue value -PassThru
            $actual = ConvertTo-Yaml -InputObject $obj -Schema $schema
            $actual | Should -Be value
        }

        It "Emits with custom scaler handler with string PSObject props" {
            $schema = New-YamlSchema -EmitScalar {
                param ($Value, $Schema)

                [Yayaml.ScalarValue]@{
                    Value = $Value.PSObject.Properties.Match('test').Value
                    Style = 'Literal'
                }
            }

            $obj = "abc" | Add-Member -NotePropertyName test -NotePropertyValue value -PassThru
            $actual = ConvertTo-Yaml -InputObject $obj -Schema $schema
            $actual | Should -Be "|-$n  value"
        }

        It "Emits with custom scalar checker" {
            $schema = New-YamlSchema -IsScalar {
                param ($Value, $Schema)

                if ($Value -is [type]) {
                    $true
                }
                else {
                    $Schema.IsScalar($Value)
                }
            }

            $actual = ConvertTo-Yaml @{ foo = [type] } -Schema $schema
            $actual | Should -Be 'foo: type'
        }

        It "Emits with custom map handler" {
            $schema = New-YamlSchema -EmitMap {
                param ($Values, $Schema)

                $Values.test = 'other'

                [Yayaml.MapValue]@{
                    Values = $Values
                    Style = 'Flow'
                }
            }

            $actual = ConvertTo-Yaml ([Ordered]@{ foo = 'bar' }) -Schema $schema
            $actual | Should -Be '{foo: bar, test: other}'
        }

        It "Emits with custom sequence handler" {
            $schema = New-YamlSchema -EmitSequence {
                param ($Values, $Schema)

                $Values = @(
                    $Values
                    'end'
                )

                [Yayaml.SequenceValue]@{
                    Values = $Values
                    Style = 'Flow'
                }
            }

            $actual = ConvertTo-Yaml @(1, 2) -Schema $schema
            $actual | Should -Be '[1, 2, end]'
        }

        It "Emits with custom transformer" {
            class MyClass {
                [string]$Value1
                [string]$Value2
            }
            $value = [MyClass]@{
                Value1 = 'foo'
                Value2 = 'bar'
            }

            $schema = New-YamlSchema -EmitTransformer {
                param($Value, $Schema)

                if ($value -is [MyClass]) {
                    [Ordered]@{
                        Value2 = $Value.Value2 | Add-YamlFormat -ScalarStyle DoubleQuoted -PassThru
                        Value1 = $Value.Value1 | Add-YamlFormat -ScalarStyle SingleQuoted -PassThru
                    }
                }
                else {
                    $Schema.EmitTransformer($Value)
                }
            }

            $actual = ConvertTo-Yaml $value -Schema $schema
            $actual | Should -Be "Value2: ""bar""$($n)Value1: 'foo'"

        }

        It "Emits with custom transformer - MapValue" {
            class MyClass {
                [string]$Value1
                [string]$Value2
            }
            $value = [MyClass]@{
                Value1 = 'foo'
                Value2 = 'bar'
            }

            $schema = New-YamlSchema -EmitTransformer {
                param($Value, $Schema)

                if ($value -is [MyClass]) {
                    [Yayaml.MapValue]@{
                        Values = [Ordered]@{
                            Value2 = $Value.Value2 | Add-YamlFormat -ScalarStyle DoubleQuoted -PassThru
                            Value1 = $Value.Value1 | Add-YamlFormat -ScalarStyle SingleQuoted -PassThru
                        }
                        Style = 'Flow'
                    }
                }
                else {
                    $Schema.EmitTransformer($Value)
                }
            } -EmitMap {
                throw "This should not happen"
            }

            $actual = ConvertTo-Yaml $value -Schema $schema
            $actual | Should -Be "{Value2: ""bar"", Value1: 'foo'}"
        }

        It "Emits with custom transformer - ScalarValue" {
            class MyClass {
                [string]$Value1
                [string]$Value2
            }
            $value = [MyClass]@{
                Value1 = 'foo'
                Value2 = 'bar'
            }

            $schema = New-YamlSchema -EmitTransformer {
                param($Value, $Schema)

                if ($value -is [MyClass]) {
                    [Yayaml.ScalarValue]@{
                        Value = "$($value.Value1) - $($value.Value2)"
                        Style = 'DoubleQuoted'
                    }
                }
                else {
                    $Schema.EmitTransformer($Value)
                }
            } -EmitScalar {
                throw "This should not happen"
            }

            $actual = ConvertTo-Yaml $value -Schema $schema
            $actual | Should -Be '"foo - bar"'
        }

        It "Emits with custom transformer - SequenceValue" {
            class MyClass {
                [string]$Value1
                [string]$Value2
            }
            $value = [MyClass]@{
                Value1 = 'foo'
                Value2 = 'bar'
            }

            $schema = New-YamlSchema -EmitTransformer {
                param($Value, $Schema)

                if ($value -is [MyClass]) {
                    [Yayaml.SequenceValue]@{
                        Values = @(
                            $Value.Value1 | Add-YamlFormat -ScalarStyle SingleQuoted -PassThru
                            $Value.Value2 | Add-YamlFormat -ScalarStyle DoubleQuoted -PassThru
                        )
                        Style = 'Flow'
                    }
                }
                else {
                    $Schema.EmitTransformer($Value)
                }
            } -EmitSequence {
                throw "This should not happen"
            }

            $actual = ConvertTo-Yaml $value -Schema $schema
            $actual | Should -Be "['foo', ""bar""]"
        }
    }
}
