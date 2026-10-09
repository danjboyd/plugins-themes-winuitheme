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
| Overlay scroll bars often never showed in MarkdownViewer's preview: its canvas, dirty as it scrolled, was drawn after the bar and over it (missing in 3 of 8 scrolls, partial in 1) (#87) | while a bar shows, a scroll view whose content was dirty draws the bars' strips again after libs-gui's pass, content then bar; QuirkProbe `scroller-over-redrawn-content` (which doesn't reproduce the fault: checked in MarkdownViewer, 8 of 8 scrolls) | the ObjcMarkdown session |
| Under compact metrics a checked radio read as unchecked: the 12px dot filled the smaller indicator, leaving a 1px accent ring (#81) | the dot is a share of the indicator (60%, 70% under the pointer, 50% pressed), so 20px keeps WinUI's 12/14/10; QuirkProbe `radio-ring-small` | Gorm |
| Checkboxes with the box after the title (`NSImageRight`, all over Gorm's inspectors) drew the box first, with the right-aligned title far from it (#80) | the title first in the cell's alignment, then the 8px gap and the box at the trailing edge; QuirkProbe `switch-image-right` | Gorm |
| Gorm made only 22pt controls, so an app couldn't be laid out at WinUI's metrics; a switch from a Gorm file came up disabled (gui 0.32) (#32) | `Palettes/WinUI`: 32pt controls and WinUI's type ramp, fonts archived as the system font; decoded switches enabled; QuirkProbe `switch-decoded-enabled` | the parity audit (Adwaita's `Palettes/Adwaita`) |
| Apps had no window tabs: `NSWindow` lacked Apple's tabbing API, so `-addTabbedWindow:ordered:` and `-newWindowForTab:` did nothing and every document was a window of its own (#72) | the shared gnustep-window-tabbing code (vendored in `ThirdParty`), installed from `-activate`, drawn as WinUI's TabView in a 40px row above the content (the title bar stays Windows'); a new tab keeps its group's frame when it gets the menu bar, and a closing selected tab hands its place to its neighbour first (NSApplication took it for the last window and quit); QuirkProbe `window-tabs-api`, `window-tab-*` | issue #72, the shared TabDemo |
| Native Open dialogs showed one file type at a time, the first chosen: ScreenshotTool's Open listed only PNG files, MarkdownViewer's Import only HTML; types were named "JPG files", "JPEG files", "SCREENSHOTTOOL files" (#76) | an Open dialog with several types starts with "All supported files", selected, then one filter per type named from the registry ("PNG File (*.png)", "PNG files" without one), aliases (jpg/jpeg, tif/tiff, htm/html) in one filter; a Save dialog selects its suggested name's type; "All files (*.*)" when the panel allows other types; QuirkProbe `file-dialog-*` (through `+[WinUITheme fileDialogFilters:]`), and the real dialog read back with CB_GETLBTEXT | ScreenshotTool, MarkdownViewer |
| Apps had no window tabs: `NSWindow` lacked Apple's tabbing API, so `-addTabbedWindow:ordered:` and `-newWindowForTab:` did nothing and every document was a window of its own (#72) | the shared gnustep-window-tabbing code (then `2fcb697` in `ThirdParty`, installed from `-activate`; see the next row), drawn as WinUI's TabView in a 40px row above the content (the title bar stays Windows'); a new tab keeps its group's frame when it gets the menu bar, and a closing selected tab hands its place to its neighbour first (NSApplication took it for the last window and quit); QuirkProbe `window-tabs-api`, `window-tab-*` | issue #72, the shared TabDemo |
| On the shared code's first version, Ctrl+Tab and Ctrl+Page Down went to a focused text view (a tab typed, a page scrolled) instead of switching tabs; a tab selected while its group was maximized filled the screen without being maximized (the caption button and double-click didn't restore it, and the restore size was lost) (#72) | the reviewed shared code (`4cb1b63`, in `Source/WindowTabbing`), installed from `-initWithBundle:` before GSTheme records the theme's overrides; its `-close` shows the neighbour first, so the theme's close hook is gone (the menu-bar frame override stays); bar margin and GSWindowTabPreviousHighlighted for the dividers; a selected tab takes the previous one's Windows placement (maximized and the size to restore to); QuirkProbe `window-tab-shortcut-over-text-view`, `window-tab-takes-placement` | MarkdownViewer (ObjcMarkdown main with #108), light and dark |
| Laid out from `-cellSize`, segmented controls, sliders and TextBoxes were squashed: 20pt, 4pt and 26pt beside a 32pt push button, the selected segment's pill and the slider's thumb clipped (#86) | their `-cellSize` heights are a push button's (its margins and a line of the cell's font): 32pt, 27pt compact, more with larger text; a slider's never less than its thumb; QuirkProbe `cell-size-*` | the ScreenshotTool session (Preferences) |
| Toolbar icons changed size after a relayout: ScreenshotTool's Undo and Redo glyphs were 24px launched without a file, 15px with one (the window narrower). The theme resized the app's own item images to 20pt, and libs-gui to 32pt (#89) | the item's image keeps its own size; its button draws a theme-owned image that draws it at WinUI's 20pt icon size (16pt small), tinted as the app's image is; QuirkProbe `toolbar-icon-image-kept`, `toolbar-icon-size` | the ScreenshotTool session |
| The font panel's "Family" and "Typeface" titles were upside down and cut in half, and they and its "Size" label sat on libs-gui's grey bezel (#74) | a text cell drawn by a non-flipped view (a browser's column title) uses string drawing: flipping the context by hand mirrored the glyphs; column titles are WinUI section labels, Body Strong in the secondary text colour on the window, no bezel, at the rows' text edge; QuirkProbe `browser-column-titles` | MarkdownViewer (Preferences, the font panel) |
| Split view dividers were the darkest line in the window (MarkdownViewer's explorer, editor and preview: 2px `#101010` on the dark palette's `#202020`, `#7C7C7C` in light), and thick ones (the font panel's) NeXT's dimple (#75) | thin and thick dividers are a 1px DividerStrokeColorDefault hairline along the divider's middle (WindowText in high contrast), no dimple, the divider's hit area unchanged; `-dividerColor` follows the palette; QuirkProbe `split-view-thin-divider`, `split-view-thick-divider` | MarkdownViewer, the font panel |
| `[NSColor toolTipColor]` and `toolTipTextColor` stayed GNUstep's pale yellow and black, so apps drawing their own hints in them (ScreenshotTool's text hint and "Copied" notice) clashed with the theme's tool tips (#95) | the flyout's background and text colours, as the theme's tips; QuirkProbe `tooltip-system-colors` | ScreenshotTool |
| Window tabs couldn't be dragged or scrolled: tabs past the bar's width were squeezed or cut off, and a tab couldn't be moved or pulled out into a window of its own (#72) | the shared code's phase 2 (`fd064ee`, in `Source/WindowTabbing`): drag to reorder, pull out 32pt to detach or drop on another window's bar, the wheel scrolls tabs that don't fit; the theme draws the dragged tab lifted off the strip over a shadow, a 24px fade into the strip at an end with tabs out of sight (an 8px band and divider in high contrast; WinUI's chevron buttons would need hit areas the bar doesn't have; a click on a close button under the fade selects the tab), and moves the "+" past a drop gap. The shared code now does what the theme worked around: the `-changeWindowHeight:` wrapper replaces the theme's `-addMenuView:` overrides; a selected tab takes the previous one's Windows placement in one `SetWindowPlacement` with its restore rect (`fd064ee`; `ed47a49`'s `ShowWindow(SW_MAXIMIZE)` left it restoring to the maximized size, which the theme's placement fix corrected); the bar is redrawn and laid out again when its window becomes or stops being key or main (`120c501`; a newly selected tab had kept a bar drawn before it was key, without the "+" and with its tabs wider than the bar hit-tests them, which the theme's redraw fixed). The theme's two fixes are gone. Also from Windows: the wheel's tilt direction, the drop target over the tab's own window, a drag whose release never comes ends on the next move (libs-back's Windows server turns a move with no button down into a release first, so there the tab drops where the pointer is; a new press cancels it), and the "+" in every window's bar, not only the key one's. Still open: a tab selected in a group that isn't key (maximized or not; for example its selected tab closed) takes Windows' foreground, not key status, from the key window, as libs-back's `-orderwindow:::` brings a window ordered to the top to the foreground before the shared code reads the foreground to hand back; QuirkProbe `window-tab-scroll-wheel`, `window-tab-scroll-fade`, `window-tab-dragged`, `window-tab-drag-reorder`, `window-tab-drag-detach`, `window-tab-drop-gap`, `window-tab-bar-redraws-on-key`, `window-tab-takes-placement` (now with the restore size), `window-tab-maximized-in-background` (KNOWN for the foreground) | the shared code's phase 2; MarkdownViewer (ObjcMarkdown `e16f9fa`, then `89de855`), light and dark |

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

Run on 2026-10-08 (#19) with gnustep-gui 0.32 and the theme built from
`d0da342` (phase I), passed with `-GSTheme`: MarkdownViewer (the dev build of
ObjcMarkdown `01fe70f`), ScreenshotTool (`origin/main`, `635e656`, built in a
scratch copy) and Gorm 1.5.0 (built, not installed) with and without
`-WinUIThemeMetrics winui` and the WinUI palette, each in light, dark and the
Dusk contrast theme where it applied.

| Finding | App | Issue |
| --- | --- | --- |
| The font panel's browser titles ("Family", "Typeface") are drawn upside down and cut in half, on libs-gui's grey bezel (GNUstep's theme draws them upright) | MarkdownViewer (font panel) | #74 |
| Split view dividers are `controlShadowColor`, `#7C7C7C` in the light palette and darker than the window in the dark one; thick dividers draw NeXT's dimple | MarkdownViewer, font panel | #75 |
| Open dialogs show one file type at a time, the first chosen: ScreenshotTool's Open lists only PNG files (JPEG, TIFF and projects hidden), MarkdownViewer's Import only HTML; types are named like "SCREENSHOTTOOL files" | ScreenshotTool, MarkdownViewer | #76, #20 |
| Menu titles past a narrow window's edge are cut off and can't be reached: Gorm's document window cuts "Windows" and hides Help | Gorm | #77 |
| No keyboard access to the menu bar: Alt, F10 and Alt+F do nothing (keys posted to the window; to confirm with a real keyboard) | MarkdownViewer | #78 |
| Alerts are captioned "Alert" (`NSAlert`) or nothing (`NSRunAlertPanel`), not the app's name | ScreenshotTool, Gorm | #79 |
| Checkboxes with the box after the title (`NSImageRight`, all over Gorm's inspectors) draw the box first, with the title right-aligned away from it | Gorm | #80 |
| Under compact metrics a checked radio looks empty: the 12px dot nearly fills the smaller indicator, leaving a thin accent ring | Gorm | #81 |
| In high contrast an open pop-up doesn't mark its selected item (the light palette's fill and pill are skipped) | MarkdownViewer | #82 |
| A selected outline row's text is white on the Dusk theme's light highlight | MarkdownViewer | #66 |
| Document windows are titled "TableRenderDemo.md  --  ~/git/ObjcMarkdown" | MarkdownViewer, ScreenshotTool | #33 |
| Preferences, Open Location, the inspector and the font panel get a maximize button | MarkdownViewer, Gorm | #67 |
| With `-WinUIThemeMetrics winui`, Gorm's own palettes and inspectors clip ("Radi", "Cus", "Miniaturiz"); as the README says, Gorm itself is meant to run compact | Gorm | by design (#31, #32) |

Worked without findings: MarkdownViewer's main window (toolbar, segmented
Read/Edit/Split, formatting bar, explorer outline, editor and preview) in
light, dark and Dusk; its Preferences tabs, Open Location window and native
Open dialog; ScreenshotTool's toolbar layout, tool popovers, text bar,
Preferences tabs and Save dialogs; Gorm's document window, palette panel and
the WinUI palette, which loads and shows its controls at WinUI's sizes.

## Not yet exercised

- **Menus, context menus and toolbar drop-downs in the apps.** libs-gui's
  menu tracking reads the real pointer (`-mouseLocationOutsideOfEventStream`
  on periodic events), so clicks posted to a window don't open them, and the
  2026-10-08 pass couldn't move the pointer (other tests shared the desktop).
  About panels and commands only in menus went untested; pop-up buttons do
  open, and ThemeDemo's scripts cover menu drawing.
- **Tool tips and hover** in the apps, for the same reason.
- **Dragging from Gorm's palettes:** a posted drag doesn't start one, so
  dropping a control into a real .gorm file is still untried (#32).
- **MarkdownViewer's Print** exports a PDF and opens it in the default
  viewer; it shows no print panel (#69 needs another app).
- **TinyRetroPad** is a Win32 assembly program (MASM and Crinkler), not a
  GNUstep app, so it can't load the theme; at most it's a reference for a
  Notepad-style Win32 menu bar.

## Not theme bugs

- **ScreenshotTool's toolbar icons aren't tinted** (they keep their files'
  `#3D3846`, nearly invisible in the dark palette). The app names each
  symbolic icon "...-symbolic" so themes tint it, but hands the controls
  copies, and `-[NSImage copy]` clears the name in libs-gui. An app fix
  (danjboyd/ScreenshotTool#136).
- **ScreenshotTool's Preferences mixes text sizes:** the app sets 12, 13,
  14 and 18pt fonts itself.
- **ScreenshotTool's Preferences has the menu bar** because it's a window
  that can become main; MarkdownViewer's, a panel, has none.
- **The Dusk run's title bar stayed light:** `--contrast-theme` recolours the
  app without turning on high contrast, so DWM draws the normal caption.

- **ScreenshotTool opens its launch arguments as files.** Launched with
  `-GSTheme PATH`, it tries to open `-GSTheme` as an image and shows
  "Unable to Open Image". GNUstep's `-Key value` arguments are defaults, not
  documents.
- **ScreenshotTool needs `MSYSTEM=CLANG64`** to find FreeType's headers.
  Its GNUmakefile chooses `/clang64/include/freetype2` from that variable.
