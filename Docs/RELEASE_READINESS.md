# Release Readiness: the gate for 0.1.0-beta1

The theme has shipped as `0.1.0-alphaN` pre-releases since 2026-10-08.
`0.1.0-beta1` is the first release apps can treat as stable-ish: its
settings and APIs are frozen until 0.2, its known gaps are written down
as non-goals or tracked issues, and two shipping apps have run on the
same release for a while without a theme regression.

This replaces the April phase-12 checklist (frozen screenshot corpora,
ObjcMarkdown going green), which no longer described the real gate.

## The gate

Each item is done when its evidence exists. Status as of 2026-10-15
(0.1.0-alpha8).

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
| `WinUIThemeColorScheme`, `WinUIThemePreferDark`/`Light`, `WinUIThemeHighContrast`, `WinUIThemeAccentColorHex`, `WinUIThemeTextScaleFactor`, `WinUIThemeDesktopScaleFactor`, the font and reduced-transparency overrides | user default | test and override hooks; decide which are public |

APIs apps call (theme-neutral names, shared with the Adwaita theme where
noted; apps ask `-respondsToSelector:` first):

| API | Since | Notes |
| --- | --- | --- |
| `-[NSProgressIndicator setGSThemeState:]` (`paused`, `error`) | alpha6 | |
| `-[NSButton setGSThemeStyle:]` (`accent`), also on `NSButtonCell` | alpha7 | Adwaita too |
| The default button yielding the accent to an `accent` button | alpha8 | a rule, not an API; Adwaita too |
| `GSThemePopoverPanel` (protocol), `GSThemeDrawsPopoverPanels` | alpha1 | |

- [ ] The owner confirms the tables (and which test hooks are public).
- [ ] Every frozen name is in the README.

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
