# <img src="https://github.com/user-attachments/assets/1a6306e6-0fbb-4c3f-b1bd-1a96070efdd3" height="32"> Duck Game Rebuilt
Duck Game Rebuilt is a decompilation of Duck Game with massive improvements to performance, compatibility, and quality of life features.

Join [our Discord server](https://discord.gg/XkAjt744hz) if you have any questions, need help, or want to report bugs

Notable wiki pages:
* [Frequently Asked Questions](https://github.com/TheFlyingFoool/DuckGameRebuilt/wiki/FAQ)
* [A list of all improvements to Duck Game Rebuilt](https://github.com/TheFlyingFoool/DuckGameRebuilt/wiki/Changelog)
* [Hardware and software compatibility](https://github.com/TheFlyingFoool/DuckGameRebuilt/wiki/Architectures-and-Devices)

## Installation 📥

For **Windows** users, subscribe to [the steam workshop mod](https://steamcommunity.com/sharedfiles/filedetails/?id=3132351890).

For **Linux** users, follow the [Linux Installation Guide](https://github.com/TheFlyingFoool/DuckGameRebuilt/wiki/Linux-Installation-Guide)

## For Developers 🚧
Welcome to the repo, enjoy your stay, please unfuck the code. thanks

Note: your IDE will scream at you with 200+ warnings when building, which is normal

### Building on Windows

* Make sure you have [.NET Framework 4.8](https://dotnet.microsoft.com/en-us/download/dotnet-framework/net48) installed and have a functioning IDE (like [Visual Studio](https://docs.microsoft.com/en-us/visualstudio/install/install-visual-studio?view=vs-2022)) for C#
* Make sure the Startup Program leads to the exe produced in the ./bin folder after compiling
* Restore the NuGet packages (most IDEs automatically do this anyway)
* Build the solution with `Ctrl+Shift+B`
* Run the game in Debug Mode with `F5` (will crash unless Steam is running)
  * Make sure the currently selected project is DuckGame and not CrashWindow/FNA/anything else

### Building on GNU/Linux

* Add the [official monoproject repos](https://www.mono-project.com/download/stable/) (unless you're firebreak appearantly)
* Install the `mono-complete` package<!-- * Install the `msbuild` package ..I think msbuild is a dependency of mono-complete -->
* `cd` to the solution's directory
* Restore the NuGet packages if your IDE hasn't
  * `nuget restore`
* Add missing DLL dependencies from Windows located in ./DuckGame/lib/
  * `mkdir ./bin/`
  * `cp ./DuckGame/lib/* ./bin/`
* Build the solution
  * `msbuild -m -p:Configuration=Debug`
* Run the game (will crash unless Steam is currently running)
  * `mono ./bin/DuckGame.exe`

### Building on macOS (Apple Silicon)

Prerequisites:

* macOS with Xcode Command Line Tools installed (`xcode-select --install`)
* Homebrew + .NET 8 SDK (install with Homebrew):
  * `brew update`
  * `brew install dotnet@8`
  * If `dotnet` is not on your `PATH`, add it:
    * `echo 'export PATH="$(brew --prefix dotnet@8)/bin:$PATH"' >> ~/.zshrc`
    * `source ~/.zshrc`
  * Verify installation: `dotnet --version` (should start with `8.`)
* Native runtime libraries present in `DuckGame/build/native/osx-arm64/`:
  * `libSDL2-2.0.0.dylib`
  * `libFNA3D.0.dylib`
  * `libFAudio.0.dylib`
  * `libtheorafile.dylib`
* Managed compatibility dependencies present in `deps/`:
  * `System.Memory.4.5.5/lib/net461/System.Memory.dll`
  * `System.Runtime.CompilerServices.Unsafe.6.0.0/lib/net461/System.Runtime.CompilerServices.Unsafe.dll`

If the two managed dependency folders are missing, install them with NuGet:

```bash
nuget install System.Memory -Version 4.5.5 -OutputDirectory deps
nuget install System.Runtime.CompilerServices.Unsafe -Version 6.0.0 -OutputDirectory deps
```

Publish the macOS build:

```bash
bash scripts/publish-macos-arm64.sh
```

Run it from the publish folder:

```bash
cd DuckGame/bin/Release/net8.0/osx-arm64/publish
./DuckGame
```

Notes:

* Publish output path: `DuckGame/bin/Release/net8.0/osx-arm64/publish/`
* Steam initialization on macOS depends on AppID platform support in Steam. If the AppID is not mac-enabled, the build can still publish/run but Steam login/features may fail at runtime.
