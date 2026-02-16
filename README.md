# <img src="https://github.com/user-attachments/assets/1a6306e6-0fbb-4c3f-b1bd-1a96070efdd3" height="32"> Duck Game Rebuilt (macOS fork)

This repository is a fork of Duck Game Rebuilt focused on macOS support.

## How to play

- Download the latest build from the [Releases page](https://github.com/philipp-eisen/DuckGameRebuilt-macos/releases/latest)
- Ensure you have steam running
- You must be logged into Steam with an account that owns [Duck Game](https://store.steampowered.com/app/312530/Duck_Game/)

## Upstream project

- Main repository: [TheFlyingFoool/DuckGameRebuilt](https://github.com/TheFlyingFoool/DuckGameRebuilt)
- Wiki: [DuckGameRebuilt Wiki](https://github.com/TheFlyingFoool/DuckGameRebuilt/wiki)
- Discord: [Duck Game Rebuilt Discord](https://discord.gg/XkAjt744hz)

For core gameplay/project docs, use the upstream repository and wiki.

## Disclaimer

- This fork only adds macOS build/distribution support.
- I do not take any responsibility for purchase outcomes or compatibility issues, including situations where you buy Duck Game and it still does not run on your Mac.

## Build on macOS (Apple Silicon)

Prerequisites:

- Xcode Command Line Tools: `xcode-select --install`
- Homebrew
- .NET 8 SDK
  - `brew update`
  - `brew install dotnet@8`
  - If needed, add to PATH:
    - `echo 'export PATH="$(brew --prefix dotnet@8)/bin:$PATH"' >> ~/.zshrc`
    - `source ~/.zshrc`
  - Verify: `dotnet --version` (should start with `8.`)
- Bun runtime (used by build scripts):
  - `brew install oven-sh/bun/bun`
  - Verify: `bun --version`

Publish the macOS build:

```bash
bun scripts/publish-macos.ts
```

Run from the publish folder:

```bash
cd DuckGame/bin/Release/net8.0/osx-arm64/publish
./DuckGame
```
