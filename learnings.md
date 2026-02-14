# net8 osx-arm64 migration learnings

## 2026-02-15

- The main game project is legacy .NET Framework 4.8 and non-SDK style (`DuckGame/DuckGame.csproj`), so `dotnet publish -r osx-arm64` cannot be done directly without a parallel SDK-style project or full in-place migration.
- Startup currently routes through `DGWindows.WindowsPlatformStartup`, which is Windows-specific and uses Win32 APIs.
- Boot-critical runtime paths use `System.Drawing`:
  - `DuckGame/src/MonoTime/Content/TextureConverter.cs`
  - `DuckGame/src/MonoTime/Render/1Windows_Font.cs`
- There are broad Windows-only imports in the game code (`System.Windows.Forms`, `System.Windows.*`, `System.Web`) that need a compatibility pass for net8.
- Existing non-Windows flow in repo is Mono/msbuild-based and copies `deps/*` ad hoc after build; this is not a RID-aware publish flow.
- Steam is intentionally excluded in phase 1 per requirement.
- Environment tooling constraint discovered during execution:
  - `dotnet` is not installed (`dotnet: command not found`)
  - `msbuild` is not installed
  - `mono` is installed
- A parallel net8 project lane is now in-repo:
  - `DuckGame/DuckGame.Net8.csproj`
  - `Steam/Steam.Net8.csproj`
- Compile-compatibility scaffolding added for net8:
  - `DuckGame/src/Compat/Net8/SystemWindowsFormsCompat.cs`
  - `DuckGame/src/Compat/Net8/SystemNamespaceCompat.cs`
  - `DuckGame/src/Platform/WindowsPlatformStartup.Net8.cs`
- Runtime compatibility changes implemented:
  - `Program.cs` now has `NO_STEAM` guarded startup and crash-loop steam calls
  - CrashWindow launch now routes through a Windows-guarded helper
  - net8 fallback font context added (`FontGDIContext.Net8.cs`)
  - net8 texture conversion implemented via ImageSharp (`TextureConverter.Net8.cs`)
- Publish scaffolding implemented:
  - `scripts/publish-macos-arm64.sh`
  - `DuckGame/build/native/osx-arm64/README.md`
  - `docs/migration/net8-macos-phase1.md`
