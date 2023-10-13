using System;
using System.Collections.Generic;
using System.Reflection;
using System.Reflection.Emit;

namespace Yayaml.Module;

internal static class ReflectionHelper
{
    private static ModuleBuilder? _builder;
    private static Dictionary<string, MethodInfo> _spanDelegates = new();

    private static ModuleBuilder Module
    {
        get
        {
            if (_builder == null)
            {
                const string assemblyName = "Yayaml.Module.Dynamic";
                AssemblyBuilder builder = AssemblyBuilder.DefineDynamicAssembly(
                    new(assemblyName),
                    AssemblyBuilderAccess.Run);

                _builder = builder.DefineDynamicModule(assemblyName);
            }

            return _builder;
        }
    }

    /// <summary>
    /// You cannot use reflection to get a Span value, this will define a
    /// dynamic method to get the span property and call ToArray() on the value
    /// to convert the span to an array for serialization.
    /// </summary>
    /// <param name="obj">The object the property is on.</param>
    /// <param name="spanProp">The property to get the span value for.</param>
    /// <returns>The span as an array.</returns>
    public static Array SpanToArray(object obj, PropertyInfo spanProp)
    {
        Type objType = obj.GetType();
        string delegateId = $"{objType.FullName}{spanProp.Name}_Get";
        Console.WriteLine(delegateId);

        MethodInfo? toArrayMeth;
        if (!_spanDelegates.TryGetValue(delegateId, out toArrayMeth))
        {
            Type spanType = spanProp.PropertyType;
            MethodInfo spanToArrayMeth = spanType.GetMethod(
                "ToArray",
                BindingFlags.Public | BindingFlags.Instance,
                Array.Empty<Type>()
            )!;

            const string invokeMethName = "Invoke";
            TypeBuilder tb = Module.DefineType(
                delegateId,
                TypeAttributes.NotPublic,
                null
            );
            MethodBuilder mb = tb.DefineMethod(
                invokeMethName,
                MethodAttributes.Static | MethodAttributes.Private,
                CallingConventions.Standard,
                typeof(Array),
                new[] { objType }
            );
            mb.DefineParameter(0, ParameterAttributes.None, "arg0");
            mb.DefineParameter(1, ParameterAttributes.None, "obj");

            ILGenerator il = mb.GetILGenerator();
            LocalBuilder spanLocal = il.DeclareLocal(spanType);
            il.Emit(OpCodes.Ldarg_0);
            il.Emit(OpCodes.Callvirt, spanProp.GetGetMethod()!);
            il.Emit(OpCodes.Stloc, spanLocal);
            il.Emit(OpCodes.Ldloca, spanLocal);
            il.Emit(OpCodes.Call, spanToArrayMeth);
            il.Emit(OpCodes.Ret);

            Type dynamicType = tb.CreateType()!;
            toArrayMeth = dynamicType.GetMethod(
                invokeMethName,
                BindingFlags.NonPublic | BindingFlags.Static)!;
            _spanDelegates[delegateId] = toArrayMeth;
        }

        return (Array)toArrayMeth.Invoke(null, new[] { obj })!;
    }
}
