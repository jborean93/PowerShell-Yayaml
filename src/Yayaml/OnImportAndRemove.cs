using System;
using System.IO;
using System.Management.Automation;
using System.Reflection;
using System.Runtime.Loader;

namespace Yayaml;

internal class YayamlResolver : AssemblyLoadContext
{
    private readonly string _assemblyDir;

    public YayamlResolver(string assemblyDir)
    {
        _assemblyDir = assemblyDir;
    }

    protected override Assembly? Load(AssemblyName assemblyName)
    {
        string asmPath = Path.Join(_assemblyDir, $"{assemblyName.Name}.dll");
        if (File.Exists(asmPath))
        {
            return LoadFromAssemblyPath(asmPath);
        }
        else
        {
            return null;
        }
    }
}

public class OnModuleImportAndRemove : IModuleAssemblyInitializer, IModuleAssemblyCleanup
{
    private static readonly string _assemblyDir = Path.GetDirectoryName(
        typeof(YayamlResolver).Assembly.Location)!;

    private static readonly YayamlResolver _alc = new YayamlResolver(_assemblyDir);

    public void OnImport()
    {
        AssemblyLoadContext.Default.Resolving += ResolveAlc;
    }

    public void OnRemove(PSModuleInfo module)
    {
        AssemblyLoadContext.Default.Resolving -= ResolveAlc;
    }

    private static Assembly? ResolveAlc(AssemblyLoadContext defaultAlc, AssemblyName assemblyToResolve)
    {
        string asmPath = Path.Join(_assemblyDir, $"{assemblyToResolve.Name}.dll");
        if (IsSatisfyingAssembly(assemblyToResolve, asmPath))
        {
            return _alc.LoadFromAssemblyName(assemblyToResolve);
        }
        else
        {
            return null;
        }
    }

    private static bool IsSatisfyingAssembly(AssemblyName requiredAssemblyName, string assemblyPath)
    {
        if (requiredAssemblyName.Name != "Yayaml.Shared" || !File.Exists(assemblyPath))
        {
            return false;
        }

        AssemblyName asmToLoadName = AssemblyName.GetAssemblyName(assemblyPath);

        return string.Equals(asmToLoadName.Name, requiredAssemblyName.Name, StringComparison.OrdinalIgnoreCase)
            && asmToLoadName.Version >= requiredAssemblyName.Version;
    }
}
