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

- [done] Phase 0.5: mandatory SDK bootstrap (self-unblock gate)
  - [done] .NET SDK 8.x installed and resolved in shell (`/opt/homebrew/opt/dotnet@8/bin/dotnet`)
  - [done] host/rid verification passed (`arm64` / `osx-arm64`)
  - [done] gate commands (`restore` + `build`) execute without toolchain errors

- [done] Phase 1: add parallel SDK-style net8 build lane
  - [done] `DuckGame/DuckGame.Net8.csproj` added
  - [done] `Steam/Steam.Net8.csproj` added
  - [done] local restore/build verification completed

- [done] Phase 2: compile-compatibility pass
  - [done] added net8 compat shims for `System.Windows.Forms` and missing namespaces
  - [done] added net8 startup stub for `DGWindows.WindowsPlatformStartup`
  - [done] `dotnet build DuckGame/DuckGame.Net8.csproj -c Debug` succeeds

- [done] Phase 3: runtime boot pass (no steam)
  - [done] added `NO_STEAM` guards in `Program.cs`
  - [done] added non-Windows crash-window guard path
  - [done] added net8 font fallback (`FontGDIContext.Net8.cs`)
  - [done] added net8 texture conversion path (`TextureConverter.Net8.cs`)
  - [done] published app smoke-run survives 8s with no stderr/stdout output (`ALIVE_AFTER_8S`)

- [done] Phase 4: publish packaging for `osx-arm64`
  - [done] publish script added (`scripts/publish-macos-arm64.sh`)
  - [done] native asset staging path added (`DuckGame/build/native/osx-arm64`)
  - [done] migration docs added (`docs/migration/net8-macos-phase1.md`)
  - [done] `dotnet publish` succeeds and output includes required dylibs
  - [done] linkage patch/sign steps verified (`otool -L` shows `@rpath/libSDL2-2.0.0.dylib` from `libFNA3D.0.dylib`)

- [in_progress] Phase 5: stabilization and final verification
  - [done] SDK/bootstrap + build/publish verification matrix items are green
  - [done] publish script now cleans output directory before publish to avoid stale artifacts
  - [in_progress] manual in-game validation (menu navigation and local match)
  - [done] no-Steam startup crash chain currently suppressed through 60s title-screen smoke run
  - [pending] finalize warning triage strategy for long-tail net8 warnings

## Verification log
- `uname -m` -> `arm64`
- `which dotnet` -> `/opt/homebrew/opt/dotnet@8/bin/dotnet`
- `dotnet --version` -> `8.0.124`
- `dotnet --list-sdks` -> `8.0.124`
- `dotnet --info` -> RID `osx-arm64`, host architecture `arm64`
- `dotnet restore DuckGame/DuckGame.Net8.csproj` -> success (warning: `SixLabors.ImageSharp` advisory `GHSA-rxmq-m78w-7wmc`)
- `dotnet build DuckGame/DuckGame.Net8.csproj -c Debug -clp:ErrorsOnly` -> success (warnings only)
- `dotnet build DuckGame/DuckGame.Net8.csproj -c Release -clp:ErrorsOnly` -> success (warnings only)
- `scripts/publish-macos-arm64.sh` -> success (warnings only)
- `otool -L DuckGame/bin/Release/net8.0/osx-arm64/publish/libFNA3D.0.dylib` -> SDL dependency resolved via `@rpath/libSDL2-2.0.0.dylib`
- smoke test (`DuckGame/bin/Release/net8.0/osx-arm64/publish/DuckGame`) -> process alive after 8 seconds, zero-line `run.log`
- attempted strict Steam assembly removal from publish output -> startup stack overflow in assembly resolve path; reverted to Steam-managed assembly presence with `NO_STEAM` runtime guards, smoke test green again
- latest runtime smoke (`DuckGame/bin/Release/net8.0/osx-arm64/publish/DuckGame`, 60s timeout) stayed alive with no fatal exception in `ducklog.txt`
