# Changelog

Releases of the WinUI theme for GNUstep. Versions are semver pre-releases
(`0.1.0-alphaN`). Each release has a "Version" commit that sets
`GSThemeVersion` in `WinUIThemeInfo.plist`, and an annotated tag on `main`.
Apps that bundle the theme should pin a tag, not `main`.

## Unreleased

**Measured against WinUI**
- `Compare-Reference.ps1` finds no measurement out of tolerance in light
  or dark (#105):
  - The light window is SolidBackgroundFillColorBase, #F3F3F3, a WinUI
    window's page; it was #F9F9F9.
  - Button, combo box and text box borders lie over the window, not the
    control's fill, as WinUI's do; in dark mode the lighter edge is the
    top.
  - Button titles sit in the middle; they were 2px low.
  - The slider thumb is 22px and centred on the track, around a 10px dot
    (14px under the pointer, 8px pressed).

**Motion** (#105)
- Pressed fills fade in and out over 83ms, as hover fills do: buttons,
  pop-ups, combo boxes, checkboxes and radios.
- A toggle switch's knob slides across and its track cross-fades; a
  checkbox's tick draws in (167ms).
- A menu bar's menus, context menus, pop-up lists and flyouts slide 8pt
  down into place as they fade in; alerts fade in.

**Windows**
- Menus and tool tips are owned by the app's main window and are never
  activated, so the window you were typing in keeps the focus; alerts are
  owned by it and have no taskbar button of their own, as a Windows
  message box hasn't (#30).
- A dialog or panel that can't be resized has no maximize button: libs-
  back's `setmaxsize` toggled it on. Minimize and maximize follow the
  window's style mask and maximum size (#67).

**Fixes**
- A disabled toolbar item's icon stays dimmed when its button redraws on
  its own; it darkened until it looked enabled (#110).
- Reading Windows' "Animation effects" setting overran the stack by three
  bytes, which could stop an app with "stack smashing detected" when a
  hover faded.
- A push button no longer sets its title again each time it's drawn,
  which asked for another redraw every time.

## 0.1.0-alpha2 (2026-10-12)

Menu bar keyboard access, Windows' print and page setup dialogs, popover
flyouts, Windows-style window and alert captions, the theme's own title
bar, and the first motion. Requires gnustep-gui 0.32 or later; the title
bar also needs the carried libs-back below.

**Menus and keyboard**
- **Menu bar from the keyboard:** Alt alone or F10 selects the first
  title and underlines the access keys; arrows, Enter, access keys and Esc
  work as in Win32 menus, and Alt+letter opens a menu unless an item has
  it as its shortcut (#78).
- **Overflow:** a bar too narrow for its titles folds the rest into a
  "..." button whose menu holds them, reachable from the keyboard too
  (#77).

**Dialogs**
- **Print:** Windows' print dialog is seeded from the operation's
  `NSPrintInfo`, and the printer, copies, collation, page range, paper and
  orientation chosen go back into it; Cancel cancels (#69).
- **Page setup:** Windows' page setup dialog, from
  `-[NSApplication runPageLayout:]` and `NSDocument`'s.
- **Fallbacks:** GNUstep's panels stay where Windows' can't do what the
  app asked: an accessory view, or a delegate that filters or checks names
  (#20). `WinUIThemeNativeFileDialogs NO` and `WinUIThemeNativePrintDialogs
  NO` keep them always.
- **File types:** an Open dialog shows every allowed type at once, under
  "All supported files", with a filter per type named from the registry
  (#76).

**Windows**
- **Title bar:** with a libs-back that leaves the caption to the gui
  (`GSBackClientDrawsCaptions`, in `danjboyd/libs-back`'s `carry` branch,
  `carry-0.32.0.1`), the theme draws WinUI's title bar: the app's icon,
  the title and the 46x32 caption buttons, in light, dark and the contrast
  themes. Windows keeps the frame, Snap, Snap Layouts and the system menu.
  A stock libs-back keeps Windows' caption (#83). QuirkProbe
  `client-caption-row`, `client-caption-hit-test`,
  `client-caption-no-system-menu`.
- **Window titles:** a document window is captioned "README.md - App"
  (the app's `CFBundleDisplayName`, then `CFBundleName`), with "*" before
  it while edited, where GNUstep showed "README.md  --  ~/folder" (#33).
  `[window title]` is unchanged. QuirkProbe `window-title-document`,
  `window-title-app-set`.
- **Alerts:** an alert libs-gui left as "Alert", "Critical",
  "Information" or blank is captioned with the app's name (#79). QuirkProbe
  `alert-caption-app-name`.
- **Popover panels:** a panel whose class adopts `GSThemePopoverPanel` is
  drawn as a WinUI flyout, owned by the main window and kept out of the
  taskbar and Alt+Tab (#101, part of #30). The theme declares
  `GSThemeDrawsPopoverPanels`.
- **Window tabs:** redone on the reviewed shared gnustep-window-tabbing
  code (`4cb1b63`) with its three Windows fixes; still off by default
  (`WinUIThemeWindowTabs`, #72).

**Motion**
- **Hover fades:** buttons, pop-ups, combo boxes, checkboxes, radios, text
  boxes and the caption buttons fade their pointer-over fills over WinUI's
  83ms instead of switching (#105).
- **Opening fades:** menus, tool tips and popover flyouts fade in over
  about 167ms.
- Both follow Windows' "Animation effects" setting; the
  `WinUIThemeAnimations` default overrides it. QuirkProbe
  `motion-hover-fades`, `motion-opens-fade-in`.

**Fixes**
- The font panel's browser titles are upright WinUI section labels (#74).
- Split view dividers are WinUI's hairline, without NeXT's dimple (#75).
- Checkboxes with the box after the title draw it there (#80); a small
  checked radio keeps its accent ring (#81).
- Segmented controls, sliders and text fields report a push button's
  height from `-cellSize` (#86).
- Toolbar icons draw at 20pt without resizing the app's images (#89).
- `toolTipColor` and `toolTipTextColor` are the flyout's, as the theme's
  tips (#95).
- An autoresizing table fits beside a scroll bar that keeps its strip (high
  contrast, classic scroll bars) instead of running under it (#103).

**Testing**
- QuirkProbe runs in a home directory of its own, so it neither reads nor
  writes the user's GNUstep defaults; the checks that move the real
  pointer run only with `-Pointer` (#98).
- `Tests/Scripts/Invoke-DialogCheck.ps1` drives the native dialogs.
- `Tests/Scripts/Compare-Reference.ps1` measures a specimens page in the
  WinUI 3 reference app and ThemeDemo, light and dark (#105).

**Known issues**
- **Measured against WinUI** (`Compare-Reference.ps1`): button titles sit
  2px low; button, combo box and text box strokes are lighter in light and
  brighter in dark than WinUI's; the slider thumb is 2px short. The light
  window background is #F9F9F9 where WinUI's page is #F3F3F3.
- **Motion** covers hover fills and opening fades only: no pressed fades,
  switch knob, checkbox tick, flyout slide or dialog entrance yet (#105).
- **Printing:** GNUstep's Windows printing sends PostScript, which most
  printers can't read. `+[NSPageLayout pageLayout]` can't load its panel on
  Windows with gui 0.32.
- **Windows:**
  - The title bar needs `danjboyd/libs-back`'s `carry` build
    (`carry-0.32.0.1`); a stock libs-back keeps Windows' caption.
  - Dialogs and panels get a maximize button, from libs-back (#67).
  - Menus and tool tips still lack an owner and WS_EX_TOOLWINDOW (#30).
  - Window tabs are off by default (#72), and not in the title bar (#83).
- **Fidelity:**
  - In high contrast an open pop-up doesn't mark its selected item (#82).
  - A focused text field hides its placeholder (#102).
  - Redo is Ctrl+Shift+Z, not Ctrl+Y (#92).
- Menu and tool-tip rounding and shadows, and Snap, are unchecked on real
  Windows 11 hardware with a GPU.

## 0.1.0-alpha1 (2026-10-08)

The first tagged release, covering the Adwaita parity work (#50, phases A
to J) and the fixes since. Requires gnustep-gui 0.32 or later.

**Controls**
- **Buttons:** WinUI's Button and AccentButton, with hover, pressed and
  disabled states, an elevation border and regular-weight titles (#38).
  The default button's title shows on its accent fill (#53). No glossy
  highlights (#10). 4px control and 8px overlay corners (#35).
- **Text input:** TextBox chrome with an accent underline on focus (#37).
  AutoSuggestBox search fields (#9). ComboBox pop-ups and combo boxes
  (#40, #8).
- **Toggles:** checkboxes and radios in every palette (#5), and the
  ToggleSwitch (#6).
- **Range controls:** Slider (#41), ProgressBar and ProgressRing (#42),
  steppers (#7).
- **Other controls:** Segmented control (#48), SelectorBar tab views (#49),
  the colour button (#26), DatePicker, TimePicker and CalendarView (#56),
  and level indicators as ProgressBar and RatingControl (#57).
- **Boxes and forms:** NSBox as cards, and NSForm entries as TextBoxes
  (#27).
- **Sizing:** `-sizeToFit` and `-cellSize` follow the theme's drawing (#14).

**Lists, menus and windows**
- **Tables and outlines:** WinUI defaults (#28), a subtle selection with an
  accent pill (#43), selected rows readable in every palette (#66), headers
  drawn once (#3), and outline chevrons placed before the title (#51).
- **Browsers:** NSBrowser columns as WinUI lists (#58).
- **Scroll bars:** WinUI's thin rail, overlaid and auto-hidden (#29). They
  sit on the trailing edge (#4), and draw over content that redraws itself
  (#87).
- **Menus:** MenuFlyout menus (#39), with Windows conventions: no
  application menu, About in Help, Exit in File (#24). Pop-ups stay open
  after the click that opens them (#54). A window made after launch gets
  the menu bar (#1).
- **Toolbars:** WinUI CommandBar-style toolbars (#21).
- **Alerts and tool tips:** alerts laid out as ContentDialog (#23), and
  tool tips as WinUI's ToolTip (#22).
- **Focus:** WinUI's focus visual, shown after keyboard navigation (#36).
- **Images:** template and symbolic images tinted with the text colour
  (#25, #64).

**Appearance and settings**
- **Palette:** WinUI 3 light and dark, with Windows' accent palette (#34).
- **High contrast:** the active Windows contrast theme's system colours
  (#45). `--contrast-theme` loads one for testing.
- **Type:** the Segoe UI Variable type ramp, with Semibold for bold (#44).
  Wrapped labels show all their lines (#15). Text alignment follows
  libs-gui's numbering (#13).
- **Live settings:** theme, accent, contrast and text size follow Windows
  while an app runs (#46).
- **Metrics:** compact metrics for Gorm and nib apps, with
  `WinUIThemeMetrics` to override (#31). A Gorm palette of controls at
  WinUI's sizes is in `Palettes/WinUI` (#32).
- **Window tabs:** Apple's `NSWindow` tabbing API, drawn as WinUI's
  TabView. It's off unless `WinUIThemeWindowTabs` is YES, until checked
  with ObjcMarkdown (#72).

**Under the hood**
- GSTheme override hooks (#12), which reach subclasses through an
  original-method helper (#2). The build works without the gnustep CLI
  (#11).
- QuirkProbe: about 120 pixel and geometry checks in eight configurations
  (#16).
- ThemeDemo: fixes and new surfaces (#18), and scriptable commands for
  captures (#17).
- Licensed LGPL-2.1-or-later (#62).

**Known issues**
- **Dialogs:** open and save dialogs show one file type at a time (#76).
  The print panel drops the printer, copies and page range (#69). The
  native dialogs haven't been verified at run time (#20).
- **Menu bar:** no keyboard access (#78), and menus past a narrow window's
  edge can't be reached (#77).
- **Windows:**
  - Dialogs and panels get a maximize button, from libs-back (#67).
  - Popup windows lack WS_EX_TOOLWINDOW and an owner (#30).
  - Document titles aren't Windows-style (#33).
  - Window tabs are off by default (#72), and not in the title bar (#83).
- **Fidelity:**
  - The font panel's browser titles are upside down (#74).
  - Split view dividers are dark grey with NeXT's dimple (#75).
  - Alerts are captioned "Alert" (#79).
  - Checkboxes with the box after the title draw it first (#80), and a
    small checked radio looks empty (#81).
  - In high contrast an open pop-up doesn't mark its selected item (#82).
  - `cellSize` under-reports some heights (#86).
  - The toolbar resizes the app's own images (#89).
