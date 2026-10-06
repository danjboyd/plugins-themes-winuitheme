# Improvement Backlog

A running list of theme bugs and WinUI polish found by running real GNUstep
apps under the theme with no changes to the apps, after the Adwaita theme's
`Docs/IMPROVEMENTS.md`. Each item notes how it was found and links its issue.
Regression checks live in `Examples/QuirkProbe`; run
`Tests/Scripts/Invoke-QuirkProbe.ps1` (see `Docs/WINDOWS_BUILD.md`).

## Fixed

| Item | Fix | Found by |
| --- | --- | --- |
| The documented build failed: the scripts called a `gnustep` CLI that isn't installed (#11) | `Scripts/Invoke-GNUstepMake.ps1` uses the CLI when present, MSYS2 clang64 otherwise | the parity audit |
| None of the theme's 23 method overrides ran, and the theme loader overran a stack buffer (gnustep-gui 0.31) | gnustep-gui 0.32 is required (libs-gui `a8018d6c8`); QuirkProbe `overrides-installed` | the parity audit, while fixing #4 |
| Overrides reached from a subclass skipped drawing: image toolbar items drew nothing (#2) | `WinUIThemeOriginalMethod()`; QuirkProbe `subclass-image-cell`, `toolbar-image-item` | the audit; confirmed in ScreenshotTool, whose toolbar icons now draw |
| Windows created after launch had no menu bar (#1) | the main menu is attached when such a window becomes key or main; QuirkProbe `late-window-menu` | ThemeDemo |
| Menu bar titles were clipped ("Fil", "Ed") | `-proposedTitleWidth:forMenuView:` widens items for the theme's padding; QuirkProbe `menu-bar-titles-fit` | ThemeDemo, once #1 showed the bar |
| ThemeDemo's window came up empty: the pop-up override raised `NSUnknownKeyException` (`_lastValidFrame`) | the stray key-value call is gone | ThemeDemo, once #1 attached the menu during launch |
| Table and outline headers drew every title twice (#3) | the header hook draws only the background; titles at the leading edge, 12pt in; QuirkProbe `table-header-title-once`, `table-header-title-inset` | ThemeDemo |
| A clean build shipped a generated `Info-gnustep.plist` without `GSThemeDomain`: scrollers on the left, no Windows menu style (#4) | `WinUIThemeInfo.plist` is merged by gnustep-make; QuirkProbe `theme-domain`, `scroller-trailing-edge` | ThemeDemo |
| Wrapping and multi-line labels (alert text) showed one line (#15) | labels that need more lines keep the full rect; QuirkProbe `label-wraps`, `label-line-breaks` | ThemeDemo |
| Category overrides replaced AppKit's menu item and segment methods for the whole process (#12) | GSTheme `_override` hooks; QuirkProbe `theme-switch-restores-methods` | the audit (compiler warnings) |
| Switches were nearly invisible, On looked like Off, and switches made in code were disabled (#6) | WinUI ToggleSwitch drawing; new switches enabled (gui 0.32 left them disabled); QuirkProbe `switch-*` | ThemeDemo |
| Stepper chevrons pointed the wrong way (#7) | chevrons follow the view's orientation; QuirkProbe `stepper-chevrons-point-out` | ThemeDemo |

## Found in real apps

Run on 2026-10-06 with gnustep-gui 0.32 (MSYS2 clang64), branch
`adwaita-parity-phase-b`.

| Finding | App | Issue |
| --- | --- | --- |
| An alert's OK button is an empty white button in the light palette (the window's default button cell gets white text but no accent fill) | ScreenshotTool | #53 |
| Pop-up buttons and menus close when the click that opened them is released (libs-gui 0.32; also under the default theme) | ThemeDemo | #54 |
| A dark line under the toolbar (light); the "Zoom" view item's label is unreadable (dark) | ScreenshotTool | #21 |
| Monochrome toolbar icons nearly disappear in the dark palette | ScreenshotTool | #25 |
| An alert is a borderless band as wide as its parent window, with GNUstep's layout | ScreenshotTool | #23 |
| A nib-based app's 22pt controls drawn with the theme's 32-34pt metrics | SystemPreferences | #31 |
| The application menu (app name, Hide, Services) in a Windows menu bar | ScreenshotTool, SystemPreferences, ThemeDemo | #24 |
| Outline child rows draw their chevron over the title | ThemeDemo | #51 |

## Not yet exercised

- **ObjcMarkdown** doesn't build on this machine, for reasons in that
  repository, not the theme:
  - `main` (`e71e0ed`): `OMMarkdownRendererMath.m` calls static functions
    that `fe770f5` ("Split OMMarkdownRenderer.m along its topics") left in
    `OMMarkdownRenderer.m`.
  - Before the split (`3df2bf2`): the GNUmakefile's MinGW `mode_t` defines
    (`_MODE_T_`, `_MODE_T_DEFINED`, `__mode_t_defined`) now stop the
    upgraded headers declaring `mode_t` at all. Without them, MarkdownViewer
    fails to link: `OMRenderedObjectAttributeName`, `OMTextTableAttributeName`
    and `OMTextTableRowAttributeName` aren't exported from the
    ObjcMarkdown DLL.
- **Gorm** isn't installed on this machine.
- **TinyRetroPad** is a Win32 assembly program, not a GNUstep app.

## Not theme bugs

- **ScreenshotTool opens its launch arguments as files.** Launched with
  `-GSTheme PATH`, it tries to open `-GSTheme` as an image and shows
  "Unable to Open Image". GNUstep's `-Key value` arguments are defaults, not
  documents.
- **ScreenshotTool needs `MSYSTEM=CLANG64`** to find FreeType's headers.
  Its GNUmakefile chooses `/clang64/include/freetype2` from that variable.
