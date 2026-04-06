# GNUstep WinUI Theme

`plugins-themes-winuitheme` is a GNUstep theme project that targets WinUI 3 as
closely as practical while preserving GNUstep desktop application conventions.

The target is a Windows-native result for ordinary GNUstep desktop software:
document windows, top menu bars, toolbars, inspectors, data views, dialogs, and
split-window layouts.

This repository is intentionally not trying to recreate the Windows Settings
app shell or turn GNUstep into a XAML application framework. The visual target
is WinUI 3 client-area parity with GNUstep structure intact.

## Current Status

The repository now has the full phase 1-12 implementation scaffold in place:

- theme settings, metrics, palette, and runtime defaults
- shared drawing helpers and client-area control rendering
- menu, data-view, and container rendering
- native Windows file/print/page-setup integration
- DWM-backed window integration
- GNUstep `ThemeDemo` and WinUI 3 reference harnesses
- variant-review and real-app validation scripts
- release-readiness and backlog documentation

Current blockers are release-gate items rather than missing implementation:

- the screenshot corpus still needs a final manual freeze
- `ObjcMarkdown` is not green enough yet to close the hard real-app gate

## Key Documents

- [Implementation Roadmap](./Docs/IMPLEMENTATION_ROADMAP.md)
- [Windows Build Notes](./Docs/WINDOWS_BUILD.md)
- [Surface Ownership Matrix](./Docs/SURFACE_OWNERSHIP_MATRIX.md)
- [Harness Review Notes](./Docs/HARNESS_REVIEW.md)
- [Upstream Boundaries](./Docs/UPSTREAM_BOUNDARIES.md)
- [Variant And Accessibility Review](./Docs/VARIANT_AND_ACCESSIBILITY_REVIEW.md)
- [ObjcMarkdown Validation](./Docs/OBJCMARKDOWN_VALIDATION.md)
- [Release Readiness](./Docs/RELEASE_READINESS.md)
- [Post-Release Backlog](./Docs/POST_RELEASE_BACKLOG.md)

## Repository Layout

```text
Source/                    Theme implementation
Source/Settings/           Settings and metrics model
Source/Rendering/          Palette and future rendering code
Source/Native/             Reserved for later Windows adapters
Resources/                 Theme bundle metadata and future assets
Examples/ThemeDemo/        GNUstep-side review harness
Examples/Shared/PageContract/
Reference/WinUI3ReferenceApp/
Tests/Scripts/             Validation and capture helpers
Docs/                      Roadmap and design notes
```

## Build

Build the theme bundle:

```sh
make
```

Build and install the theme bundle on this Windows/MSYS2 machine:

```powershell
powershell -ExecutionPolicy Bypass -File Scripts/Build-ThemeBundle.ps1
powershell -ExecutionPolicy Bypass -File Scripts/Install-ThemeBundle.ps1
```

Build the GNUstep demo harness:

```sh
make -C Examples/ThemeDemo
```

Build the WinUI 3 reference harness:

```powershell
powershell -ExecutionPolicy Bypass -File Reference/WinUI3ReferenceApp/build.ps1
```

## Real-App Gate

Before release, the theme must validate against `ObjcMarkdown` in the sibling
directory at `C:\Users\Support\git\ObjcMarkdown`.
