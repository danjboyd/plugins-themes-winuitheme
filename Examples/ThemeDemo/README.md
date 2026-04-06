# ThemeDemo

This directory contains the GNUstep-side review app for `WinUITheme`.

Build from the repo root:

```powershell
powershell -ExecutionPolicy Bypass -File Scripts/Build-ThemeDemo.ps1
```

Run from the repo root:

```powershell
powershell -ExecutionPolicy Bypass -File Scripts/Run-ThemeDemo.ps1
```

On this Windows/MSYS2 GNUstep setup, launching `ThemeDemo.exe` directly is not
reliable unless the runtime environment points at the matching `clang64`
GNUstep tree. The run helper script sets `GNUSTEP_PATHLIST=C:\msys64\clang64`
and the required DLL `PATH` before launching the app.

The harness now includes real widget surfaces for the roadmap's phase 4-9
review pages:

- `Controls`
- `Text Input`
- `Commands`
- `Data Views`
- `Dialogs`
- `Stress`
