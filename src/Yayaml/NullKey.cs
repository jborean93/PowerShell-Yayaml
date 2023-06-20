using System;

namespace Yayaml;

public sealed class NullKey
{
    private static readonly Lazy<NullKey> lazy =
        new Lazy<NullKey>(() => new NullKey());

    public static NullKey Value { get { return lazy.Value; } }

    private NullKey()
    { }

    public override bool Equals(object? obj)
        => obj == null || obj is NullKey;

    public override int GetHashCode()
        => base.GetHashCode();
}
