# Release Readiness: the gate for 0.1.0-beta1

The theme has shipped as `0.1.0-alphaN` pre-releases since 2026-10-08.
`0.1.0-beta1` is the first release apps can treat as stable-ish: its
settings and APIs are frozen until 0.2, its known gaps are written down
as non-goals or tracked issues, and two shipping apps have run on the
same release for a while without a theme regression.

This replaces the April phase-12 checklist (frozen screenshot corpora,
ObjcMarkdown going green), which no longer described the real gate.

## The gate

Each item is done when its evidence exists. Status as of 2026-10-16
(0.1.0-alpha9).

### 1. The backend story is settled

The title bar, shadows, per-monitor DPI and the second-monitor fixes need
the carried libs-back (`danjboyd/libs-back`, `carry-0.32.0.N`).

- [ ] Decide, with the owner, whether beta1 requires the carried backend
      (documented as such, apps ship it) or waits for GNUstep to take the
      changes.
- [ ] The four libs-back topic branches reviewed by the owner and posted
      upstream (GCC builds done; the X11 build of `CairoFontInfo.m` owed),
      and gnustep/libs-back#246's FSF assignment question settled.
- [x] The theme works, with documented differences, on a stock libs-back
      (QuirkProbe runs every configuration on both).

### 2. Settings and APIs are frozen

Frozen means: no renames or meaning changes until 0.2, and each is in
the README. Diagnostic and test-only settings are marked as such and
are not covered.

User defaults and Info.plist keys:

| Name | Where | Status |
| --- | --- | --- |
| `WinUIThemeWindowTabs` | user default | on by default since alpha7 |
| `WinUIThemeMenuStyle` (`menubar`, `more`) | Info.plist, user default | alpha6 |
| `GSThemeToolbarInMenuBar` | Info.plist, user default | alpha6; theme-neutral |
| `WinUIThemeMetrics` (`winui`, `compact`) | Info.plist, user default | |
| `WinUIThemeMica` | user default | |
| `WinUIThemeAnimations` | user default | |
| `WinUIThemeOverlayScrollbars` | user default | |
| `WinUIThemeNativeFileDialogs`, `WinUIThemeNativePrintDialogs` | user default | |
| `WinUIThemeContrastTheme` | user default, `--contrast-theme` | for checking an app |
| `WinUIThemeTraceScrollers` | user default | diagnostic, not frozen |
| `WinUIThemeDisableWindowIntegration` | user default | diagnostic, not frozen |
| `WinUIThemeColorScheme`, `WinUIThemePreferDark`/`Light`, `WinUIThemeHighContrast`, `WinUIThemeAccentColorHex`, `WinUIThemeTextScaleFactor`, `WinUIThemeDesktopScaleFactor`, `WinUIThemeReducedTransparency`, `WinUIThemeInterfaceFontName`/`Size`, `WinUIThemeMonospaceFontName`/`Size` | user default | test and override hooks; decide which are public |

APIs apps call (theme-neutral names, shared with the Adwaita theme where
noted; apps ask `-respondsToSelector:` first):

| API | Since | Notes |
| --- | --- | --- |
| `-[NSProgressIndicator setGSThemeState:]` (`paused`, `error`) | alpha6 | |
| `-[NSButton setGSThemeStyle:]` (`accent`), also on `NSButtonCell` | alpha7 | Adwaita too |
| The default button yielding the accent to an `accent` button | alpha8 | a rule, not an API; Adwaita too |
| `GSThemePopoverPanel` (protocol), `GSThemeDrawsPopoverPanels` | alpha1 | |

- [ ] The owner confirms the tables (and which test hooks are public).
- [x] Every frozen name is in the README: its "Settings" section lists
      every key the theme reads (2026-10-16), the hooks marked as such.

### 3. Real hardware and real input

This VM has no GPU, one monitor, and blocks SendInput mouse buttons.

- [ ] One session on Windows 11 with a GPU: menu and tool tip rounding
      and shadows, Mica's blur, Snap with Win+arrow, window tabs.
- [x] Two monitors at 125% and 150% (OCI VMs, alpha4).
- [x] Real input at 125% and 150% in Markdown Viewer (its VM lease,
      alpha7-alpha8: tabs, "+", tab close, typing, Ctrl+N/W).
