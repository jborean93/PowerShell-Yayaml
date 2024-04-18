# Changelog for Yayaml

## v0.4.0 - 2023-04-19

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
