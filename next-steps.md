# next steps - net8 osx-arm64 migration

1. Commit phase-0 tracking scaffold.
2. Add `DuckGame/DuckGame.Net8.csproj` and `Steam/Steam.Net8.csproj`.
3. Wire minimal compile constants (`DUCKGAME_NET8`, `NO_STEAM`) and source include/exclude sets.
4. Run `dotnet restore/build` and fix first wave of compile errors (namespaces/types).
5. Add net8 startup stub for `DGWindows.WindowsPlatformStartup`.
6. Implement no-steam guards and non-Windows crash-path safeguards.
7. Add net8-safe texture/font pathways.
8. Stage mac native publish assets and publish script.
9. Run verification matrix and iterate until bootable publish path is stable.
