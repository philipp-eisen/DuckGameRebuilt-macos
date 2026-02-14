# next steps - net8 osx-arm64 migration

1. Install .NET SDK 8.x on this machine (hard blocker).
2. Run `dotnet restore DuckGame/DuckGame.Net8.csproj` and resolve package/reference errors.
3. Run `dotnet build DuckGame/DuckGame.Net8.csproj -c Debug` and fix compile issues until clean.
4. Place required mac arm64 native dylibs in `DuckGame/build/native/osx-arm64/`.
5. Run `dotnet publish DuckGame/DuckGame.Net8.csproj -c Release -r osx-arm64 --self-contained true`.
6. Perform runtime smoke test on macOS arm64 (menu + local match).
7. Iterate font/texture/runtime fixes based on smoke results.
8. Finalize phase-5 stabilization notes and update tracking files to done.
