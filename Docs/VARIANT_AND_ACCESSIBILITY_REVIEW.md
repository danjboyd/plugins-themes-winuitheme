# Variant And Accessibility Review

This document records the phase 10 review matrix for `WinUITheme`.

## Review Matrix

The current automated matrix covers these review variants:

- `light-100`
- `dark-100`
- `high-contrast-100`
- `reduced-transparency-100`
- `light-125`
- `light-150`
- `light-200`

The default page set is:

- `controls`
- `text-input`
- `commands`
- `data-views`
- `dialogs`
- `stress`
- `real-app`

## Review Commands

Build and install the theme first:

```powershell
powershell -ExecutionPolicy Bypass -File Scripts/Build-ThemeBundle.ps1
powershell -ExecutionPolicy Bypass -File Scripts/Install-ThemeBundle.ps1
```

Generate the current acceptance corpus:

```powershell
powershell -ExecutionPolicy Bypass -File Tests/Scripts/Invoke-ThemeAcceptanceMatrix.ps1
```

Artifacts are written under:

```text
Tests/Screenshots/
```

## Current Status

As of `2026-04-03`:

- The theme bundle now builds successfully against the MSYS2 `clang64`
  GNUstep makefiles.
- The theme installs successfully to:
  `C:\msys64\home\Support\GNUstep\Library\Themes\WinUITheme.theme`
- The review matrix script is in place and uses the actual installed
  `WinUITheme` bundle.
- WinUI 3 reference app captures are scriptable through the same page ID
  vocabulary used by `ThemeDemo`.

## Known Limitations

- GNUstep desktop capture on this Windows backend is not yet fully deterministic.
  The fallback capture flow depends on a foreground desktop session.
- `ThemeDemo` accepts page IDs and theme-variant arguments, but the internal
  self-capture path is not yet reliable enough to be treated as the canonical
  capture backend.
- Until the screenshot corpus is manually reviewed and frozen, phase 10 should
  be treated as implemented but not visually closed.

## Acceptance Standard

Phase 10 is considered visually closed only when:

1. The screenshot corpus includes current captures for every required page.
2. Light, dark, high-contrast, reduced-transparency, and scale-factor captures
   have been reviewed for obvious regressions.
3. Any remaining deltas are classified as intended GNUstep behavior or an
   explicit blocker.
