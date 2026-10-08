# WinUI theme vs Adwaita theme: parity matrix

A comparison made on 2026-10-08 by the Adwaita theme's session
(danjboyd/plugins-themes-Adwaita, `main` at `38668b8`, 0.1.0-alpha7) of this
theme at `b3a6b20`. It was made read-only, from this repository's sources,
docs and issues, without running it. It's kept here as input to the release
plan. The order of the work is the owner's decision. Each row names how
Adwaita did the piece, as a pointer to its repository.

At the time: this theme had 91 commits since 2026-04-06, no tags, 54 closed
and 21 open issues, and QuirkProbe ran 116 distinct checks in 8
configurations. Adwaita had about 150 checks in 7 configurations, and 9
other check targets.

## Prioritised gaps

**Release blockers**

1. **Releases.** There are no tags and no changelog, and ObjcMarkdown's MSI
   takes `main` unpinned. Recommended:
   - semver pre-release tags, like Adwaita's (0.1.0-alpha1...);
   - `GSThemeVersion` bumped in `WinUIThemeInfo.plist` in a "Version X"
     commit, with an annotated tag per release;
   - release notes listing the issues fixed;
   - apps pinning a tag rather than `main`;
   - optionally, a zip or MSI of the theme bundle attached to each release.
2. **Print dialog (#69).** It drops the printer, copies and page range, and
   a cancel falls into GNUstep's panel. Model: Adwaita's
   `Source/Adapters/GnomeThemePrintDialog.m`, which carries NSPrintInfo to
   and from the dialog's settings, maps cancel to `NSCancelButton`, and
   renders the job to PDF and hands it over. Its `make check-print-dialog`
   tests this. libs-gui's did-run callback passes the wrong arguments
   (Adwaita's draft upstream issue 14).
3. **Native dialogs.** They're unverified at run time (#20), and open
   dialogs filter one type at a time (#76). Add a scripted dialog check.
   Model: Adwaita's check-file-chooser (NSDocument's types become the
   filters, with fallbacks for accessory views and delegate filtering).
4. **Menu bar.** It has no keyboard access (#78): Windows users expect
   Alt, F10 and Alt+letter. Menus past a narrow window's edge are cut off
   (#77). Model for the overflow: Adwaita #25:
   - an overflow button;
   - the folded items get zero rects;
   - key equivalents and validation keep working, because the main menu
     isn't modified;
   - the overflow menu is a fresh copy each time it opens.
5. **Test isolation.** Give `Invoke-QuirkProbe.ps1` scratch GNUstep
   defaults. Model: Adwaita's `Tests/Scripts/run-quirk-probe.sh` (commit
   `5131af2`), a private `GNUstep.conf` with an empty
   `GNUSTEP_USER_DEFAULTS_DIR`. Adwaita's probe was found writing into the
   owner's real defaults. Also make the checks that move the pointer opt-in
   on the shared desktop.

**Parity**

6. **Measured reference checks.** Sample the WinUI 3 reference app's
   pixels (PrintWindow) and assert the theme against them: palette fills,
   control heights, radii, text width. Model: Adwaita's `text-width`,
   `control-colors-*` and `window-tabs-*` checks, measured from its GTK
   reference apps.
7. **Document titles (#33).** "name - App", an edited marker, kept up to
   date. Model: Adwaita #31 and `5b372f3`.
8. **Window ownership and styles (#30).** Menus and tool tips need
   `WS_EX_TOOLWINDOW`/`WS_EX_NOACTIVATE` and owner windows, so they stay
   out of Alt+Tab and the taskbar. Model: Adwaita #15 and its libs-back
   patch 0002, which sets window types by role and sets them again at map
   time.
9. **Per-window metrics for nib windows in code-built apps.** Model:
   Adwaita #24 (`GnomeThemeNibMetrics.m`). It hooks NSNib's instantiation,
   marks what it makes, and resolves a control's window when a metric is
   asked. `check-nib-metrics` tests it with a real .gorm file.
10. **Window tabs on by default.** Finish the redo onto the shared code at
    `4cb1b63` (installed from `-initWithBundle:`), check it with
    ObjcMarkdown, then drop the `WinUIThemeWindowTabs` gate.
11. **Open fidelity bugs:** #74, #75, #79, #80, #81, #82, #86, #89.
12. **README for users.**
    - A side-by-side gallery (GNUstep's theme vs WinUI, light and dark),
      with a record of how each shot is retaken.
    - How to install and select the theme.
    - Known issues.
    - Refresh `RELEASE_READINESS.md` (dated 2026-04).
    - Tick #50's checklist: #17, #22, #27, #32 and #45 are closed but
      unticked.

**Nice to have:**
- Mica (#47).
- Title-bar tabs (#83, which needs libs-back custom captions).
- CI for the MSYS2 build.
- A sign-off log and review packets for upstream items. Model: Adwaita's
  `Docs/UPSTREAM_SIGNOFF.md` and `Docs/upstream-patches/review/`.

**Where WinUI is ahead** (Adwaita will adopt these):
- the real Windows contrast themes in tests, and `--contrast-theme`;
- a 150% scale configuration;
- NSDatePicker, calendar, level indicator and NSBox cards drawn natively;
- the `--mode`, `--scale` and `--contrast-theme` switches;
- DWM corners and dark captions without a patched backend.

**Proposed order** (the Adwaita session's, for the owner to decide):
1. Test isolation (5).
2. Finish the window tabs (10).
3. Print (#69) and file dialogs (#76, #20).
4. Menus (#78, #77).
5. A first tagged pre-release, with release notes and the apps pinned to
   it.
6. Then measured reference checks, #33, #30, per-window metrics, the
   fidelity bugs and the README.

## 1. Look

| Capability | Adwaita | WinUI | Gap |
| --- | --- | --- | --- |
| Native reference app | Reference/AdwaitaDemo (GTK 4, same page ids), AdwaitaTabBar, TableCard; values measured from the reference's pixels and asserted by QuirkProbe | Reference/WinUI3ReferenceApp (dotnet 8, WindowsAppSDK 1.6, same page ids); values from generic.xaml, the theme dictionaries and Fluent docs; compared by eye; the probe asserts constants | measured checks against the reference |
| Palette, light and dark | libadwaita 1.7 tokens as "fg at N% over window" | WinUI 3 palette, accent shades (#34) | none |
| High contrast | libadwaita's high-contrast outlines | the active Windows contrast theme via GetSysColor (#45); `--contrast-theme` | WinUI ahead |
| Buttons, default, disabled | yes, measured | Button/AccentButton and states (#38, #53) | none |
| Entries, search, combo | yes | TextBox underline, AutoSuggestBox, ComboBox (#37, #40, #8, #9) | none |
| Check, radio, switch | 2px ring unchecked, NSSwitch | yes (#5, #6); #80 and #81 open | 2 open |
| Slider, stepper, segmented, progress | yes | yes (#41, #7, #48, #42); #86 cellSize under-reports heights | 1 open |
| Tabs (NSTabView) | GNOME view-switcher tabs | SelectorBar (#49) | none |
| Tables, outlines, browsers | view colour, selection at 25% accent | list pill (#43), browser (#58); #74 column titles upside down | 1 open |
| Scroll views, overlay scrollers | overlay, fade, frame; redraw-order fix (its #47) | thin rail, auto-hide (#29); redraw fix (#87) | none (a shared upstream draft) |
| Split view dividers | GNOME hairline | #75 dark line and NeXT's dimple | open |
| Menus, popovers | popover menus, shortcuts, inline rows, overflow (its #25) | MenuFlyout (#39), shortcuts; #77 overflow cut off; #78 no keyboard access | 2 open |
| Tool tips | translucent, measured | WinUI ToolTip (#22) | none |
| Alerts, dialogs | attached, no bar | ContentDialog (#23); #79 captioned "Alert" or empty | 1 open |
| Symbolic icon tinting | by name (-symbolic, Template) | yes (#25); the same name-matching weakness (ScreenshotTool#136) | none |
| Toolbar | header-bar toolbar, overflow | yes (#21); #89 resizes the app's own images | 1 open |
| Focus rings | yes | yes (#36) | none |
| Colour well, date picker, level indicator, box and form | colour well; the date picker isn't drawn specially | colour well (#26), DatePicker and CalendarView (#56), level indicator (#57), cards (#27) | WinUI ahead |
| Window backdrop | not applicable | #47 Mica (investigate) | nice to have |

## 2. Behaviour and integration

| Capability | Adwaita | WinUI | Windows equivalent | Gap |
| --- | --- | --- | --- | --- |
| File dialogs | GNOME portal chooser, NSDocument types, fallbacks; check-file-chooser (28 checks against a stand-in portal) | IFileDialog; #20 never verified at run time; #76 one type at a time | IFileDialog | verify, filters |
| Print dialog | portal, NSPrintInfo both ways, PDF job; check-print-dialog (11 checks) | PrintDlgW; #69 drops printer, copies and range | PrintDlgEx / IPrintDialog | blocks printing |
| Page setup | GNUstep's panel | PageSetupDlgW | PageSetupDlgW | none |
| Live settings | GLib main context in the run loop; check-live-settings | WM_SETTINGCHANGE listener (#46) | WM_SETTINGCHANGE | none |
| Text scaling | text-scaling-factor, compact exempt | text scale (#46), large-text configuration | Accessibility text size | none |
| DPI, scale | GSScaleFactor | metrics scaled by the desktop factor; light-150 configuration | per-monitor DPI | WinUI ahead (libs-back is DPI-unaware) |
| Fonts | Cantarell, hinting; text width within 1.4% of GTK | Segoe UI Variable, type ramp (#44); no ClearType handling found | ClearType | measure text width against the reference |
| Per-window metrics for nib windows | nib windows compact in code-built apps | per app only (#31) | none | missing |
| Context menus at the pointer | GTK 4 placement, kept on screen | menu tracking; no probe check found | at the pointer, flipped at edges | add a check |
| Window types, ownership | window types for menus, tool tips, drag images, dialogs | #30 open: owner, WS_EX_TOOLWINDOW/NOACTIVATE | owner window and extended styles | open |
| Alerts attached to the window | yes | modal to the window (#23) | owner and modal | none |
| Document title, edited marker | file name, folder in the tool tip, dot | #33 open: "name -- ~/dir" | "name - App", a dot or asterisk | open |
| Maximize on dialogs | not applicable | #67 libs-back sets WS_MAXIMIZEBOX | none on dialogs | upstream patch |
| Window tabs | AdwTabBar, shared code `4cb1b63`, drag and scroll in progress | TabView drawing, off by default; redo onto `4cb1b63`; title-bar tabs (#83) need libs-back | Windows 11 title-bar tabs | redo, default on |
| Keyboard access | GNUstep's | #78 no Alt, F10 or Alt+letter | access keys, F10 | open |
| Header bar | GNUstep-drawn header bar | native caption with DWM dark caption and corners | DWM caption | none (right for the platform) |

## 3. Engineering and process

| Area | Adwaita | WinUI | Gap |
| --- | --- | --- | --- |
| Versioned releases | semver pre-release tags, GSThemeVersion in the plist, "Version X" commits | no tags or changelog; ships only in apps' MSIs (ObjcMarkdown unpinned, ScreenshotTool pinned) | nothing to pin or roll back |
| Packaging | packages the owner builds for his own use | none for the theme | a standalone artifact |
| Release docs | a local release checklist | `RELEASE_READINESS.md`, dated 2026-04-03, stale | refresh |
| README showcase | side-by-side gallery with a dark row; Features, Install and use, Settings, Known issues | build-centred; an old "Current Status"; good Settings, High Contrast and Window Tabs sections | gallery, install and select |
| Selecting the theme | `defaults write NSGlobalDomain GSTheme Adwaita`, or per app | install scripts; selection not in the README | add |
| Improvements log | `Docs/IMPROVEMENTS.md` | `Docs/IMPROVEMENTS.md` | none |
| Handoff | `Docs/HANDOFF_OPEN_ISSUES.md` | `Docs/HANDOFF.md`, `PARITY_AUDIT.md`, #50 (checklist partly stale) | tick #50 |
| Test configurations | 7 probe configurations, plus window-manager, file chooser, print, nib metrics, text scaling, live settings, menu timing, scroller drag and context menu suites | 8 configurations (light, dark, high contrast, 150%, large text, compact, Dusk, Desert) | WinUI ahead on scale and contrast themes |
| Test isolation | private Xvfb, private D-Bus, scratch defaults and settings | the owner's shared desktop; the probe moves the real pointer unless `-NoPointer`; no scratch defaults, so the probe reads (and may write) the owner's GNUstep defaults | risk |
| CI | none | none | both; the MSYS2 build could run in CI |
| Upstream process | `UPSTREAM_POLICY.md`, a sign-off log, review packets, GCC syntax checks | the process in `HANDOFF.md`; no sign-off log; libs-back#246 sent | a sign-off log |
| GCC | syntax checks; a full GCC and GNU libobjc stack for the tabbing code | syntax only (no GCC-built gnustep-base on Windows) | upstream items need a Linux GCC run, which the Adwaita session offered |
| LGPL headers | all sources | all sources | none |