- [ ] Snap on a tabbed window and repeated real clicks on a new tab's
      close button (asked of Markdown Viewer's lease, 2026-10-15).
- [ ] Live settings done for real: light/dark, the accent and a contrast
      theme switched in Windows Settings while an app runs (#105).

### 4. A soak

- [ ] ScreenshotTool and Markdown Viewer shipped on the same theme
      release, with the carried backend it was tested with.
- [ ] Two weeks on that release with no theme regression reported by
      either app's session or the owner; any regression resets the clock.

### 5. Tests and measurements

- [x] QuirkProbe: all configurations on the carried and stock backends,
      0 failures, at each release; every fix has a check that fails on
      the build before it.
- [x] `Compare-Reference.ps1`: 0 out of tolerance against the WinUI 3
      reference app in light and dark.
- [ ] The reference app gains the real Toolkit `Segmented` and WinUI's
      `SelectorBar`, and the segmented control is measured against the
      one the owner picks.
- [ ] Text width measured against the reference (#105), as Adwaita does
      against GTK.
- [ ] CI: at least a build of the theme and QuirkProbe on every push
      (today they run by hand on this VM).

### 6. Known gaps written down

- [ ] Every item under "Known gaps in finished work" in `HANDOFF.md` is
      either fixed, a tracked issue, or listed below as a non-goal.

Non-goals for beta1 (proposed):
- Recreating the Settings app shell or NavigationView.
- A tab overview, and dragging tabs between windows (the shared tabbing
  code's phase 2, #97, can come after).
- A single overflow merging the toolbar's ">>" with the "..." menu.

**Proposed triage of `HANDOFF.md`'s known gaps** (2026-10-16, for the
owner to confirm; no issues filed yet). "Gate 3" means the GPU and
real-input session above covers it.

Already fixed (the handoff's text is stale):
- Window tabs above the content: in the title bar since #118.
- Alerts only fade: ContentDialog's scale shipped in alpha6 (#125).
- No paused or error progress, no slider ticks: alpha6 (#125).
- Hover when the pointer is already inside a control: #120.
- A toolbar's colour well as a square swatch: alpha9 (#151).
- `setmaxsize` toggling the maximize box: fixed in `carry-0.32.0.2`; the
  theme's correction stays for a stock libs-back.

Proposed issues (real gaps the theme could close):
1. Under `WinUIThemeMenuStyle = more`, a window without a toolbar keeps
   a whole row for the "..." button (#130).
2. Title-bar tabs narrow to 40px, then run past the bar; WinUI scrolls
   them. And the "+" button's hit area covers the empty strip after the
   tabs, which Windows makes a drag area (#72).
3. The menu row's height is 0 while the "..." is in the title bar, so a
   menu removed after the "..." moved leaves the window a row off.
4. The second-monitor edges: the first menu's dark strip, a pop-up list
   sized at the previous monitor's scale, and a window growing about
   6px per round trip (`AdjustWindowRectEx` at the system DPI). Needs
   two monitors to check (OCI).
5. `motion-row-hover-fades` shows no hover fill at 150% in the probe,
   cause not found.
6. The date flyout's up and down buttons step once per click; WinUI's
   repeat while held (#56).
7. Caption-size text (12px) is 2.5% narrower than WinUI's: WinUI uses
   Segoe UI Variable's optical size axis, the theme its Text instance at
   every size. Using the Small instance at 12px would also widen every
   compact-metrics (Gorm and nib) app's text, so it needs a decision.
8. Dropping a palette control into a real .gorm file and reopening it
   (#32, part of #19's real-app pass).

Limitations, documented and not planned for beta1:
- The "..." flyout's items are copies made each time it opens (as the
  narrow bar's overflow menu's are, #77); compare menus by title.
- The theme's opaque blended fills on the menu bar and toolbar are tuned
  for the solid window colour, not for Mica.
- Switches flip on release (WinUI's), in the theme's own tracking loop.
- A hover is dropped when the window moved since the pointer entered
  and Windows says the pointer isn't over the view.
- High contrast's pressed buttons change at once; submenus don't slide.
- A rounded control redrawn with `-setNeedsDisplay:` has its corners a
  shade darker than `-display` gives (libs-gui draws it twice; invisible).
- The focused placeholder only for fields the theme fills (#102).
- Keyboard stepping of a date field without the flyout, and seconds:
  WinUI's DatePicker and TimePicker have neither.
- Browser columns as cards 8pt apart, as the reference app has them.
- A box title keeps an app's own font; a Gorm box laid out for the small
  font gives its content a few points less.
- Selected rows keep an app's own text colours (they read on WinUI's
  subtle fill); high contrast forces HighlightText.
- Tool tip padding relies on libs-gui's text-plus-4pt tip frame.
- An app that compiles the shared tabbing code itself crashes under the
  theme (two copies of each class); apps rely on the theme's.
- The theme's `-[NSWindow close]` hook stays after a theme switch.
- `-setMinSize:` in points is taken as pixels on a scaled display:
  gnustep-gui's frame sizes are device pixels (`-setContentMinSize:` is
  scaled). A libs-gui question.
- The probe's offscreen menu views draw no items, and the full matrix's
  pointer checks flake when other windows are in the way: test notes,
  not gaps.

Covered by gate 3 (GPU, real input, live settings): menu and tool tip
rounding and shadows; Mica's blur; Snap; real clicks on menus (#30),
title-bar tabs and a new tab's close button; real tool tip hover; the
GetSysColor path and switching contrast themes live; Ctrl+Tab and middle
click on tabs; the wrong cursor once on a first new tab.

### 7. Shared code where it belongs

- [ ] The theme's replacements of the shared tabbing code's
      `-isTabBarVisible`, `-_toggleTabBar` and `-_switchToWindow:` (#133,
      #137) moved into `danjboyd/gnustep-window-tabbing`, reviewed by the
      owner, and vendored back.

## Release process

Unchanged from the alphas (approved 2026-10-08): a "Version X" commit
setting `GSThemeVersion` and adding the release's `CHANGELOG.md` section,
an annotated tag on `main`, a GitHub pre-release (a release, for beta1
and later) with the CLANG64 bundle zip built from the tagged tree, its
checksum checked by downloading it back; apps pin a tag.
