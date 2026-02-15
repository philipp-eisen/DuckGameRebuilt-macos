using Mono.Cecil;

if (args.Length != 1)
{
    Console.Error.WriteLine("Usage: SteamworksPatcher <path-to-Steamworks.NET.dll>");
    return 1;
}

string assemblyPath = args[0];
if (!File.Exists(assemblyPath))
{
    Console.Error.WriteLine("File not found: " + assemblyPath);
    return 1;
}

string patchedPath = assemblyPath + ".patched";

var resolver = new DefaultAssemblyResolver();
resolver.AddSearchDirectory(Path.GetDirectoryName(assemblyPath)!);

var parameters = new ReaderParameters
{
    AssemblyResolver = resolver,
    ReadWrite = false,
    InMemory = true
};

var assembly = AssemblyDefinition.ReadAssembly(assemblyPath, parameters);
assembly.MainModule.Architecture = TargetArchitecture.I386;
assembly.MainModule.Attributes &= ~ModuleAttributes.Required32Bit;
assembly.MainModule.Attributes &= ~ModuleAttributes.Preferred32Bit;
assembly.Write(patchedPath);

File.Copy(patchedPath, assemblyPath, true);
File.Delete(patchedPath);

Console.WriteLine("Patched Steamworks.NET to AnyCPU: " + assemblyPath);
return 0;
