# Changelog

Releases of the WinUI theme for GNUstep. Versions are semver pre-releases
(`0.1.0-alphaN`). Each release has a "Version" commit that sets
`GSThemeVersion` in `WinUIThemeInfo.plist`, and an annotated tag on `main`.
Apps that bundle the theme should pin a tag, not `main`.

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
