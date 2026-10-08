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
| Monochrome toolbar icons nearly disappeared in the dark palette (#25) | template images are tinted with the text colour around them; QuirkProbe `template-images` | ScreenshotTool |
| A dark line under the toolbar; the "Zoom" view item's label unreadable in the dark palette (#21) | WinUI CommandBar layout, hover and colours; QuirkProbe `toolbar-row-height`, `toolbar-bottom-line` | ScreenshotTool |
| Buttons had a Windows 7-style gloss, 7-10pt corners, no pointer-over state, and bold default titles that moved when pressed (#38, #10, #35) | WinUI Button and AccentButton; 4pt control and 8pt overlay corners; QuirkProbe `button-no-gloss`, `button-corner-radius`, `button-pressed-title-still`, `button-hover` | the parity audit |
| Menus had a Win32-classic gutter, a blue selection and cramped shortcuts; tool tips were a black box (#39) | WinUI MenuFlyout and ToolTip, rounded by DWM on Windows 11; QuirkProbe `menu-hover-fill`, `menu-shortcut-gap`, `menu-shortcut-colour`, `menu-separator-width` | the parity audit |
| Scroll bars were always-shown classic strips (#29) | WinUI ScrollBar over the content, hidden at rest; Windows' "Automatically hide scroll bars" and `WinUIThemeOverlayScrollbars NO` keep them shown; QuirkProbe `scroller-*` | the parity audit |
| Focus rings showed after a click, in a translucent accent, round a cell's interior (#36) | WinUI's double-stroke focus visual outside the control, only after keyboard navigation; QuirkProbe `focus-ring-*` | the parity audit |
| Text fields were filled with the window's colour, focused with an accent-tinted border (#37) | WinUI TextBox: control fill, strong bottom edge, 2px accent underline when focused; QuirkProbe `textbox-*` | ThemeDemo |
| Pop-up buttons had a tinted lane and divider; a focused combo box showed an empty field and GNUstep's "..." button (#40, #8) | WinUI ComboBox: one box, chevron, accent pill on the selected drop-down item; no editor in a non-editable combo box; QuirkProbe `popup-no-lane`, `popup-title-primary`, `combobox-focused-keeps-value` | ThemeDemo |
| Table and outline selection was a light-blue fill with a border; nested outline rows drew their chevron over the title (#43, #51) | WinUI ListView/TreeView selection with an accent pill; the chevron placed once from the indented edge; QuirkProbe `list-selection-*`, `outline-chevron-before-title` | ThemeDemo |
| A search field's magnifier and cancel button sat outside the field; the cancel button didn't clear text being typed (#9) | WinUI AutoSuggestBox layout and glyphs; the field editor is cleared too; QuirkProbe `search-*` | ThemeDemo |
| Controls sized with `-sizeToFit` cut their titles: "Sign In" showed "ign I", "Errors only" "Errors", a 44pt "20" nothing (#14) | `-cellSize` measures with the theme's insets and font; a button's title sits between WinUI's 11pt margins; padding gives way before a title is cut; QuirkProbe `size-to-fit-*` | the Adwaita audit (its rows 2, 3, 58) |
| Interface text was Segoe UI at 13px, and bold was Tahoma Bold (#44) | Segoe UI Variable at 14px (Segoe UI on Windows 10), Semibold for bold, Windows' text size honoured; headers grow and TextBoxes keep their underline at larger sizes; QuirkProbe `typography-*` and the `large-text` configuration | the parity audit |
| The slider was a plain circle on a bordered 5-6px track (#41) | WinUI Slider: 4px track, 20px thumb, 12px accent dot (14 under the pointer, 10 pressed); QuirkProbe `slider-*` | ThemeDemo |
| Progress bars were bordered bezels; the indeterminate chunk followed the redraw count; spinners were GNUstep's NeXT spinner (#42) | WinUI ProgressBar (1px track, 3px bar, clock-timed segments) and ProgressRing; QuirkProbe `progress-*` | ThemeDemo |
| Tables built in code had 16pt rows, spaced cells, dividers between every header column, header titles 16pt in, and no row hover (#28, #43) | WinUI list defaults (32pt rows, no grid or spacing), dividers under the pointer, titles 12pt in, a hover fill; QuirkProbe `table-code-defaults`, `table-header-dividers`, `table-header-title-inset`, `table-row-hover` | ThemeDemo, the audit |
| Theme, accent and contrast changes showed only after a window's focus changed, and AppKit's system colours stayed stale (#46) | a hidden listener window hears Windows' broadcasts; reloads tell NSColor; QuirkProbe `live-accent-change` | the parity audit |
| Checkboxes and radios were 14-18px with an 8px radio dot; the plist still mapped five light-mode bitmaps (#5) | WinUI CheckBox and RadioButton at 20px; the bitmaps are gone; QuirkProbe `checkbox-indicator-size`, `radio-centre-dot` | ThemeDemo |
| With libs-gui master, table header titles stayed centred, menu shortcuts were centred and toolbar view items' labels right-aligned: master swapped `NSTextAlignment`'s centre and right (#13) | `WinUIThemeCenterTextAlignment()` and `WinUIThemeRightTextAlignment()` follow `NSParagraphStyle`'s class version; QuirkProbe `toolbar-label-centred`, `menu-shortcut-trailing`, `table-header-title-inset`, run against a master build | the Adwaita theme's row 71 |
| A level indicator at 6 of 10 was a solid red bar in a square white well: with the warning and critical values left at 0, every level counted as critical (#57) | WinUI ProgressBar for capacity (in segments for discrete), a secondary bar for relevancy, RatingControl stars; thresholds at 0 are unset; QuirkProbe `level-*` | ThemeDemo |
| A date picker drew "2026-10-05 19:00:00 -0500" as plain text, with no chrome and no way to edit it (#56) | WinUI DatePicker and TimePicker fields in Windows' date order, a picker flyout to edit them, CalendarView for the calendar style; QuirkProbe `date-picker-*`, `time-picker-field` | ThemeDemo |
| A browser's columns were bezelled boxes with a saturated full-width selection, GNUstep's arrows, and a heavy horizontal scroller even when every column fit (#58) | WinUI ListView columns on cards: subtle selection with the accent pill, secondary chevrons, the scroller only when there are columns to scroll to; QuirkProbe `browser-*` | ThemeDemo |
| Without gnustep-gui's images, every button and menu item drew as a radio button and the menu bar read "B B Bu B" | named-image checks require an image on both sides (#70) | ScreenshotTool's first MSI on a clean VM |
| The colour well was NeXT's bevel, its swatch square (#26) | WinUI's colour button: the theme's button round a rounded swatch, accent chrome while the colour panel is attached; QuirkProbe `colour-well-*` | ScreenshotTool's toolbar on a clean VM |
| Segmented controls had dividers, a tinted selection and a semibold label; in high contrast the selected label was black on black (#48) | WinUI's Segmented control: one container, a raised selected segment with an accent pill; QuirkProbe `segmented-*` | ThemeDemo |
| Top tabs were pills on a grey strip, and a click on a tab selected nothing: the theme drew them without recording their rects (#49) | WinUI's SelectorBar over a content card, each tab's rect recorded; QuirkProbe `tab-*` | ThemeDemo |
| Layouts made at GNUstep's 12pt didn't fit WinUI's 14px: a label sized for "Miniaturize window" needed 119pt of its 107 (#31) | compact metrics for apps with a main nib or Gorm file, and the `WinUIThemeMetrics` override; QuirkProbe `metrics-choice`, `compact-nib-*` and a `compact` configuration | the parity audit, SystemPreferences |
| Boxes were NeXT's groove with the title centred in it, separators a dark line, and a form's entries a bezel filled white (#27) | grooved, bezelled and lined boxes are WinUI cards with a semibold title above them at the leading edge; separators and line borders are DividerStrokeColorDefault hairlines; form entries are TextBoxes; QuirkProbe `box-*`, `form-entry-textbox` | ThemeDemo |
| High contrast was black on white, or white on black, whatever the contrast theme: Aquatic, Desert, Dusk and Night sky all looked alike, and disabled text was as strong as the rest (#45) | the contrast theme's system colours (GetSysColor): Window, WindowText, Hilight, HilightText, GrayText, ButtonFace and ButtonText; `--contrast-theme` and `WinUIThemeContrastTheme` load one of Windows' own for testing; QuirkProbe `contrast-*` and `dusk` and `desert` configurations | the parity audit (Adwaita row 81) |
| A selected row's text was unreadable in high contrast (the app's controlTextColor, black on the black highlight), and an app that used selectedControlTextColor instead got white on WinUI's near-white selection (#66) | selectedControlTextColor is the primary text colour (HighlightText in high contrast), with the theme's text on accent under its own key; in high contrast a selected table or outline row's text is HighlightText whatever the app set; QuirkProbe `selected-row-text-*` | MarkdownViewer |
| Tool tips were 2pt round their text at the body size (#22) | WinUI's ToolTip: Caption (12px times the text size) inside ToolTipBorderPadding, the tip kept below the pointer as it moves; ThemeDemo's `tooltip` command shows one for a capture; QuirkProbe `tooltip-padding`, `tooltip-font` | the parity audit |
| Gorm made only 22pt controls, so an app couldn't be laid out at WinUI's metrics; a switch from a Gorm file came up disabled (gui 0.32) (#32) | `Palettes/WinUI`: 32pt controls and WinUI's type ramp, fonts archived as the system font; decoded switches enabled; QuirkProbe `switch-decoded-enabled` | the parity audit (Adwaita's `Palettes/Adwaita`) |

## Found in real apps

Run on 2026-10-06 with gnustep-gui 0.32 (MSYS2 clang64), branch
`adwaita-parity-phase-b`.

| Finding | App | Issue |
| --- | --- | --- |
| An alert's OK button is an empty white button in the light palette (the window's default button cell gets white text but no accent fill) | ScreenshotTool | #53 |
| Pop-up buttons and menus close when the click that opened them is released (libs-gui 0.32; also under the default theme) | ThemeDemo | #54 |
| An alert is a borderless band as wide as its parent window, with GNUstep's layout | ScreenshotTool | #23 |
| A nib-based app's 22pt controls drawn with the theme's 32-34pt metrics | SystemPreferences | #31 |
| The application menu (app name, Hide, Services) in a Windows menu bar | ScreenshotTool, SystemPreferences, ThemeDemo | #24 |

## Not yet exercised

- **ObjcMarkdown** now runs here (`MarkdownViewer-dev.ps1`), and its
  MarkdownViewer loads the installed theme (2026-10-06, built from
  `effae64`), but hasn't been reviewed under it. Earlier it didn't build, for
  reasons in that repository, not the theme:
  - `main` (`e71e0ed`): `OMMarkdownRendererMath.m` calls static functions
    that `fe770f5` ("Split OMMarkdownRenderer.m along its topics") left in
    `OMMarkdownRenderer.m` (danjboyd/ObjcMarkdown#55).
  - Before the split (`3df2bf2`): the GNUmakefile's MinGW `mode_t` defines
    (`_MODE_T_`, `_MODE_T_DEFINED`, `__mode_t_defined`) now stop the
    upgraded headers declaring `mode_t` at all (danjboyd/ObjcMarkdown#56).
    Without them, MarkdownViewer fails to link:
    `OMRenderedObjectAttributeName`, `OMTextTableAttributeName` and
    `OMTextTableRowAttributeName` aren't exported from the ObjcMarkdown DLL
    (danjboyd/ObjcMarkdown#57).
- **Gorm** isn't installed on this machine.
- **TinyRetroPad** is a Win32 assembly program, not a GNUstep app.

## Not theme bugs

- **ScreenshotTool opens its launch arguments as files.** Launched with
  `-GSTheme PATH`, it tries to open `-GSTheme` as an image and shows
  "Unable to Open Image". GNUstep's `-Key value` arguments are defaults, not
  documents.
- **ScreenshotTool needs `MSYSTEM=CLANG64`** to find FreeType's headers.
  Its GNUmakefile chooses `/clang64/include/freetype2` from that variable.
