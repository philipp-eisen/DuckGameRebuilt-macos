# net8 osx-arm64 migration progress

## Status legend
- pending
- in_progress
- done
- blocked

## Phase checklist

- [done] Phase 0: baseline and tracking scaffolding
  - [done] Plan approved
  - [done] tracking files created (`progress.md`, `learnings.md`, `next-steps.md`)
  - [done] checkpoint commit created

- [done] Phase 1: add parallel SDK-style net8 build lane
  - [done] `DuckGame/DuckGame.Net8.csproj` added
  - [done] `Steam/Steam.Net8.csproj` added
  - [blocked] local restore/build verification (no `dotnet` SDK in environment)

- [in_progress] Phase 2: compile-compatibility pass
  - [done] added net8 compat shims for `System.Windows.Forms` and missing namespaces
  - [done] added net8 startup stub for `DGWindows.WindowsPlatformStartup`
  - [blocked] compile verification (no `dotnet` SDK in environment)

- [in_progress] Phase 3: runtime boot pass (no steam)
  - [done] added `NO_STEAM` guards in `Program.cs`
  - [done] added non-Windows crash-window guard path
  - [done] added net8 font fallback (`FontGDIContext.Net8.cs`)
  - [done] added net8 texture conversion path (`TextureConverter.Net8.cs`)
  - [blocked] runtime verification (no `dotnet` SDK in environment)

- [in_progress] Phase 4: publish packaging for `osx-arm64`
  - [done] publish script added (`scripts/publish-macos-arm64.sh`)
  - [done] native asset staging path added (`DuckGame/build/native/osx-arm64`)
  - [done] migration docs added (`docs/migration/net8-macos-phase1.md`)
  - [blocked] publish verification (no `dotnet` SDK in environment)

- [pending] Phase 5: stabilization and final verification

## Verification log
- attempted: `dotnet restore/build` for net8 lane -> failed: `dotnet: command not found`
- tool availability check: `dotnet` unavailable, `msbuild` unavailable, `mono` available
