# Release Readiness

This document records the phase 12 release state for `WinUITheme`.

## Release Checklist

- [x] Theme bundle builds locally.
- [x] Theme bundle installs locally for the active Windows/MSYS2 user.
- [x] `ThemeDemo` builds locally.
- [x] WinUI 3 reference app builds locally.
- [x] Native-dialog and window-integration code is wired into the theme build.
- [x] Variant review scripts exist.
- [x] `ObjcMarkdown` smoke launch under `WinUITheme` works.
- [ ] Variant screenshot corpus is frozen and reviewed.
- [ ] `ObjcMarkdown` validation captures are frozen and reviewed.
- [ ] `ObjcMarkdown` sibling build/test state is green enough to treat as a hard
      release gate.

## Current Release Blockers

As of `2026-04-03`, release is still blocked by:

1. The phase 10 screenshot corpus is not frozen yet.
2. The phase 11 `ObjcMarkdown` validation corpus is not frozen yet.
3. The sibling `ObjcMarkdown` repository is not green in its current Windows
   build/test state.

## Supported Review Scripts

- `Scripts/Build-ThemeBundle.ps1`
- `Scripts/Install-ThemeBundle.ps1`
- `Scripts/Build-ThemeDemo.ps1`
- `Scripts/Run-ThemeDemo.ps1`
- `Scripts/Build-WinUIReferenceApp.ps1`
- `Scripts/Run-WinUIReferenceApp.ps1`
- `Scripts/Run-ObjcMarkdownValidation.ps1`
- `Tests/Scripts/Invoke-ThemeAcceptanceMatrix.ps1`
- `Tests/Scripts/Invoke-ObjcMarkdownValidation.ps1`

## Ship Standard

`WinUITheme` is ready to ship only when:

1. `ThemeDemo`, the WinUI 3 reference app, and `ObjcMarkdown` have current
   acceptance captures.
2. All known deltas are classified.
3. Any remaining blockers are documented as explicit non-goals rather than
   unknown behavior.
