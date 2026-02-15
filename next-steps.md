# next steps - net8 osx-arm64 migration

1. Perform interactive runtime validation now that no-Steam startup survives 60s:
   - confirm menu input/navigation works
   - verify intended single-player flow(s) still function
   - verify no texture/font/audio regressions during active gameplay
2. Decide whether no-Steam phase should support `TeamSelect2`/multiplayer menus; if yes, do a focused no-Steam compatibility pass in `TeamSelect2` and related UI instead of current transition-block workaround.
3. Investigate and fix (or explicitly defer) startup audio packaging/reference issue for `NVorbis` reported in logs.
4. Triage repeated `GlobalData` parse warnings for save-data compatibility (migrate old values, clear invalid fields, or document expected behavior).
5. Keep Steam managed assemblies in phase-1 publish output (runtime still `NO_STEAM`), and optionally add a future task to harden `Program.Resolve` so strict Steam-free packaging does not recurse/overflow.
6. Address or consciously defer `SixLabors.ImageSharp` advisory (`GHSA-rxmq-m78w-7wmc`) before final handoff.
7. Capture final stabilization notes in `docs/migration/net8-macos-phase1.md` with warning profile + known limitations, then make incremental commit(s).
