# <img src="https://github.com/user-attachments/assets/1a6306e6-0fbb-4c3f-b1bd-1a96070efdd3" height="32"> Duck Game Rebuilt (macOS fork)

This is a fork of [Duck Game Rebuilt](https://github.com/TheFlyingFoool/DuckGameRebuilt) that adds native macOS builds for both Apple Silicon (arm64) and Intel (x64) Macs.

## How to play

1. Download the latest `.dmg` from the [Releases page](https://github.com/philipp-eisen/DuckGameRebuilt-macos/releases/latest)
   - **Apple Silicon** (M1/M2/M3/M4): `DuckGameRebuilt-macos-arm64.dmg`
   - **Intel Mac**: `DuckGameRebuilt-macos-x64.dmg`
2. Open the `.dmg` and drag `DuckGameRebuilt` to your Applications folder
3. Make sure Steam is running and you are logged in with an account that owns [Duck Game](https://store.steampowered.com/app/312530/Duck_Game/)
4. Launch the app

## Upstream project

- Main repository: [TheFlyingFoool/DuckGameRebuilt](https://github.com/TheFlyingFoool/DuckGameRebuilt)
- Wiki: [DuckGameRebuilt Wiki](https://github.com/TheFlyingFoool/DuckGameRebuilt/wiki)
- Discord: [Duck Game Rebuilt Discord](https://discord.gg/XkAjt744hz)

For core gameplay, project docs, and non-macOS platforms, see the upstream repo.

## Disclaimer

This fork only adds macOS build and distribution support. We do not take any responsibility for purchase outcomes or compatibility issues, including situations where you buy Duck Game and it does not run on your Mac.

## Building from source

Prerequisites:

- Xcode Command Line Tools: `xcode-select --install`
- Homebrew
- .NET 8 SDK:
  - `brew install dotnet@8`
  - If needed, add to PATH: `echo 'export PATH="$(brew --prefix dotnet@8)/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc`
  - Verify: `dotnet --version` (should start with `8.`)
- Bun runtime (used by build/packaging scripts):
  - `brew install oven-sh/bun/bun`

### Publish

```bash
# Apple Silicon (default)
bun scripts/publish-macos.ts

# Intel
bun scripts/publish-macos.ts --arch x64
```

Run from the publish folder:

```bash
# arm64
cd DuckGame/bin/Release/net8.0/osx-arm64/publish && ./DuckGame

# x64
cd DuckGame/bin/Release/net8.0/osx-x64/publish && ./DuckGame
```

### Package `.app` and `.dmg`

```bash
# Apple Silicon .app + .dmg
bun scripts/package-macos.ts --dmg

# Intel .app + .dmg
bun scripts/package-macos.ts --arch x64 --dmg
```

Output: `dist/macos/`
