# Changelog

Releases of the WinUI theme for GNUstep. Versions are semver pre-releases
(`0.1.0-alphaN`). Each release has a "Version" commit that sets
`GSThemeVersion` in `WinUIThemeInfo.plist`, and an annotated tag on `main`.
Apps that bundle the theme should pin a tag, not `main`.

## Unreleased

**Chrome**
- Single-row chrome (#91): an app that declares `GSThemeToolbarInMenuBar`
  in its Info.plist gets its toolbar in the menu bar's row, as Notepad
  and Paint have it:
  - the menu titles first, then icon-only 32pt commands named by tool
    tips;
  - the toolbar folds into its ">>" before the menus fold;
  - the content keeps its size;
  - a user default overrides the app, and a change applies to open
    windows.

  ObjcMarkdown already declares it. QuirkProbe `toolbar-in-menu-bar`,
  `toolbar-in-menu-bar-off`.

**Controls** (#105)
- Sliders draw their tick marks (`-setNumberOfTickMarks:`), as WinUI's
  TickBar; libs-gui kept them but drew none. QuirkProbe `slider-ticks`.
- Progress bars can show a paused or failed task, as WinUI's ProgressBar
  does: `-[NSProgressIndicator setGSThemeState:]` with `@"paused"` or
  `@"error"`. It's a theme-neutral name; ask `-respondsToSelector:`
  first. QuirkProbe `progress-states`.

**Motion** (#105)
- Alerts open as WinUI's ContentDialog does: their content scales from
  105% to 100% about its centre over 250ms, opaque after 83ms. It's a
  snapshot of the drawn content shown scaled over it, removed at the
  end; a layered window's alpha can't scale the window. QuirkProbe
  `motion-dialog-scales`.

**Fixes**
- At a fractional window scale (a 150% monitor on the DPI-aware carried
  backend) a scroll view showed its overlay indicator over content at
  rest after its first display: the clip view's snap to the pixel grid
  was taken for a scroll. QuirkProbe `scroller-hidden-at-rest` in the
  `scaled-150` configuration.

**Testing**
- QuirkProbe sets centre and right alignment as the running gui numbers
  them, so it runs clean on libs-gui master too.

## 0.1.0-alpha5 (2026-10-15)

One fix for alpha4 on a scaled display. Requires gnustep-gui 0.32 or
later. Tested with the carried libs-back `carry-0.32.0.4`
(`danjboyd/libs-back`), as alpha4 was. Apps on alpha4 should move to it,
above all those on the carried, DPI-aware backend.

**Fixes**
- At 125% and 150% on the DPI-aware carried backend, an item after a
  flexible space went into the toolbar's ">>" menu with the row half
  empty (ScreenshotTool's Copy, found by the ScreenshotTool session).
  libs-gui rounds the space's frame to device pixels, a fraction of a
  point past the toolbar's width, and its own fit test then fails; the
  space gives the excess back. alpha3 didn't show it: its process was
  DPI-unaware, so the gui drew at 1.0. QuirkProbe
  `toolbar-flexible-space-scaled`.

## 0.1.0-alpha4 (2026-10-14)

Shadows, per-monitor DPI, Mica and title-bar tabs (which came after
alpha3), the rest of #105's motion and controls, the date picker's gaps,
context menus at the screen's edges, and fixes for scaled displays and a
second monitor found on two-monitor VMs at 125% and 150%. Requires
gnustep-gui 0.32 or later. Tested with the carried libs-back
`carry-0.32.0.4` (`danjboyd/libs-back`), which the title bar, shadows,
per-monitor DPI and the second-monitor fixes need; see "Requirements" in
`README.md`. Apps on alpha3 should move to it with `carry-0.32.0.4`.

**Motion** (#105)
- A radio's dot grows in as it's checked and shrinks away as another
  takes the check (167ms).
- A toggle switch's knob is 14px under the pointer and stretches to
  17x14 while it's held, towards the side it will go; the switch flips
  on a release over it, as WinUI's does (libs-gui flipped it on the
  press).
- List rows' and menu items' pointer-over fills fade in and out over
  83ms, the old row or item fading as the new one comes up.
- An overlay scroll bar eases between the 2px indicator and the
  expanded bar (167ms).
- Menus, pop-up lists and context menus slide in from the side they
  open on: down below the pointer or the menu bar, up when they open
  above it; a submenu slides in from beside its menu; combo box lists
  fade and slide in too.
- QuirkProbe `motion-radio-dot-grows`, `motion-row-hover-fades`,
  `motion-switch-knob-stretches`; menu-item fades checked in ObjcMarkdown
  (the probe's offscreen menus don't redraw highlighted items through
  the theme).

**Controls**
- A combo box's list is WinUI's ComboBox drop-down: a flyout with the
  menu's fill, border, shadow and rounding, as wide as the combo box,
  32px items with their text 12px in, against the field's edge (#105).
- A control that appears under a still pointer shows its pointer-over
  fill at once; one whose window moved or resized under the pointer (a
  caption button as the window restores) loses it (#105). QuirkProbe
  `hover-appears-under-pointer`.
- The combo box list's selected item has the accent pill: the list's
  window never becomes key, so the pill was the inactive grey (#105).
  QuirkProbe `combo-list-selection-accent`.
- Browser rows get the hover fill under the pointer, fading in and out
  over 83ms, as lists do (#58, #105). QuirkProbe `browser-row-hover`.
- Box titles are WinUI's BodyStrong at the body size (14px times the
  text size), and the box lays its title out for it; libs-gui gave every
  box the small system font. An app's own title font stays (#27, #105).
  QuirkProbe `box-title-size`.
- **Date picker** (#56, #105):
  - a picker with a date and a time gives each field its own pointer-over
    and pressed state; they lit together;
  - the flyout's column under the pointer shows LoopingSelector's up and
    down buttons over its ends (34px, an 8px caret), a step each;
  - a calendar-style picker with time elements has a TimePicker field
    under the calendar; only the calendar showed.
  - QuirkProbe `date-picker-field-hover`, `date-picker-flyout-arrows`,
    `date-picker-calendar-time`.
- Toolbar separators are WinUI's AppBarSeparator, a solid 1px divider
  line; libs-gui drew a dashed image (#105). QuirkProbe
  `toolbar-separator`.
- **A Windows text size change reaches open windows**: controls, table
  cells, box titles, tab views and plain text views at the theme's sizes
  take the new ones, tables at the theme's row height the new height, and
  menus resize. Only controls made afterwards changed. Fonts and sizes an
  app chose stay, as do frames (#105). QuirkProbe `live-text-size`.

**Menus**
- **Context menus flip at the screen's edges**, as Windows' do: one that
  would run off the right edge opens to the left of the pointer, one that
  would run off the foot opens upwards, sliding in from that side (#105).
  QuirkProbe `context-menu-edges` (with `-Pointer`).
- **A click on an item with a submenu** opens the submenu and leaves the
  menus open, as on Windows; libs-gui closed every menu. Found with real
  clicks in Gorm's Tools > Palettes (#19). QuirkProbe
  `menu-submenu-click-stays-open` (real clicks, with `-Pointer`).

**Windows**
- **Context menus stay open after a right-click**, as Windows' do, and
  the release picks nothing. They slide into place with their corner
  under the pointer, so the items moved under a pointer that hadn't, and
  Windows sends the release into the menu's window, on its first item;
  either ended tracking, and a real right-click in ObjcMarkdown's editor
  closed the menu 3 times in 5. The opening release is now dropped while
  the pointer stays where it pressed: 10 in 10 stay open. QuirkProbe
  `context-menu-click-stays-open` (real right-clicks, with `-Pointer`).
- **Mica with the theme's title bar:** DWM drew its own caption buttons
  over the theme's (doubled glyphs), because the frame reached into the
  client area from the top; it now reaches in from the bottom. Found with
  real input in ObjcMarkdown. QuirkProbe `mica-chrome` compares the close
  button's ink on the screen with and without Mica.
- Menus, tool tips, pop-up lists, flyouts and the date picker's flyout
  have Windows' shadow, with the carried libs-back (`carry-0.32.0.2`),
  which gives a borderless window a frame for DWM's shadow when the gui
  asks for one (`-setHasShadow:`); DWM also rounds them on Windows 11 with
  a GPU. A stock libs-back ignores the request (#39). QuirkProbe
  `menu-popup-shadow`.
- **Display scaling:** with the carried libs-back (`carry-0.32.0.3`) the
  theme makes apps per-monitor DPI aware (`GSBackDPIAware` in its
  `GSThemeDomain`): on a 125% or 150% display gnustep-gui draws each
  window sharp at its monitor's scale, where Windows stretched it
  blurred, and a window moved to a monitor with another scale takes the
  size Windows suggests. The theme draws in points then, letting the gui
  scale. A stock libs-back stays DPI-unaware (#105). QuirkProbe
  `dpi-per-monitor-aware`.
- **Window tabs in the title bar:** with the carried libs-back, window
  tabs (`WinUIThemeWindowTabs`) sit in the theme's title bar after the
  app's icon, as Notepad's do, with the row beside them left to drag the
  window by; the row takes the strip's colour, and the tabs narrow to fit
  rather than run under the caption buttons. Captions are 40px while tabs
  are on. A stock libs-back keeps the bar above the content (#83).
  QuirkProbe `window-tab-bar`, `window-tab-title-bar-hit-test`.
- **Mica:** on Windows 11 22H2 and later, main and document windows show
  Windows' Mica backdrop through the title bar, menu bar and toolbar,
  which leave their background transparent, with the content solid, as
  Windows 11's apps do; caption, menu bar and toolbar hover fills are
  WinUI's translucent ones over it. Not panels, dialogs or alerts, high
  contrast or with transparency effects off; `WinUIThemeMica NO` turns it
  off. Works with a stock libs-back (#47). QuirkProbe `mica-chrome`.
- **Tool tips on a scaled display** hold their text: libs-gui gives the
  tip's size in points as its frame, in pixels, so the padded tip was
  too small by the scale and clipped its text. QuirkProbe
  `tooltip-scaled`.
- **The theme's title bar on a scaled display** (found on a two-monitor
  VM at 125% and 150%): the menu bar and content started half a caption
  too high, over the title and caption buttons, and the top of the menu
  titles dragged the window. The caption's height (points) now counts in
  the window's offsets (pixels) at the screen's scale, and the content
  meets the caption's foot exactly (#105). QuirkProbe
  `client-caption-row-scaled`.
- **Flyouts on a scaled display:** the date picker's flyout opened about
  110px too high at 150%, and a combo box's list showed 2 of its 3 rows;
  both are now placed in pixels from their size in points (#105).
  QuirkProbe `date-picker-flyout-scaled`, `combo-list-scaled`.
- **A window that fills the screen keeps its caption** when it gets a
  menu bar or toolbar: libs-gui sized the decoration for a taller window
  that the screen didn't allow, so the caption lay above the window and a
  gap opened above the content (ThemeDemo at 125% and 150%, any window
  as tall as the screen at 100%). QuirkProbe
  `decoration-fits-tall-window`.
- **A second monitor:**
  - tool tips open on the monitor the pointer is on; libs-gui kept them
    on the main screen;
  - with the carried libs-back `carry-0.32.0.4`, each monitor's frame is
    flipped against the primary's height, as window coordinates are, so
    on a monitor shorter than the primary (or not level with it) windows
    find their screen and its scale; menus and pop-up lists drew at the
    primary's scale there;
  - `carry-0.32.0.4` also keeps a window the gui moved to another monitor
    at the size the gui gave it, where `WM_DPICHANGED` shrank reused menu
    panels by the ratio of the scales (menu text cut off);
  - and turns hinted glyph metrics off for a DPI-aware app, as libs-back
    already did under `GSScaleFactor`: text views at 125% and 150%
    spaced some words unevenly.

**Testing**
- `Invoke-QuirkProbe.ps1 -Backend DIR` and `Invoke-ThemeDemoScript.ps1
  -Backend DIR` run on a libs-back bundle of one's choosing, such as the
  carry build, copied into the test home, without replacing MSYS2's.
- Checked on temporary OCI Windows Server 2025 VMs with two monitors
  (1920x1080 at 150% and 1280x800 at 125%): drags and Win+Shift+Arrow
  between them rescale windows sharply; the caption, menus, pop-up
  lists, combo lists, date flyouts, tool tips and text views are right
  on both.

**Known issues**
- **A second monitor:** the first menu shown after launch can have a
  dark strip on its right until it opens again; a pop-up list on a
  monitor at another scale from the one it last opened on is narrower
  than its button; a window grows by a few pixels each time it moves to
  another monitor and back.
- **Minimum and maximum sizes** an app gives in points
  (`-setMinSize:`) are taken as pixels on a scaled display, as
  gnustep-gui treats frame sizes; `-setContentMinSize:` is scaled.
- **Motion:** alerts fade but don't scale as WinUI's ContentDialog does.
- **Unchecked on a GPU:** Mica's blur, and DWM's rounding of menus, tool
  tips and flyouts.
- Window tabs stay off by default (#72); paused and error progress and
  slider tick marks wait on an API decision.

## 0.1.0-alpha3 (2026-10-13)

The fix for alpha2's stack overrun, measured agreement with WinUI 3's
controls, more motion, and menus that never take the focus. Every app
built with alpha2 should move to it. Requires gnustep-gui 0.32 or later.
Tested with the carried libs-back `carry-0.32.0.1`
(`danjboyd/libs-back`), which the title bar needs; see "Requirements" in
`README.md`.

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

**Menus**
- Redo shows Ctrl+Y, as on Windows, and Ctrl+Y redoes; the app's
  Ctrl+Shift+Z still does. Left alone when something else has Ctrl+Y
  (#92).
- In high contrast an open pop-up marks its selected item in Highlight,
  with its title and pill in HighlightText, as WinUI's ComboBox does
  (#82).
- A focused, empty text field keeps its placeholder behind the caret until
  the first character, and shows it again when the text is deleted, as
  WinUI's TextBox does (#102).

**Fixes**
- A disabled toolbar item's icon stays dimmed when its button redraws on
  its own; it darkened until it looked enabled (#110).
- Reading Windows' "Animation effects" setting overran the stack by three
  bytes, which could stop an app with "stack smashing detected" when a
  hover faded.
- A push button no longer sets its title again each time it's drawn,
  which asked for another redraw every time.

**Documentation**
- `README.md` has a "Requirements" section: gnustep-gui 0.32, and the
  carried libs-back, what needs it and what a stock libs-back does
  instead.

**Known issues**
- **Motion:** no list-row or menu-item hover fades, radio dot, pressed
  switch stretch, side-opening flyouts, scroll bar rail transition,
  indeterminate ProgressBar or ProgressRing yet; alerts fade but don't
  scale (#105).
- **Menus** never take activation (#30); a real click on a menu item is
  unchecked here, as only synthesized and pointer-moving checks ran.
- **Windows:**
  - The title bar needs the carried libs-back; a stock libs-back keeps
    Windows' caption.
  - libs-back's windows are DPI-unaware, so a window doesn't rescale on a
    monitor with a different scale.
  - No Mica backdrop (#47).
  - Window tabs are off by default (#72), and not in the title bar (#83).
- **Printing:** GNUstep's Windows printing sends PostScript, which most
  printers can't read. `+[NSPageLayout pageLayout]` can't load its panel on
  Windows with gui 0.32.
- Menu and tool-tip rounding and shadows, and Snap, are unchecked on real
  Windows 11 hardware with a GPU.

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
