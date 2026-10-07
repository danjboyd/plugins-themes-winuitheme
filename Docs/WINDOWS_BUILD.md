# Windows Build Notes

This repository now supports the full local build, install, and review loop on
the current machine.

## Requirements

- MSYS2 with the `clang64` GNUstep packages: gnustep-make 2.9.3, gnustep-base
  1.31.1, gnustep-gui 0.32.0 and gnustep-back 0.32.0 or later. Update the whole
  `clang64` environment together (MSYS2 doesn't support partial upgrades; gui
  0.32 needs ICU 78 and libxml2 2.15).
- **gnustep-gui 0.31 is not supported.** Its theme loader misparses the
  theme's `_override<Class>Method_<selector>` methods (fixed upstream in
  libs-gui `a8018d6c8`, first released in 0.32.0): none of the theme's
  overrides are installed, and it overruns a stack buffer while trying, so
  symptoms change from build to build. `Tests/Scripts/Invoke-QuirkProbe.ps1`
  fails `overrides-installed` on such a system.

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
- `powershell -ExecutionPolicy Bypass -File Tests/Scripts/Invoke-QuirkProbe.ps1`

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
- `ThemeDemo` links against `/clang64/lib`, so it imports the `clang64`
  `gnustep-base-1_31.dll` that matches the `clang64` `gnustep-gui-0.dll`.
  Mixing in another GNUstep install's base DLL caused Windows startup failure
  `0xc0000142`.
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

## Regression Probe

`Examples/QuirkProbe` checks theme behaviour by rendering controls and
measuring the pixels, after the Adwaita theme's probe. Build it and run it
against the theme built in this checkout:

```powershell
powershell -ExecutionPolicy Bypass -File Scripts/Build-ThemeBundle.ps1
powershell -ExecutionPolicy Bypass -File Scripts/Invoke-GNUstepMake.ps1 -Directory Examples/QuirkProbe
powershell -ExecutionPolicy Bypass -File Tests/Scripts/Invoke-QuirkProbe.ps1
```

It runs the probe in the `light`, `dark`, `high-contrast` and `light-150`
configurations (`-Configuration` picks some; `light-150` scales the theme's
metrics with `--scale 1.5`, not the backing store), prints one
PASS/FAIL/KNOWN/SKIP line per check, and exits with the number of failures.
`-Theme PATH` checks another build, and `-OutputDirectory DIR` saves a PNG of
each rendered check. Add a check with each fix.

Some checks click with the real pointer (`popup-click-stays-open`), so the
probe moves it while it runs; pass `-NoPointer` to skip those while you use
the desktop.
