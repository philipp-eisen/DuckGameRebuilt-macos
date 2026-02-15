# next steps - net8 osx-arm64 migration

1. Perform interactive gameplay validation on Steam-enabled net8 publish:
   - confirm title -> TeamSelect2 navigation works
   - start local match flow end-to-end
   - verify no texture/font/audio regressions during active gameplay
2. Validate behavior both with and without Steam client login/session, and decide if non-Steam fallback UX (`Steam INIT Failed!`) needs explicit user messaging.
3. Investigate and fix (or explicitly defer) startup audio packaging/reference issue for `NVorbis` reported by compiler warnings.
4. Triage repeated `GlobalData` parse warnings for save-data compatibility (migrate old values, clear invalid fields, or document expected behavior).
5. Evaluate whether no-Steam lane should be kept as an optional future target, now that primary lane is Steam-enabled for TeamSelect2 compatibility.
6. Address or consciously defer `SixLabors.ImageSharp` advisory (`GHSA-rxmq-m78w-7wmc`) before final handoff.
7. Capture final stabilization notes in `docs/migration/net8-macos-phase1.md` with warning profile + known limitations, then make incremental commit(s).
