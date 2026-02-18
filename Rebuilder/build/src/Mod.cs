using BsDiff;
using System;
using System.IO;
using System.Reflection;
using System.Diagnostics;

[assembly: AssemblyTitle("Duck Game Rebuilt")]
[assembly: AssemblyCompany("DGR Team")]
[assembly: AssemblyDescription("An installer and manager mod for Duck Game Rebuilt")]
[assembly: AssemblyVersion("1.0.0")]

namespace DuckGame.Cobalt
{
    public sealed class Mod : ClientMod
    {
        public static bool OnDGR;
        
        protected override void OnPreInitialize()
        {
            _properties.Set("isDgrMod", true);
            
            OnDGR = IsOnDGR();
            alreadyPatched = File.Exists(Path.GetDirectoryName(typeof(ItemBox).Assembly.Location) + "/rebuilt.quack");

            if (!OnDGR && !alreadyPatched)
            {
                AppDomain.CurrentDomain.AssemblyResolve += OnCurrentDomainOnAssemblyResolve;
                
                PatchForDGRQuickload();
                SaveVanillaPath();
                RestartToDGR();
            }
            
            base.OnPreInitialize();
        }
        public bool alreadyPatched;
        protected override void OnPostInitialize()
        {
            if (!OnDGR && alreadyPatched)
            {
                AppDomain.CurrentDomain.AssemblyResolve += OnCurrentDomainOnAssemblyResolve;

                PatchForDGRQuickload();
                SaveVanillaPath();
                RestartToDGR();
            }
            base.OnPostInitialize();
        }
        private static bool IsOnDGR()
        {
            // dan will probably kill me for this ~Firebreak
            return typeof(Program).GetField("CURRENT_VERSION_ID", BindingFlags.Public | BindingFlags.Static) is { IsLiteral: true, IsInitOnly: false };
        }

        private string ModDirectoryPath
        {
            get
            {
                if (configuration == null || string.IsNullOrWhiteSpace(configuration.directory))
                    throw new InvalidOperationException("Mod configuration directory is unavailable.");
                return configuration.directory;
            }
        }

        private string DGRDirectoryPath => Path.Combine(ModDirectoryPath, "dgr");
        private string DGRFilePath
        {
            get
            {
                string nativePath = Path.Combine(DGRDirectoryPath, "DuckGame");
                if (File.Exists(nativePath))
                    return nativePath;

                string scriptPath = Path.Combine(DGRDirectoryPath, "DuckGame.sh");
                if (File.Exists(scriptPath))
                    return scriptPath;

                string legacyPath = Path.Combine(DGRDirectoryPath, "DuckGame.exe");
                if (File.Exists(legacyPath))
                    return legacyPath;

                throw new FileNotFoundException("Could not find a DGR executable in the mod dgr folder.", DGRDirectoryPath);
            }
        }

        private string PatchFilePath => Path.Combine(ModDirectoryPath, "patch", "quickload.patch");
        private string BsDiffFilePath => Path.Combine(ModDirectoryPath, "patch", "BsDiff.dll");
        private string SharpZipLibFilePath => Path.Combine(ModDirectoryPath, "patch", "ICSharpCode.SharpZipLib.dll");

        private void RestartToDGR()
        {
            string dgrPath = DGRFilePath;
            string fromArg = " -from \"" + ModDirectoryPath + "\"";
            string baseArgs = (Program.commandLine ?? string.Empty) + fromArg;

            ProcessStartInfo startInfo = new ProcessStartInfo();
            if (dgrPath.EndsWith(".sh", StringComparison.OrdinalIgnoreCase))
            {
                startInfo.FileName = "/bin/bash";
                startInfo.Arguments = "\"" + dgrPath + "\" " + baseArgs;
            }
            else
            {
                startInfo.FileName = dgrPath;
                startInfo.Arguments = baseArgs;
            }

            Process.Start(startInfo);
            Process.GetCurrentProcess().Kill();
        }

        private void SaveVanillaPath()
        {
            string vanillaPath = Path.Combine(DuckFile.saveDirectory, "vanilla_dg.path");
            File.WriteAllText(vanillaPath, typeof(ItemBox).Assembly.Location);
        }

        // assuming this isn't already-patched dg...
        private void PatchForDGRQuickload()
        {
            string gamePath = typeof(ItemBox).Assembly.Location;
            if (string.IsNullOrWhiteSpace(gamePath))
                throw new InvalidOperationException("Could not resolve current Duck Game assembly location.");

            string root = Path.GetDirectoryName(gamePath);
            if (string.IsNullOrWhiteSpace(root))
                throw new InvalidOperationException("Could not resolve current Duck Game directory.");

            string tempGamePath = gamePath + ".tmp";

            // generate files
            if (File.Exists(tempGamePath))
                File.Delete(tempGamePath);
            File.Move(gamePath, tempGamePath);

            using FileStream vanilla = File.OpenRead(tempGamePath);
            using FileStream patched = File.Create(gamePath);

            try
            {
                BinaryPatch.Apply(vanilla, () => File.OpenRead(PatchFilePath), patched);
            }
            catch
            {
                // unfuck stuff in case it crashes
                vanilla.Close();
                patched.Close();
                
                File.Delete(gamePath);
                File.Move(tempGamePath, gamePath);
                
                throw;
            }

            // indicator for DGR quickloading
            File.WriteAllLines(root + "/rebuilt.quack", new[]
            {
                DGRFilePath,
                
                // WHY WAS THIS INTERNAL AND NOT PUBLIC, PARIL ??!
                (string) typeof(ModLoader).GetProperty("modConfigFile", BindingFlags.Static | BindingFlags.NonPublic)!.GetValue(null),
                
                configuration.uniqueID
            });
        }

        private Assembly OnCurrentDomainOnAssemblyResolve(object sender, ResolveEventArgs args)
        {
            if (args.Name.StartsWith("ICSharpCode.SharpZipLib"))
            {
                return Assembly.LoadFile(SharpZipLibFilePath);
            }
            else if (args.Name.StartsWith("BsDiff"))
            {
                return Assembly.LoadFile(BsDiffFilePath);
            }

            return null;
        }
    }
}
