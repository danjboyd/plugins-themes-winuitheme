# Windows Build Notes

This repository now supports the full local build, install, and review loop on
the current machine.

Repo-root helper scripts:

- `powershell -ExecutionPolicy Bypass -File Scripts/Build-ThemeDemo.ps1`
- `powershell -ExecutionPolicy Bypass -File Scripts/Run-ThemeDemo.ps1`
- `powershell -ExecutionPolicy Bypass -File Scripts/Build-ThemeBundle.ps1`
- `powershell -ExecutionPolicy Bypass -File Scripts/Install-ThemeBundle.ps1`
- `powershell -ExecutionPolicy Bypass -File Scripts/Build-WinUIReferenceApp.ps1`
- `powershell -ExecutionPolicy Bypass -File Scripts/Run-WinUIReferenceApp.ps1`
- `powershell -ExecutionPolicy Bypass -File Scripts/Run-ObjcMarkdownValidation.ps1`
- `powershell -ExecutionPolicy Bypass -File Tests/Scripts/validate-page-contract.ps1`
- `powershell -ExecutionPolicy Bypass -File Tests/Scripts/Invoke-ThemeAcceptanceMatrix.ps1`
- `powershell -ExecutionPolicy Bypass -File Tests/Scripts/Invoke-ObjcMarkdownValidation.ps1`

The build scripts call `Scripts/Invoke-GNUstepMake.ps1`, which uses the
`gnustep` CLI when it is on `PATH` and otherwise runs GNUstep Make in MSYS2's
`clang64` environment.

## Theme Bundle

Best-effort build:

```powershell
powershell -ExecutionPolicy Bypass -File Scripts/Build-ThemeBundle.ps1
```

Install for the current user:

```sh
make install GNUSTEP_INSTALLATION_DOMAIN=USER
```

Expected install path:

```text
~/GNUstep/Library/Themes/WinUITheme.theme
```

Current status:

- Source compilation and bundle linking succeed when the build uses the
  `clang64` GNUstep makefiles.
- The current repo helper script sources:
  `/clang64/share/GNUstep/Makefiles/GNUstep.sh`
- The installed user-theme path on this machine is:
  `C:\msys64\home\Support\GNUstep\Library\Themes\WinUITheme.theme`

## GNUstep ThemeDemo

Build:

```powershell
powershell -ExecutionPolicy Bypass -File Scripts/Build-ThemeDemo.ps1
```

Run:

```powershell
powershell -ExecutionPolicy Bypass -File Scripts/Run-ThemeDemo.ps1
```

Run a specific page under the installed theme:

```powershell
powershell -ExecutionPolicy Bypass -File Scripts/Run-ThemeDemo.ps1 -Theme WinUITheme -Page real-app
```

Current status:

- `ThemeDemo` builds successfully with the repo helper script.
- `ThemeDemo` is forced to link against `/clang64/lib` so it imports
  `gnustep-base-1_30.dll`, matching the installed `gnustep-gui-0.dll` on this
  machine. Linking against the system `1_31` base DLL caused Windows startup
  failure `0xc0000142`.
- On this machine, `ThemeDemo.exe` also needs `GNUSTEP_PATHLIST` pointed at
  `C:\msys64\clang64` so GNUstep loads the matching `clang64` backend bundle
  instead of the incompatible `/usr/GNUstep/System` backend.
- `Scripts/Run-ThemeDemo.ps1` sets `GNUSTEP_PATHLIST` and a matching runtime
  `PATH` using `C:\msys64\clang64\bin` and `C:\msys64\mingw64\bin`.
- The helper script stages a local compatibility copy of `libgcc_s.a` under
  `tmp/clang64-linker-compat/` for the current MSYS2 layout.

## WinUI 3 Reference App

Build:

```powershell
powershell -ExecutionPolicy Bypass -File Scripts/Build-WinUIReferenceApp.ps1
```

The reference app is intentionally separate from the theme bundle. It is a
design oracle and review harness, not a rendering dependency.

Current status:

- `dotnet` 8 SDK is installed on this machine.
- The reference app builds successfully with `EnableMsixTooling=true`.

Run:

```powershell
powershell -ExecutionPolicy Bypass -File Scripts/Run-WinUIReferenceApp.ps1 -Page real-app
```

## Real-App Validation

Later phases must validate against:

- `C:\Users\Support\git\ObjcMarkdown`

Smoke launch:

```powershell
powershell -ExecutionPolicy Bypass -File Scripts/Run-ObjcMarkdownValidation.ps1
```
