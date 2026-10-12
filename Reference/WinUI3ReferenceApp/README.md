# WinUI 3 Reference App

This directory contains the WinUI 3 starter review harness for `WinUITheme`.

At phases 1 through 3, the app is intentionally simple and contract-driven. It
mirrors the GNUstep `ThemeDemo` at the page, section, and fixture level so the
two harnesses can be compared consistently even before real rendering parity is
implemented.

Build with:

```powershell
powershell -ExecutionPolicy Bypass -File build.ps1
```

## Measured comparison

`--mode light|dark` sets the app's theme. The `specimens` page (also in
ThemeDemo, `--page specimens`) puts one of each control at a fixed place on
a canvas marked by a magenta square.
`Tests/Scripts/Compare-Reference.ps1 [-Mode light,dark] [-OutputDirectory DIR]`
captures both apps' specimens pages and measures them with
`Tests/Scripts/measure_specimens.py`: control sizes, fills, strokes and
corners, where text sits in a control, the slider and progress bar's parts
and the body text's width. It writes a report and a side-by-side sheet
per mode, and exits with the number of measurements out of tolerance
(colours 6 per channel, sizes 1px, text width 2%).
