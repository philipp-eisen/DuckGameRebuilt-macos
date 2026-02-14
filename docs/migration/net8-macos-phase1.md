# net8 macOS arm64 phase 1

This document describes the first migration milestone for running DuckGameRebuilt as a published .NET 8 app on Apple Silicon.

## Scope

- Bootable `net8` publish path for `osx-arm64`
- Steam disabled by default (`NO_STEAM`) for this phase
- Existing net48/Mono workflow remains untouched

## Build and publish

```bash
dotnet restore DuckGame/DuckGame.Net8.csproj
dotnet build DuckGame/DuckGame.Net8.csproj -c Debug
dotnet publish DuckGame/DuckGame.Net8.csproj -c Release -r osx-arm64 --self-contained true
```

Or use:

```bash
./scripts/publish-macos-arm64.sh
```

## Required native runtime files

Place these files in `DuckGame/build/native/osx-arm64/` before publish:

- `libSDL2-2.0.0.dylib`
- `libFNA3D.0.dylib`
- `libFAudio.0.dylib`
- `libtheorafile.dylib`

## Known limitations in phase 1

- Steam runtime integration is disabled.
- CrashWindow integration is Windows-only and skipped on non-Windows.
- Dynamic GDI raster font behavior is replaced with a fallback path on net8.
- Texture conversion path is replaced with ImageSharp-based processing.
