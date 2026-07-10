. ([IO.Path]::Combine($PSScriptRoot, 'common.ps1'))

Describe "Import-Yaml" {
    BeforeAll {
        $testDir = Join-Path $TestDrive "Import-Yaml"
        New-Item -Path $testDir -ItemType Directory -Force | Out-Null
    }

    Context "Basic Functionality" {
        It "Imports YAML from a file" {
            $testFile = Join-Path $testDir "simple.yaml"
            "foo: bar`ntest: 1" | Set-Content -LiteralPath $testFile -NoNewline

            $actual = Import-Yaml -Path $testFile
            $actual.foo | Should -Be 'bar'
            $actual.test | Should -Be 1
        }

        It "Imports YAML with Path parameter from pipeline" {
            $testFile = Join-Path $testDir "pipeline.yaml"
            "key: value" | Set-Content -LiteralPath $testFile -NoNewline

            $actual = $testFile | Import-Yaml
            $actual.key | Should -Be 'value'
        }

        It "Imports multiple YAML files" {
            $file1 = Join-Path $testDir "multi1.yaml"
            $file2 = Join-Path $testDir "multi2.yaml"
            "file1: data1" | Set-Content -LiteralPath $file1 -NoNewline
            "file2: data2" | Set-Content -LiteralPath $file2 -NoNewline

            $actual = Import-Yaml -Path $file1, $file2
            $actual.Count | Should -Be 2
            $actual[0].file1 | Should -Be 'data1'
            $actual[1].file2 | Should -Be 'data2'
        }

        It "Imports YAML with wildcard paths" {
            $wildcardDir = Join-Path $testDir "wildcard"
            New-Item -Path $wildcardDir -ItemType Directory -Force | Out-Null
            $file1 = Join-Path $wildcardDir "test1.yaml"
            $file2 = Join-Path $wildcardDir "test2.yaml"
            "a: 1" | Set-Content -LiteralPath $file1 -NoNewline
            "b: 2" | Set-Content -LiteralPath $file2 -NoNewline

            $actual = Import-Yaml -Path (Join-Path $wildcardDir "*.yaml")
            $actual.Count | Should -Be 2
        }

        It "Imports YAML with wildcard paths through pipeline" {
            $wildcardDir = Join-Path $testDir "wildcard-pipe"
            New-Item -Path $wildcardDir -ItemType Directory -Force | Out-Null
            $file1 = Join-Path $wildcardDir "pipe[1].yaml"
            $file2 = Join-Path $wildcardDir "pipe[2].yaml"
            "c: 3" | Set-Content -LiteralPath $file1 -NoNewline
            "d: 4" | Set-Content -LiteralPath $file2 -NoNewline

            $actual = Get-Item (Join-Path $wildcardDir "*.yaml") | Import-Yaml
            $actual.Count | Should -Be 2
        }

        It "Imports YAML with LiteralPath parameter" {
            $testFile = Join-Path $testDir "literal[test].yaml"
            "literal: true" | Set-Content -LiteralPath $testFile -NoNewline

            $actual = Import-Yaml -LiteralPath $testFile
            $actual.literal | Should -BeTrue
        }

        It "Imports YAML with LiteralPath through PSPath alias" {
            $testFile = Join-Path $testDir "pspath[test].yaml"
            "pspath: true" | Set-Content -LiteralPath $testFile -NoNewline

            $actual = Get-Item -LiteralPath $testFile | Import-Yaml
            $actual.pspath | Should -BeTrue
        }

        It "Returns a single array element without NoEnumerate" {
            $testFile = Join-Path $testDir "single-array.yaml"
            "- value" | Set-Content -LiteralPath $testFile -NoNewline

            $actual = Import-Yaml -Path $testFile
            Should -ActualValue $actual -BeOfType ([string])
            $actual | Should -Be 'value'
        }

        It "Returns array with NoEnumerate for single element" {
            $testFile = Join-Path $testDir "single-noenum.yaml"
            "- value" | Set-Content -LiteralPath $testFile -NoNewline

            $actual = Import-Yaml -Path $testFile -NoEnumerate
            Should -ActualValue $actual -BeOfType ([object[]])
            $actual.Count | Should -Be 1
            $actual[0] | Should -Be 'value'
        }

        It "Returns multiple array elements as array" {
            $testFile = Join-Path $testDir "multi-array.yaml"
            "- item1`n- item2`n- item3" | Set-Content -LiteralPath $testFile -NoNewline

            $actual = Import-Yaml -Path $testFile
            Should -ActualValue $actual -BeOfType ([object[]])
            $actual.Count | Should -Be 3
            $actual[0] | Should -Be 'item1'
            $actual[2] | Should -Be 'item3'
        }

        It "Imports multiple documents from a file" {
            $testFile = Join-Path $testDir "multi-doc.yaml"
            @"
---
doc: 1
---
doc: 2
"@ | Set-Content -LiteralPath $testFile -NoNewline

            $actual = Import-Yaml -Path $testFile
            $actual.Count | Should -Be 2
            $actual[0].doc | Should -Be 1
            $actual[1].doc | Should -Be 2
        }

        It "Returns scalar value as-is" {
            $testFile = Join-Path $testDir "scalar.yaml"
            "just a string" | Set-Content -LiteralPath $testFile -NoNewline

            $actual = Import-Yaml -Path $testFile
            Should -ActualValue $actual -BeOfType ([string])
            $actual | Should -Be 'just a string'
        }

        It "Returns dictionary as OrderedDictionary" {
            $testFile = Join-Path $testDir "dict.yaml"
            "key1: val1`nkey2: val2" | Set-Content -LiteralPath $testFile -NoNewline

            $actual = Import-Yaml -Path $testFile
            $actual | Should -BeOfType ([System.Collections.Specialized.OrderedDictionary])
            $actual.key1 | Should -Be 'val1'
            $actual.key2 | Should -Be 'val2'
        }
    }

    Context "Schema Parameter" {
        It "Imports with default YAML 1.2 schema" {
            $testFile = Join-Path $testDir "yaml12.yaml"
            "value: yes" | Set-Content -LiteralPath $testFile -NoNewline

            $actual = Import-Yaml -Path $testFile
            $actual.value | Should -Be 'yes'
            $actual.value | Should -BeOfType ([string])
        }

        It "Imports with YAML 1.1 schema" {
            $testFile = Join-Path $testDir "yaml11.yaml"
            "value: yes" | Set-Content -LiteralPath $testFile -NoNewline

            $actual = Import-Yaml -Path $testFile -Schema Yaml11
            $actual.value | Should -BeTrue
            $actual.value | Should -BeOfType ([bool])
        }

        It "Imports with Blank schema" {
            $testFile = Join-Path $testDir "blank.yaml"
            "value: 123" | Set-Content -LiteralPath $testFile -NoNewline

            $actual = Import-Yaml -Path $testFile -Schema Blank
            $actual.value | Should -Be '123'
            $actual.value | Should -BeOfType ([string])
        }

        It "Imports with YAML12JSON schema" {
            $testFile = Join-Path $testDir "yaml12json.yaml"
            @"
"bool": true
"int": 42
"@  | Set-Content -LiteralPath $testFile -NoNewline

            $actual = Import-Yaml -Path $testFile -Schema Yaml12JSON
            $actual.bool | Should -BeTrue
            $actual.int | Should -Be 42
        }

        It "Imports with custom schema" {
            $testFile = Join-Path $testDir "custom.yaml"
            "custom: !!test value" | Set-Content -LiteralPath $testFile -NoNewline

            $schema = New-YamlSchema -ParseScalar {
                param ($Value, $Schema)
                if ($Value.Tag -eq 'tag:yaml.org,2002:test') {
                    'custom-value'
                }
                else {
                    $Schema.ParseScalar($Value)
                }
            }

            $actual = Import-Yaml -Path $testFile -Schema $schema
            $actual.custom | Should -Be 'custom-value'
        }
    }

    Context "Encoding Parameter" {
        It "Imports with default UTF8 encoding and BOM detection" {
            $testFile = Join-Path $testDir "utf8-bom-detect.yaml"
            $content = "emoji: $([Char]::ConvertFromUtf32(0x1F680))"
            [System.IO.File]::WriteAllText($testFile, $content, [System.Text.UTF8Encoding]::new($true))

            $actual = Import-Yaml -Path $testFile
            $actual.emoji | Should -Be $([Char]::ConvertFromUtf32(0x1F680))
        }

        It "Imports with explicit UTF8 encoding" {
            $testFile = Join-Path $testDir "utf8.yaml"
            $content = "unicode: $([Char]::ConvertFromUtf32(0x1F4A9))"
            [System.IO.File]::WriteAllText($testFile, $content, [System.Text.UTF8Encoding]::new($false))

            $actual = Import-Yaml -Path $testFile -Encoding UTF8
            $actual.unicode | Should -Be $([Char]::ConvertFromUtf32(0x1F4A9))
        }

        It "Imports with UTF8Bom encoding" {
            $testFile = Join-Path $testDir "utf8bom.yaml"
            $content = "char: $([Char]0x00E9)"
            [System.IO.File]::WriteAllText($testFile, $content, [System.Text.UTF8Encoding]::new($true))

            $actual = Import-Yaml -Path $testFile -Encoding UTF8Bom
            $actual.char | Should -Be $([Char]0x00E9)
        }

        It "Imports with ASCII encoding" {
            $testFile = Join-Path $testDir "ascii.yaml"
            $content = "ascii: test"
            [System.IO.File]::WriteAllText($testFile, $content, [System.Text.ASCIIEncoding]::new())

            $actual = Import-Yaml -Path $testFile -Encoding ASCII
            $actual.ascii | Should -Be 'test'
        }

        It "Imports with Unicode encoding" {
            $testFile = Join-Path $testDir "unicode.yaml"
            $content = "char: $([Char]0x03B1)"
            [System.IO.File]::WriteAllText($testFile, $content, [System.Text.UnicodeEncoding]::new())

            $actual = Import-Yaml -Path $testFile -Encoding Unicode
            $actual.char | Should -Be $([Char]0x03B1)
        }

        It "Imports with ANSI encoding" {
            $testFile = Join-Path $testDir "ansi.yaml"
            $ansiEncoding = [System.Text.Encoding]::GetEncoding([System.Globalization.CultureInfo]::CurrentCulture.TextInfo.ANSICodePage)
            $content = "ansi: test"
            [System.IO.File]::WriteAllText($testFile, $content, $ansiEncoding)

            $actual = Import-Yaml -Path $testFile -Encoding ANSI
            $actual.ansi | Should -Be 'test'
        }
    }

    Context "Error Handling" {
        It "Writes error for non-existent file" {
            $nonExistent = Join-Path $testDir "does-not-exist-continue.yaml"

            $null = Import-Yaml -Path $nonExistent -ErrorAction SilentlyContinue -ErrorVariable err
            $err.Count | Should -Be 1
            $err[0].CategoryInfo.Category | Should -Be ObjectNotFound
            $err[0].FullyQualifiedErrorId | Should -Be 'FileNotFound,Yayaml.ImportYamlCommand'
        }

        It "Handles invalid YAML syntax" {
            $testFile = Join-Path $testDir "invalid.yaml"
            "foo: bar: baz" | Set-Content -LiteralPath $testFile -NoNewline

            $null = Import-Yaml -Path $testFile -ErrorAction SilentlyContinue -ErrorVariable err
            $err.Count | Should -Be 1
            $err[0].CategoryInfo.Category | Should -Be ParserError
        }

        It "Writes error for non-filesystem path" {
            $null = Import-Yaml -Path "env:\PATH" -ErrorAction SilentlyContinue -ErrorVariable err
            $err.Count | Should -Be 1
            $err[0].CategoryInfo.Category | Should -Be InvalidArgument
            [string]$err[0] | Should -BeLike "*is not a FileSystem path*"
        }

        It "Continues processing multiple files when one fails" {
            $validFile = Join-Path $testDir "valid.yaml"
            $invalidFile = Join-Path $testDir "does-not-exist-multi.yaml"
            "valid: data" | Set-Content -LiteralPath $validFile -NoNewline

            $result = @(Import-Yaml -Path $validFile, $invalidFile -ErrorAction SilentlyContinue -ErrorVariable err)
            $result.Count | Should -Be 1
            $result[0].valid | Should -Be 'data'
            $err.Count | Should -Be 1
        }

        It "Fails with missing -LiteralPath" {
            $err = $null
            Import-Yaml -LiteralPath 'missing.yml' -ErrorAction SilentlyContinue -ErrorVariable err

            $err | Should -HaveCount 1
            [string]$err | Should -BeLike "Cannot find path '*missing.yml' because it does not exist."
        }
    }

    Context "Path Resolution" {
        It "Resolves relative paths" {
            $testFile = Join-Path $testDir "relative.yaml"
            "relative: path" | Set-Content -LiteralPath $testFile -NoNewline

            Push-Location $testDir
            try {
                $actual = Import-Yaml -Path "relative.yaml"
                $actual.relative | Should -Be 'path'
            }
            finally {
                Pop-Location
            }
        }

        It "Resolves paths with .. in them" {
            $subDir = Join-Path $testDir "subdir"
            New-Item -Path $subDir -ItemType Directory -Force | Out-Null
            $testFile = Join-Path $testDir "parent.yaml"
            "parent: true" | Set-Content -LiteralPath $testFile -NoNewline

            Push-Location $subDir
            try {
                $actual = Import-Yaml -Path "../parent.yaml"
                $actual.parent | Should -BeTrue
            }
            finally {
                Pop-Location
            }
        }

        It "Resolves provider paths (PSDrive)" {
            $testFile = Join-Path $testDir "psdrive.yaml"
            "psdrive: test" | Set-Content -LiteralPath $testFile -NoNewline

            $driveName = "TestYaml"
            New-PSDrive -Name $driveName -PSProvider FileSystem -Root $testDir -Scope Global | Out-Null
            try {
                $actual = Import-Yaml -Path "${driveName}:\psdrive.yaml"
                $actual.psdrive | Should -Be 'test'
            }
            finally {
                Remove-PSDrive -Name $driveName -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context "Edge Cases" {
        It "Imports empty file" {
            $testFile = Join-Path $testDir "empty.yaml"
            "" | Set-Content -LiteralPath $testFile -NoNewline

            $actual = Import-Yaml -Path $testFile
            $actual | Should -BeNullOrEmpty
        }

        It "Imports file with only comments" {
            $testFile = Join-Path $testDir "comments.yaml"
            @"
# This is a comment
# Another comment
"@ | Set-Content -LiteralPath $testFile -NoNewline

            $actual = Import-Yaml -Path $testFile
            $actual | Should -BeNullOrEmpty
        }

        It "Imports YAML with null values" {
            $testFile = Join-Path $testDir "nulls.yaml"
            @"
key1: null
key2: ~
key3:
"@ | Set-Content -LiteralPath $testFile -NoNewline

            $actual = Import-Yaml -Path $testFile
            $actual.key1 | Should -BeNullOrEmpty
            $actual.key2 | Should -BeNullOrEmpty
            $actual.key3 | Should -BeNullOrEmpty
        }
    }

    Context "Type Preservation" {
        It "Preserves boolean types" {
            $testFile = Join-Path $testDir "bools.yaml"
            @"
true_val: true
false_val: false
"@ | Set-Content -LiteralPath $testFile -NoNewline

            $actual = Import-Yaml -Path $testFile
            $actual.true_val | Should -BeTrue
            $actual.true_val | Should -BeOfType ([bool])
            $actual.false_val | Should -BeFalse
            $actual.false_val | Should -BeOfType ([bool])
        }

        It "Preserves integer types" {
            $testFile = Join-Path $testDir "ints.yaml"
            @"
small: 42
large: 9223372036854775807
negative: -123
"@ | Set-Content -LiteralPath $testFile -NoNewline

            $actual = Import-Yaml -Path $testFile
            $actual.small | Should -Be 42
            $actual.small | Should -BeOfType ([int])
            $actual.large | Should -Be 9223372036854775807
            $actual.negative | Should -Be -123
        }

        It "Preserves float types" {
            $testFile = Join-Path $testDir "floats.yaml"
            @"
pi: 3.14159
scientific: 1.23e-4
"@ | Set-Content -LiteralPath $testFile -NoNewline

            $actual = Import-Yaml -Path $testFile
            $actual.pi | Should -Be 3.14159
            $actual.pi | Should -BeOfType ([double])
            $actual.scientific | Should -Be 1.23e-4
        }
    }
}
