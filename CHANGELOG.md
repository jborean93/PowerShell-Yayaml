# Changelog for Yayaml

## v0.2.1 - 2023-10-13

+ Support serializating dotnet properties that return a `Span<T>`, `ReadOnlySpan<T>`, `Memory<T>`, or `ReadOnlyMemory<T>`
  + These values will be copied to a temporary array of the type `T`
+ Treat any `IList<byte>` type, not just `byte[]`, as `!!binary` with the `Yaml11` schema

## v0.2.0 - 2023-09-26

+ Updated [YamlDotNet](https://github.com/aaubry/YamlDotNet) dependency to `13.4.0`

## v0.1.1 - 2023-08-03

+ Treat `IntPtr` values like other numeric types

## v0.1.0 - 2023-06-23

+ Initial version of the `Yayaml` module
