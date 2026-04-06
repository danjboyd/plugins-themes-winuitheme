# ObjcMarkdown Validation

This document records the phase 11 real-app validation status for
`C:\Users\Support\git\ObjcMarkdown`.

## Review Commands

Build the sibling repo:

```powershell
powershell -ExecutionPolicy Bypass -File ..\ObjcMarkdown\scripts\windows\build-from-powershell.ps1 -Task build
```

Run the sibling test suite:

```powershell
powershell -ExecutionPolicy Bypass -File ..\ObjcMarkdown\scripts\windows\build-from-powershell.ps1 -Task test
```

Smoke-launch the viewer under `WinUITheme`:

```powershell
powershell -ExecutionPolicy Bypass -File Scripts/Run-ObjcMarkdownValidation.ps1
```

## Current Status

As of `2026-04-03`:

- `MarkdownViewer` launches successfully under `WinUITheme` in the local
  Windows/MSYS2 environment.
- A smoke launch left `MarkdownViewer` running and responding in the local
  desktop session.

## Current Blockers

The real-app gate is not fully closed yet because the sibling repo is not green.

### Build/Test Issues Observed On `2026-04-03`

1. The aggregate `build` lane fails while compiling
   `ObjcMarkdownTests/OMDPanelSelectionTests.m`.
   The current compiler failure starts around line `150` and prevents the test
   bundle from building cleanly in that lane.
2. The `test` lane runs existing built bundles, but `OMMarkdownRendererTests`
   still reports two failing tests:
   - `testDisplayMathDollarsAreStyled`
   - `testDisplayMathAcrossLinesIsStyled`

### Validation Gaps

1. The screenshot corpus for `ObjcMarkdown` is not frozen yet.
2. The current Windows desktop capture flow is usable for smoke review but is
   not yet robust enough to be the only acceptance mechanism.

## Mismatch Ledger

Current classification:

- `external-repo blocker`
  `ObjcMarkdown` test/build failures described above.
- `theme-repo blocker`
  Real-app visual captures are not yet frozen into the final acceptance corpus.
- `acceptable for now`
  Smoke-launch verification of `MarkdownViewer` under `WinUITheme` is working,
  so the theme does not appear to cause immediate startup failure in the real
  app.
