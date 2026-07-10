using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Management.Automation;
using Microsoft.PowerShell.Commands;

namespace Yayaml;

public static class PathHelper
{
    internal static IEnumerable<string> GetResolvedPaths(
        PSCmdlet cmdlet,
        string[] paths,
        bool expandWildcards,
        bool mustExist = true)
    {
        foreach ((string path, ProviderInfo provider) in NormalizePaths(cmdlet, paths, expandWildcards, mustExist))
        {
            if (provider.ImplementingType != typeof(FileSystemProvider))
            {
                ErrorRecord err = new(
                    new ArgumentException($"The resolved path '{path}' is not a FileSystem path but {provider.Name}."),
                    "PathNotFileSystem",
                    ErrorCategory.InvalidArgument,
                    path);
                cmdlet.WriteError(err);
                continue;
            }

            yield return path;
        }
    }

    private static IEnumerable<(string Path, ProviderInfo Provider)> NormalizePaths(
        PSCmdlet cmdlet,
        string[] paths,
        bool expandWildcards,
        bool mustExist)
    {
        if (expandWildcards)
        {
            foreach (string p in paths)
            {
                Collection<string>? resolvedPaths = null;
                ProviderInfo? provider = null;
                bool fallbackToLiteral = false;

                try
                {
                    resolvedPaths = cmdlet.GetResolvedProviderPathFromPSPath(p, out provider);
                }
                catch (ItemNotFoundException e)
                {
                    // If the path doesn't exist and doesn't contain wildcards and mustExist is false,
                    // treat it as a literal path (for output scenarios like Export-Yaml)
                    if (!mustExist && !WildcardPattern.ContainsWildcardCharacters(p))
                    {
                        fallbackToLiteral = true;
                    }
                    else
                    {
                        ErrorRecord err = new(
                            e,
                            "FileNotFound",
                            ErrorCategory.ObjectNotFound,
                            p);
                        cmdlet.WriteError(err);
                        continue;
                    }
                }

                if (fallbackToLiteral)
                {
                    string resolvedPath = cmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
                        p, out provider, out var _);
                    yield return (resolvedPath, provider!);
                }
                else
                {
                    foreach (string resolvedPath in resolvedPaths!)
                    {
                        yield return (resolvedPath, provider!);
                    }
                }
            }
        }
        else
        {
            foreach (string p in paths)
            {
                string resolvedPath = cmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
                    p, out var provider, out var _);
                yield return (resolvedPath, provider);
            }
        }
    }
}
