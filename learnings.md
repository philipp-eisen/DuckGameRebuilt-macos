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
