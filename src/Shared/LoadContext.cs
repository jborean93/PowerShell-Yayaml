using System;
using System.Reflection;

namespace Yayaml.Shared;

public class LoadContext
{
    // private static LoadContext? s_instance;

    // private LoadContext(string mainModulePathAssemblyPath)
    // {
    //     _thisAssembly = typeof(Module1LoadContext).Assembly;
    //     _thisAssemblyName = _thisAssembly.GetName();

    //     Resolving += (AssemblyLoadContext _, AssemblyName target) =>
    //     {
    //         if (_thisAssemblyName == target)
    //         {
    //             return _thisAssembly;
    //         }

    //         return Load(target);
    //     };

    //     _moduleAssembly = LoadFromAssemblyPath(mainModulePathAssemblyPath);
    // }

    // public static Assembly Initialize()
    // {
    //     YayamlLoadContext? instance = s_instance;
    //     if (instance is not null)
    //     {
    //         return instance._moduleAssembly;
    //     }

    //     lock (s_sync)
    //     {
    //         if (s_instance is not null)
    //         {
    //             return s_instance._moduleAssembly;
    //         }
    //         s_instance = new YayamlLoadContext(mainModulePathAssemblyPath);
    //         return s_instance._moduleAssembly;

    //     }
    // }
}
