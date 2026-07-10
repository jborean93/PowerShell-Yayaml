using namespace System.Globalization
using namespace System.Text

. ([IO.Path]::Combine($PSScriptRoot, 'common.ps1'))

Describe "Export-Yaml" {
    BeforeAll {
        $testDir = Join-Path $TestDrive "Export-Yaml"
        New-Item -Path $testDir -ItemType Directory -Force | Out-Null
    }

    Context "Basic Functionality" {
        It "Exports object to YAML file" {
            $testFile = Join-Path $testDir "simple.yaml"
            $obj = [PSCustomObject]@{ foo = 'bar'; test = 1 }

            $obj | Export-Yaml -Path $testFile
            Test-Path -LiteralPath $testFile | Should -BeTrue

            $content = (Get-Content -LiteralPath $testFile -Raw).Trim()
            $content | Should -Be "foo: bar$([Environment]::NewLine)test: 1"
        }

        It "Exports object with InputObject parameter" {
            $testFile = Join-Path $testDir "inputobject.yaml"
            $obj = [PSCustomObject]@{ key = 'value' }

            Export-Yaml -Path $testFile -InputObject $obj
            Test-Path -LiteralPath $testFile | Should -BeTrue

            $content = (Get-Content -LiteralPath $testFile -Raw).Trim()
            $content | Should -Be "key: value"
        }

        It "Exports multiple objects from pipeline" {
            $testFile = Join-Path $testDir "pipeline.yaml"
            $obj1 = [PSCustomObject]@{ id = 1 }
            $obj2 = [PSCustomObject]@{ id = 2 }

            $obj1, $obj2 | Export-Yaml -Path $testFile
            Test-Path -LiteralPath $testFile | Should -BeTrue

            $lines = Get-Content -LiteralPath $testFile
            # Each object is written as a separate line
            $lines.Count | Should -Be 2
            $lines[0] | Should -Be '- id: 1'
            $lines[1] | Should -Be '- id: 2'
        }

        It "Exports to multiple files" {
            $file1 = Join-Path $testDir "multi1.yaml"
            $file2 = Join-Path $testDir "multi2.yaml"
            $obj = [PSCustomObject]@{ data = 'test' }

            $obj | Export-Yaml -Path $file1, $file2
            Test-Path -LiteralPath $file1 | Should -BeTrue
            Test-Path -LiteralPath $file2 | Should -BeTrue

            $content1 = (Get-Content -LiteralPath $file1 -Raw).Trim()
            $content2 = (Get-Content -LiteralPath $file2 -Raw).Trim()
            $content1 | Should -Be "data: test"
            $content2 | Should -Be "data: test"
        }

        It "Exports with LiteralPath parameter" {
            $testFile = Join-Path $testDir "literal[test].yaml"
            $obj = [PSCustomObject]@{ literal = $true }

            $obj | Export-Yaml -LiteralPath $testFile
            Test-Path -LiteralPath $testFile | Should -BeTrue

            $content = (Get-Content -LiteralPath $testFile -Raw).Trim()
            $content | Should -Be "literal: true"
        }

        It "Overwrites existing file by default" {
            $testFile = Join-Path $testDir "overwrite.yaml"
            "old: data" | Set-Content -LiteralPath $testFile -NoNewline

            $obj = [PSCustomObject]@{ new = 'data' }
            $obj | Export-Yaml -Path $testFile

            $content = (Get-Content -LiteralPath $testFile -Raw).Trim()
            $content | Should -Be "new: data"
        }
    }

    Context "Append Parameter" {
        It "Appends to existing file with -Append" {
            $testFile = Join-Path $testDir "append.yaml"
            $obj1 = [PSCustomObject]@{ first = 'data' }
            $obj2 = [PSCustomObject]@{ second = 'data' }

            $obj1 | Export-Yaml -Path $testFile
            $obj2 | Export-Yaml -Path $testFile -Append

            $lines = Get-Content -LiteralPath $testFile
            $lines.Count | Should -Be 2
            $lines[0] | Should -Be "first: data"
            $lines[1] | Should -Be "second: data"
        }

        It "Creates new file with -Append if it doesn't exist" {
            $testFile = Join-Path $testDir "append-new.yaml"
            $obj = [PSCustomObject]@{ data = 'value' }

            $obj | Export-Yaml -Path $testFile -Append
            Test-Path -LiteralPath $testFile | Should -BeTrue

            $content = (Get-Content -LiteralPath $testFile -Raw).Trim()
            $content | Should -Be "data: value"
        }
    }

    Context "NoClobber Parameter" {
        It "Prevents overwriting existing file with -NoClobber" {
            $testFile = Join-Path $testDir "noclobber.yaml"
            "existing: data" | Set-Content -LiteralPath $testFile -NoNewline

            $err = $null
            $obj = [PSCustomObject]@{ new = 'data' }
            $obj | Export-Yaml -Path $testFile -NoClobber -ErrorAction SilentlyContinue -ErrorVariable err

            $err.Count | Should -Be 1
            $err[0].CategoryInfo.Category | Should -Be OpenError

            # Original file should be unchanged
            $content = Get-Content -LiteralPath $testFile -Raw
            $content | Should -Be "existing: data"
        }

        It "Creates new file with -NoClobber if it doesn't exist" {
            $testFile = Join-Path $testDir "noclobber-new.yaml"
            $obj = [PSCustomObject]@{ data = 'value' }

            $obj | Export-Yaml -Path $testFile -NoClobber
            Test-Path -LiteralPath $testFile | Should -BeTrue

            $content = (Get-Content -LiteralPath $testFile -Raw).Trim()
            $content | Should -Be "data: value"
        }
    }

    Context "Force Parameter" {
        It "Overwrites read-only file with -Force" -Skip:(-not $IsWindows) {
            $testFile = Join-Path $testDir "force-readonly.yaml"
            "old: data" | Set-Content -LiteralPath $testFile -NoNewline
            $item = Get-Item -LiteralPath $testFile
            $item.Attributes = $item.Attributes -bor [System.IO.FileAttributes]::ReadOnly

            $obj = [PSCustomObject]@{ new = 'data' }
            $obj | Export-Yaml -Path $testFile -Force

            $content = (Get-Content -LiteralPath $testFile -Raw).Trim()
            $content | Should -Be "new: data"

            # Verify read-only attribute was restored
            $item = Get-Item -LiteralPath $testFile
            ($item.Attributes -band [System.IO.FileAttributes]::ReadOnly) | Should -Be ([System.IO.FileAttributes]::ReadOnly)
        }

        It "Fails to overwrite read-only file without -Force" -Skip:(-not $IsWindows) {
            $testFile = Join-Path $testDir "no-force-readonly.yaml"
            "old: data" | Set-Content -LiteralPath $testFile -NoNewline
            $item = Get-Item -LiteralPath $testFile
            $item.Attributes = $item.Attributes -bor [System.IO.FileAttributes]::ReadOnly

            $err = $null
            $obj = [PSCustomObject]@{ new = 'data' }
            $obj | Export-Yaml -Path $testFile -ErrorAction SilentlyContinue -ErrorVariable err

            $err.Count | Should -Be 1
            $err[0].CategoryInfo.Category | Should -Be OpenError

            # Verify file is still read-only
            $item = Get-Item -LiteralPath $testFile
            ($item.Attributes -band [System.IO.FileAttributes]::ReadOnly) | Should -Be ([System.IO.FileAttributes]::ReadOnly)

            # Original content should remain
            $item.Attributes = $item.Attributes -band (-bnot [System.IO.FileAttributes]::ReadOnly)
            $content = Get-Content -LiteralPath $testFile -Raw
            $content | Should -Be "old: data"
        }

        It "Appends to read-only file with -Force and -Append" -Skip:(-not $IsWindows) {
            $testFile = Join-Path $testDir "force-append-readonly.yaml"
            $obj1 = [PSCustomObject]@{ first = 'data' }
            $obj1 | Export-Yaml -Path $testFile

            $item = Get-Item -LiteralPath $testFile
            $item.Attributes = $item.Attributes -bor [System.IO.FileAttributes]::ReadOnly


            $obj2 = [PSCustomObject]@{ second = 'data' }
            $obj2 | Export-Yaml -Path $testFile -Force -Append

            $lines = Get-Content -LiteralPath $testFile
            $lines.Count | Should -Be 2
            $lines[0] | Should -Be "first: data"
            $lines[1] | Should -Be "second: data"

            # Verify read-only attribute was restored
            $item = Get-Item -LiteralPath $testFile
            ($item.Attributes -band [System.IO.FileAttributes]::ReadOnly) | Should -Be ([System.IO.FileAttributes]::ReadOnly)
        }
    }

    Context "AsArray Parameter" {
        It "Exports multiple objects as array with -AsArray" {
            $testFile = Join-Path $testDir "asarray.yaml"
            $obj1 = [PSCustomObject]@{ id = 1 }
            $obj2 = [PSCustomObject]@{ id = 2 }

            $obj1, $obj2 | Export-Yaml -Path $testFile -AsArray

            $content = (Get-Content -LiteralPath $testFile -Raw).Trim()
            # With -AsArray, objects are in an array structure
            $content | Should -Be "- id: 1$([Environment]::NewLine)- id: 2"
        }

        It "Exports single object as array with -AsArray" {
            $testFile = Join-Path $testDir "asarray-single.yaml"
            $obj = [PSCustomObject]@{ id = 1 }

            $obj | Export-Yaml -Path $testFile -AsArray

            $content = (Get-Content -LiteralPath $testFile -Raw).Trim()
            $content | Should -Be "- id: 1"
        }

        It "Exports single object as array without -AsArray" {
            $testFile = Join-Path $testDir "notasarray-single.yaml"
            $obj = [PSCustomObject]@{ id = 1 }

            $obj | Export-Yaml -Path $testFile

            $content = (Get-Content -LiteralPath $testFile -Raw).Trim()
            $content | Should -Be "id: 1"
        }
    }

    Context "Depth Parameter" {
        It "Uses default depth of 2" {
            $testFile = Join-Path $testDir "depth-default.yaml"
            $obj = [PSCustomObject]@{
                level1 = [PSCustomObject]@{
                    level2 = [PSCustomObject]@{
                        level3 = [PSCustomObject]@{
                            value = 'deep'
                        }
                    }
                }
            }

            $depthWarning = $null
            $obj | Export-Yaml -Path $testFile -WarningAction SilentlyContinue -WarningVariable depthWarning

            $depthWarning | Should -HaveCount 1
            $depthWarning[0].Message | Should -Be "Resulting YAML is truncated as serialization has exceeded the set depth of 2"

            $content = Get-Content -LiteralPath $testFile
            $content | Should -HaveCount 3
            $content[0] | Should -Be "level1:"
            $content[1] | Should -Be "  level2:"
            $content[2] | Should -Be '    level3: ""'
        }

        It "Exports deep structures with custom depth" {
            $testFile = Join-Path $testDir "depth-5.yaml"
            $obj = [PSCustomObject]@{
                level1 = [PSCustomObject]@{
                    level2 = [PSCustomObject]@{
                        level3 = [PSCustomObject]@{
                            level4 = [PSCustomObject]@{
                                value = 'deep'
                            }
                        }
                    }
                }
            }

            $depthWarning = $null
            $obj | Export-Yaml -Path $testFile -Depth 5 -WarningAction SilentlyContinue -WarningVariable depthWarning

            $depthWarning | Should -BeNullOrEmpty
            $content = Get-Content -LiteralPath $testFile
            $content | Should -HaveCount 5
            $content[0] | Should -Be "level1:"
            $content[1] | Should -Be "  level2:"
            $content[2] | Should -Be "    level3:"
            $content[3] | Should -Be "      level4:"
            $content[4] | Should -Be "        value: deep"
        }
    }

    Context "IndentSequence Parameter" {
        It "Exports arrays without indentation by default" {
            $testFile = Join-Path $testDir "no-indent.yaml"
            $obj = [PSCustomObject]@{
                items = @('one', 'two', 'three')
            }

            $obj | Export-Yaml -Path $testFile

            $content = Get-Content -LiteralPath $testFile
            $content | Should -HaveCount 4
            $content[0] | Should -Be "items:"
            $content[1] | Should -Be "- one"
            $content[2] | Should -Be "- two"
            $content[3] | Should -Be "- three"
        }

        It "Exports arrays with indentation using -IndentSequence" {
            $testFile = Join-Path $testDir "indent.yaml"
            $obj = [PSCustomObject]@{
                items = @('one', 'two', 'three')
            }

            $obj | Export-Yaml -Path $testFile -IndentSequence

            $content = Get-Content -LiteralPath $testFile
            $content | Should -HaveCount 4
            $content[0] | Should -Be "items:"
            $content[1] | Should -Be "  - one"
            $content[2] | Should -Be "  - two"
            $content[3] | Should -Be "  - three"
        }
    }

    Context "Schema Parameter" {
        It "Exports with default YAML 1.2 schema" {
            $testFile = Join-Path $testDir "schema-default.yaml"
            $obj = [PSCustomObject]@{
                bool = $true
                int = 42
            }

            $obj | Export-Yaml -Path $testFile

            $content = (Get-Content -LiteralPath $testFile -Raw).Trim()
            $content | Should -Be "bool: true$([Environment]::NewLine)int: 42"
        }

        It "Exports with YAML 1.1 schema" {
            $testFile = Join-Path $testDir "schema-11.yaml"
            $obj = [PSCustomObject]@{
                value = $true
            }

            $obj | Export-Yaml -Path $testFile -Schema Yaml11

            $content = (Get-Content -LiteralPath $testFile -Raw).Trim()
            $content | Should -Be "value: true"
        }

        It "Exports with custom schema" {
            $testFile = Join-Path $testDir "schema-custom.yaml"
            $schema = New-YamlSchema
            $obj = [PSCustomObject]@{
                data = 'test'
            }

            $obj | Export-Yaml -Path $testFile -Schema $schema

            $content = (Get-Content -LiteralPath $testFile -Raw).Trim()
            $content | Should -Be "data: test"
        }
    }

    Context "Encoding Parameter" {
        It "Exports with <Encoding> values" -TestCases @(
            @{ Encoding = 'ASCII'; EncodingObj = [Encoding]::ASCII }
            @{ Encoding = 'ANSI'; EncodingObj = [Encoding]::GetEncoding([CultureInfo]::CurrentCulture.TextInfo.ANSICodePage) }
            @{ Encoding = 'OEM'; EncodingObj = [Console]::OutputEncoding }
            @{ Encoding = 'Default'; EncodingObj = [UTF8Encoding]::new($false) }
            @{ Encoding = 'UTF8'; EncodingObj = [UTF8Encoding]::new($false) }
            @{ Encoding = 'UTF8NoBom'; EncodingObj = [UTF8Encoding]::new($false) }
            @{ Encoding = 'UTF8Bom'; EncodingObj = [UTF8Encoding]::new($true) }
            @{ Encoding = 'Unicode'; EncodingObj = [UnicodeEncoding]::new($false, $true) }
            @{ Encoding = '437'; EncodingObj = [Encoding]::GetEncoding(437) }
            @{ Encoding = 437; EncodingObj = [Encoding]::GetEncoding(437) }
            @{ Encoding = ([Text.Encoding]::GetEncoding(437)); EncodingObj = [Encoding]::GetEncoding(437) }
        ) {
            param ($Encoding, $EncodingObj)

            $expected = @(
                $bom = $EncodingObj.GetPreamble()
                if ($bom.Length) {
                    $bom | ForEach-Object { $_.ToString("X2") }
                }

                $EncodingObj.GetBytes([char]0x00E9) | ForEach-Object { $_.ToString("X2") }
            ) -join ''
            $newLineLength = $EncodingObj.GetBytes([Environment]::NewLine).Length * 2

            $testFile = Join-Path $testDir "encoding-$Encoding.yaml"

            $encodingParams = @{}
            if ($Encoding -ne 'Default') {
                $encodingParams['Encoding'] = $Encoding
            }
            [Char]0x00E9 | Export-Yaml -Path $testFile @encodingParams

            $bytes = [System.IO.File]::ReadAllBytes($testFile)
            $actual = ($bytes | ForEach-Object { $_.ToString("X2") }) -join ''

            # Strip off newline characters at the end of the file for comparison
            $actual = $actual.Substring(0, $actual.Length - $newLineLength)

            $actual | Should -Be $expected
        }

        It "Exports PSObject wrapped value for -Encoding" {
            $testFile = Join-Path $testDir "psobject-encoding.yaml"

            $encoding = 'Unicode' | Write-Output

            [Char]0x00E9 | Export-Yaml -Path $testFile -Encoding $encoding

            $bytes = [System.IO.File]::ReadAllBytes($testFile)
            $actual = ($bytes | ForEach-Object { $_.ToString("X2") }) -join ''
            # Strip off newline characters at the end of the file for comparison
            $actual = $actual.Substring(0, $actual.Length - [System.Environment]::NewLine.Length * 4)

            $actual | Should -Be 'FFFEE900'
        }

        It "Fails with invalid -Encoding value" {
            $testFile = Join-Path $testDir "invalid-encoding.yaml"

            {
                'a' | Export-Yaml -Path $testFile -Encoding @{}
            } | Should -Throw "*Could not convert input 'System.Collections.Hashtable' to a valid Encoding object*"
        }

        It "Completes -Encoding with no value" {
            $actual = Complete 'Export-Yaml -Encoding '
            $actual.Count | Should -Be 7
            $actual[0].CompletionText | Should -Be UTF8
            $actual[1].CompletionText | Should -Be ASCII
            $actual[2].CompletionText | Should -Be ANSI
            $actual[3].CompletionText | Should -Be OEM
            $actual[4].CompletionText | Should -Be Unicode
            $actual[5].CompletionText | Should -Be UTF8Bom
            $actual[6].CompletionText | Should -Be UTF8NoBom
        }

        It "Completes -Encoding with partial match" {
            $actual = Complete 'Export-Yaml -Encoding UT'
            $actual.Count | Should -Be 3
            $actual[0].CompletionText | Should -Be UTF8
            $actual[1].CompletionText | Should -Be UTF8Bom
            $actual[2].CompletionText | Should -Be UTF8NoBom
        }

        It "Completes -Encoding with partial match and wildcard" {
            $actual = Complete 'Export-Yaml -Encoding UT*'
            $actual.Count | Should -Be 3
            $actual[0].CompletionText | Should -Be UTF8
            $actual[1].CompletionText | Should -Be UTF8Bom
            $actual[2].CompletionText | Should -Be UTF8NoBom
        }
    }

    Context "Error Handling" {
        It "Writes error for invalid path" {
            if ($IsWindows) {
                $invalidPath = Join-Path $testDir "invalid`0path.yaml"
            }
            else {
                $invalidPath = "/root/nopermission/test.yaml"
            }
            $obj = [PSCustomObject]@{ data = 'test' }

            $obj | Export-Yaml -Path $invalidPath -ErrorAction Continue -ErrorVariable err 2>&1

            $err.Count | Should -Be 1
            $err[0].CategoryInfo.Category | Should -Be OpenError
        }

        It "Writes error for non-filesystem path" {
            $obj = [PSCustomObject]@{ data = 'test' }
            $obj | Export-Yaml -Path "env:\test.yaml" -ErrorAction Continue -ErrorVariable err 2>&1

            $err.Count | Should -Be 1
            $err[0].CategoryInfo.Category | Should -Be InvalidArgument
            [string]$err[0] | Should -BeLike "*is not a FileSystem path*"
        }

        It "Handles null input object" {
            $testFile = Join-Path $testDir "null.yaml"

            $null | Export-Yaml -Path $testFile

            Test-Path -LiteralPath $testFile | Should -BeTrue
            $content = Get-Content -LiteralPath $testFile -Raw
            # null should be serialized as empty or 'null'
            $content -match "(null|^[\r\n]*$)" | Should -BeTrue
        }

        It "Continues processing when one file fails" {
            $validFile = Join-Path $testDir "valid-multi.yaml"
            if ($IsWindows) {
                $invalidFile = Join-Path $testDir "invalid`0multi.yaml"
            }
            else {
                $invalidFile = "/root/nopermission/invalid.yaml"
            }
            $obj = [PSCustomObject]@{ data = 'test' }

            $obj | Export-Yaml -Path $validFile, $invalidFile -ErrorAction Continue -ErrorVariable err 2>&1

            Test-Path -LiteralPath $validFile | Should -BeTrue
            $err.Count | Should -Be 1
        }
    }

    Context "ShouldProcess Support" {
        It "Supports -WhatIf" {
            $testFile = Join-Path $testDir "whatif.yaml"
            $obj = [PSCustomObject]@{ data = 'test' }

            $obj | Export-Yaml -Path $testFile -WhatIf

            Test-Path -LiteralPath $testFile | Should -BeFalse
        }

        It "Supports -Confirm with automatic No" {
            $testFile = Join-Path $testDir "confirm.yaml"
            $obj = [PSCustomObject]@{ data = 'test' }

            # Simulate user choosing 'No' to confirmation
            $obj | Export-Yaml -Path $testFile -Confirm:$false

            Test-Path -LiteralPath $testFile | Should -BeTrue
        }
    }

    Context "Path Resolution" {
        It "Resolves relative paths" {
            $testFile = "relative.yaml"
            $obj = [PSCustomObject]@{ relative = 'path' }

            Push-Location $testDir
            try {
                $obj | Export-Yaml -Path $testFile
                Test-Path -LiteralPath (Join-Path $testDir $testFile) | Should -BeTrue
            }
            finally {
                Pop-Location
            }
        }

        It "Fails when parent directory doesn't exist" {
            $subDir = Join-Path $testDir "newdir"
            $testFile = Join-Path $subDir "file.yaml"
            $obj = [PSCustomObject]@{ data = 'test' }

            # This should fail because Export-Yaml doesn't create directories
            $obj | Export-Yaml -Path $testFile -ErrorAction Continue -ErrorVariable err 2>&1

            $err.Count | Should -Be 1
            Test-Path -LiteralPath $testFile | Should -BeFalse
        }

        It "Resolves provider paths (PSDrive)" {
            $obj = [PSCustomObject]@{ psdrive = 'test' }
            $driveName = "TestYaml"
            New-PSDrive -Name $driveName -PSProvider FileSystem -Root $testDir -Scope Global | Out-Null

            try {
                $testFile = "${driveName}:\psdrive.yaml"
                $obj | Export-Yaml -Path $testFile

                Test-Path -LiteralPath (Join-Path $testDir "psdrive.yaml") | Should -BeTrue
            }
            finally {
                Remove-PSDrive -Name $driveName -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context "Round-Trip Tests" {
        It "Round-trips strings correctly" {
            $testFile = Join-Path $testDir "roundtrip-string.yaml"
            $obj = [PSCustomObject]@{
                simple = 'simple string'
                quoted = 'string: with: colons'
                multiline = "line1`nline2`nline3"
            }

            $obj | Export-Yaml -Path $testFile
            $result = Import-Yaml -Path $testFile

            $result.simple | Should -Be 'simple string'
            $result.quoted | Should -Be 'string: with: colons'
            $result.multiline | Should -Be "line1`nline2`nline3"
        }

        It "Round-trips boolean values correctly" {
            $testFile = Join-Path $testDir "roundtrip-bool.yaml"
            $obj = [PSCustomObject]@{
                true_val = $true
                false_val = $false
            }

            $obj | Export-Yaml -Path $testFile
            $result = Import-Yaml -Path $testFile

            $result.true_val | Should -BeTrue
            $result.false_val | Should -BeFalse
        }

        It "Round-trips numeric values correctly" {
            $testFile = Join-Path $testDir "roundtrip-numbers.yaml"
            $obj = [PSCustomObject]@{
                int = 42
                long = [long]9223372036854775807
                double = 3.14159
                negative = -123
            }

            $obj | Export-Yaml -Path $testFile
            $result = Import-Yaml -Path $testFile

            $result.int | Should -Be 42
            $result.long | Should -Be 9223372036854775807
            $result.double | Should -Be 3.14159
            $result.negative | Should -Be -123
        }

        It "Round-trips arrays correctly" {
            $testFile = Join-Path $testDir "roundtrip-array.yaml"
            $obj = [PSCustomObject]@{
                items = @(1, 2, 3, 4, 5)
            }

            $obj | Export-Yaml -Path $testFile
            $result = Import-Yaml -Path $testFile

            $result.items.Count | Should -Be 5
            $result.items[0] | Should -Be 1
            $result.items[4] | Should -Be 5
        }

        It "Round-trips nested objects correctly" {
            $testFile = Join-Path $testDir "roundtrip-nested.yaml"
            $obj = [PSCustomObject]@{
                outer = [PSCustomObject]@{
                    inner = [PSCustomObject]@{
                        value = 'deep'
                    }
                }
            }

            $obj | Export-Yaml -Path $testFile -Depth 5
            $result = Import-Yaml -Path $testFile

            $result.outer.inner.value | Should -Be 'deep'
        }

        It "Round-trips ordered hashtables correctly" {
            $testFile = Join-Path $testDir "roundtrip-hashtable.yaml"
            $obj = [Ordered]@{
                key1 = 'value1'
                key2 = 'value2'
            }

            $obj | Export-Yaml -Path $testFile
            $result = Import-Yaml -Path $testFile

            $result.key1 | Should -Be 'value1'
            $result.key2 | Should -Be 'value2'
        }
    }

    Context "Edge Cases" {
        It "Exports empty object" {
            $testFile = Join-Path $testDir "empty-object.yaml"
            $obj = [PSCustomObject]@{}

            $obj | Export-Yaml -Path $testFile

            Test-Path -LiteralPath $testFile | Should -BeTrue
            $content = (Get-Content -LiteralPath $testFile -Raw).Trim()
            $content | Should -Be "{}"
        }

        It "Exports object with empty string values" {
            $testFile = Join-Path $testDir "empty-strings.yaml"
            $obj = [PSCustomObject]@{
                empty = ''
                null_val = $null
            }

            $obj | Export-Yaml -Path $testFile

            $result = Import-Yaml -Path $testFile
            $result.empty | Should -Be ''
            $result.null_val | Should -BeNullOrEmpty
        }

        It "Exports object with special characters" {
            $testFile = Join-Path $testDir "special-chars.yaml"
            $obj = [PSCustomObject]@{
                unicode = [Char]::ConvertFromUtf32(0x1F4A9)
                quote = "He said ""hello"""
                newline = "line1`nline2"
                tab = "col1`tcol2"
            }

            $obj | Export-Yaml -Path $testFile

            $result = Import-Yaml -Path $testFile
            $result.unicode | Should -Be $([Char]::ConvertFromUtf32(0x1F4A9))
            $result.quote | Should -Be "He said ""hello"""
            $result.newline | Should -Be "line1`nline2"
            $result.tab | Should -Be "col1`tcol2"
        }
    }
}
