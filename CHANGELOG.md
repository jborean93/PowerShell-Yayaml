# Changelog for Yayaml

## v0.8.0 - 2026-07-10

+ Updated [YamlDotNet](https://github.com/aaubry/YamlDotNet) dependency to `18.1.0`
+ Move cmdlet and other PowerShell cmdlet related types from the namespace `Yayaml.Module` to `Yayaml`
  + This should have no impact to end users as `Yayaml.Module` was loaded in an ALC whereas now `Yayaml` is in the ALC
+ Added new cmdlets `Export-Yaml` and `Import-Yaml`
+ Removed stray `Console.WriteLine` in Span emitter left over from debugging

## v0.7.0 - 2025-09-12

+ Added the `Tag` property to the emitted `MapValue` and `SequenceValue` for the `-Parse*` APIs on a YAML schema

## v0.6.0 - 2025-03-13

+ Updated [YamlDotNet](https://github.com/aaubry/YamlDotNet) dependency to `16.3.0`
+ Raised minimum PowerShell 7 version to 7.4

## v0.5.0 - 2024-07-11

+ Updated [YamlDotNet](https://github.com/aaubry/YamlDotNet) dependency to `15.3.0`
+ Added the `-Stream` parameter to `ConvertTo-Yaml` that can serialize the input objects as they are received rather than as one big object at the end
+ Implement new emitter logic to skip the multiple processing passes done on the objects to be serialized
+ Add support for serializing values with a pre, inline, or post comment

## v0.4.0 - 2024-04-19

+ Updated [YamlDotNet](https://github.com/aaubry/YamlDotNet) dependency to `15.1.2`

## v0.3.0 - 2023-11-29

+ Updated [YamlDotNet](https://github.com/aaubry/YamlDotNet) dependency to `13.7.1`
+ Provide workaround when importing the module more than once
+ Add support for Windows PowerShell 5.1
  + There are no guarantees that YamlDotNet will be loadable in case of conflicts, use PowerShell 7 so an ALC can be used
+ Added `-EmitTransformer` to `New-YamlSchema` to provide a simpler way of transforming particular types or objects
  + This runs the ScriptBlock provided for every object that is being serialized allowing the caller to provide a "transformed" value for that object

## v0.2.1 - 2023-10-13

+ Support serializing dotnet properties that return a `Span<T>`, `ReadOnlySpan<T>`, `Memory<T>`, or `ReadOnlyMemory<T>`
  + These values will be copied to a temporary array of the type `T`
+ Treat any `IList<byte>` type, not just `byte[]`, as `!!binary` with the `Yaml11` schema

## v0.2.0 - 2023-09-26

+ Updated [YamlDotNet](https://github.com/aaubry/YamlDotNet) dependency to `13.4.0`

## v0.1.1 - 2023-08-03

+ Treat `IntPtr` values like other numeric types

## v0.1.0 - 2023-06-23

+ Initial version of the `Yayaml` module
