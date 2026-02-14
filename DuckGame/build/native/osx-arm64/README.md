# macOS arm64 native runtime assets

Place required native libraries for `dotnet publish -r osx-arm64` in this directory.

Expected filenames (matching FNA dllmap conventions):

- `libSDL2-2.0.0.dylib`
- `libFNA3D.0.dylib`
- `libFAudio.0.dylib`
- `libtheorafile.dylib`

These files are copied to the publish output by `DuckGame.Net8.csproj` when targeting `osx-arm64`.
