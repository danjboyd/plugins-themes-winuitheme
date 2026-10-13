# Handoff: Adwaita parity work

State as of 2026-10-13 (morning), for picking the work up in a fresh session. The goal
(tracking issue #50): unmodified GNUstep apps look like first-rate WinUI 3
apps under this theme, at parity with what the Adwaita theme
(`C:\Users\Support\git\plugins-themes-Adwaita`) does for GNOME. The audit
behind it is `Docs/PARITY_AUDIT.md`; fixes and real-app findings are listed
in `Docs/IMPROVEMENTS.md`.

## Ground rules

- **Git authorship:** commits as `Daniel Boyd <danieljboyd@icloud.com>`
  (`AGENTS.md`).
- **GitHub account:** `gh` as `danjboyd`. If several accounts are logged in,
  run `gh auth switch -u danjboyd` and check with `gh auth status`.
- **Upstream GNUstep patches** follow a formal process:
  1. Review GNUstep's official AI-contributed patch policy and follow it.
  2. Confirm the patch works with GCC, not just clang.
  3. The owner personally reviews every patch before it's posted.

  None have been needed so far. Where libs-gui falls short, the theme works
  around it, as with gui 0.32's push-in offset and search field clearing.
- **Commits:**
  - One commit per issue.
  - `Fixes #N` lines.
  - The trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **PR bodies** end with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- **Pushing and opening PRs** wait until the owner asks.
- **Stacked branches:** never `gh pr merge --delete-branch` on a branch that
  other PRs are based on. GitHub closes them, and reopening them needs the
  owner. Merge without deleting, then retarget.
- **Real input** (SendInput clicks and keys) is blocked by this session's
  permission check unless the owner allows it. Probe checks that move the
  pointer (`-Pointer`) are allowed. Synthesized NSEvents don't go through
  Windows' input queue, so they don't stand in for real clicks.
- **Sharing the desktop:** the "ScreenshotTool Windows" Claude session
  works on the same desktop. It asks before taking it, and so should we
  (SendMessage). A window or system error dialog of its own over the probe
  makes pointer checks fail or a configuration time out; rerun once the
  desktop is clear.
- **Escapes in scripts:** bash heredocs here turn `\n` into a real
  newline. Write scripts with the Write tool, or build escapes in Python
  with `chr(92)`. Sources are CRLF.

## Where things stand

Phases A to J and these fixes are merged into `main`:

| PR | Branch | Issues |
| --- | --- | --- |
| #52 | `adwaita-parity-phase-a` | #11, #2, #1, #4, #3, #16 |
| #55 | `adwaita-parity-phase-b` | #15, #19, #12, #6, #7 |
| #59 | `adwaita-parity-phase-c` | #54, #53, #24, #23, #34, #18 |
| #60 | `adwaita-parity-phase-d` | #25, #21, #38, #10, #35, #39, #29 |
| #61 | `adwaita-parity-phase-e` | #36, #37, #40, #8, #43, #51, #9 |
| #63 | `adwaita-parity-phase-f` | #14, #44, #41, #42, #28, #46, #5 |
| #65 | `fix-early-template-tint` | #64 |
| #68 | `adwaita-parity-phase-g` | #62 (LGPL-2.1-or-later), #13, #57, #56, #58 |
| #70 | `fix-missing-indicator-images` | buttons as radios without gui's images |
| #71 | `adwaita-parity-phase-h` | #26, #48, #49, #31 |
| #73 | `adwaita-parity-phase-i` | #27, #45, #32, #17 |
| #84 | `adwaita-parity-phase-j` | #66, #22, part of #72 (tabs), part of #19 (real-app pass) |
| #85 | `window-tabs-off-by-default` | window tabs behind `WinUIThemeWindowTabs` (#72) |
| #88 | `fix-overlay-scrollers-autohide` | #87 |
| #90 | `version-0.1.0-alpha1` | the first release |
| #93 | `adwaita-parity-phase-k` | #80, #81, #76, #86, #89, #74, #75, part of #72 |
| #94, #96 | window tabbing fixes, tool tip colours | part of #72, #95 |
| #98 | `test-isolation` | QuirkProbe in its own home, `-Pointer` opt-in |
| #99 | `menu-bar-keyboard` | #78, #77 |
| #100 | `native-dialogs` | #69, #20, page setup |
| #101 | `popover-flyouts` | popover panels as flyouts (part of #30) |
| #103 | `hc-scroller-tiling` | #103 |
| #104 | `client-caption` | the theme's own title bar (needs the libs-back carry build) |
| #106 | `windows-titles` | #33, #79 |
| #107 | `motion` | the motion clock, hover fades, opening fades (part of #105) |
| #108 | `reference-specimens` | `Compare-Reference.ps1` and the specimens page (part of #105) |
| #109 | `version-0.1.0-alpha2` | the second release |
| #110 | `toolbar-disabled-icon` | a disabled toolbar icon darkening when redrawn alone (ScreenshotTool's Redo at 1.5) |
| #111 | `reference-fidelity` | measured against WinUI, more motion, the Win32 BOOL stack fix, #30, #67 |
| #112 | `fidelity-bugs` | #92, #82, #102 |

**Releases.** The owner approved the release process on 2026-10-08:
- semver pre-release tags (`0.1.0-alphaN`);
- a "Version X" commit that sets `GSThemeVersion` in `WinUIThemeInfo.plist`
  and adds the release's section to `CHANGELOG.md`;
- an annotated tag on `main`;
- a GitHub pre-release with the notes and the bundle zip built in CLANG64;
- apps pin a tag, not `main`.

**0.1.0-alpha2** is tag `0.1.0-alpha2` on `104b12e`, a GitHub pre-release
with `WinUITheme-0.1.0-alpha2-msys2-clang64.zip`. **It has a stack overrun**
(fixed in #111, `c2124c5`): reading Windows' "Animation effects" setting
can stop an app with "stack smashing detected" once hover fades run.
ThemeDemo built with alpha2 quit during real clicks. Cut 0.1.0-alpha3 soon,
and move ObjcMarkdown's pin off alpha2.

**0.1.0-alpha1** is tag `0.1.0-alpha1` on `eb9f8b8`. ObjcMarkdown's MSI is
pinned to it (its `packaging/manifests/windows-msi.manifest.json`); it was
pinned at `48d21f0`, from April, before.

**Measured against WinUI (#108, #111).** `Tests/Scripts/Compare-Reference.ps1`
captures the WinUI 3 reference app's specimens page and ThemeDemo's, and
measures sizes, fills, strokes and text. Light and dark: 0 out of tolerance
on `main`. The light window is #F3F3F3 (it was #F9F9F9, changed on the
owner's go-ahead to do all five items; one line in `WinUIThemePalette.m`).

**Motion (#105).** One clock in `Source/Rendering/WinUIThemeMotion.m`:
- hover and pressed fills fade (83ms);
- a switch's knob slides and a checkbox's tick draws in (167ms);
- menus, tool tips and flyouts fade in; a menu bar's menus, context menus,
  pop-up lists and flyouts also slide 8pt down into place;
- alerts fade in.

It's off under Windows' "Animation effects", or the
`WinUIThemeAnimations` default. QuirkProbe turns it off for every check but
`checkMotion`'s.

**Window tabs (#72):**
- **Shared code:** danjboyd/gnustep-window-tabbing at `4cb1b63`, the commit
  the owner reviewed, vendored in `Source/WindowTabbing` with a relative
  `GSWINDOWTABBING_DIR`. Installed from `-initWithBundle:`, before super,
  only when the `WinUIThemeWindowTabs` default is YES (off by default).
- **MinGW:** `4cb1b63` needs `<dlfcn.h>`, which MinGW lacks, so the theme
  carries `Source/Native/Compat/dlfcn.h`.
- **Upstream fixes, applying them waits on the owner:**
  - `e49226b`: exports, removing the dllimport and LNK4217 warnings;
  - `a5cb18a`: a Windows path for the two-copies check, removing the
    shim;
  - `adfa7b4`: the include order.

  All three were tried on top of `4cb1b63` in a scratch build and build
  cleanly here. Phase 2 (`ed47a49`: dragging, scrolling, the bar's fades)
  also carries a maximized state to the selected tab and keeps a tab's
  frame when a menu bar is added. Taking it would let the theme drop its
  placement fix and its `-addMenuView:` overrides.
- **Checked with ObjcMarkdown** (`main` with #108) in light and dark,
  results on #72. Before defaulting it on, check by hand:
  - snap with Win+arrow;
  - a real click on a new tab's close button (a posted one was ignored
    twice in six runs).
- **Title-bar tabs** are #83, which needs libs-back work first.

**Upstream:** gnustep/libs-back#246 (posted 2026-10-08 after the owner's
review; branch `win32pbs-images` on danjboyd/libs-back, rebased onto
upstream `9c7bcce`)
makes `win32pbs.m` bridge images both ways: CF_DIB, CF_BITMAP and "PNG" to
NSTIFFPboardType and NSPasteboardTypePNG, and TIFF or PNG back as CF_DIB and
"PNG", rendered on demand like the text. It adds `Tests/win32/pasteboard.m`
(16 checks, which fail on the unpatched gpbs). It was compiled with clang;
GCC only checked its syntax, since no GCC-built gnustep-base exists here
(gcc-objc 14.2 was unpacked in a scratch directory, not installed). The
only GNUstep AI policy found is apps-gorm's `POLICY_AI.md` (tests, the
contributor's own review, no Apple-only syntax, disclosure); the commit
message discloses the assistance. Its two behaviour changes went in as
written (CF_UNICODETEXT is published only when the pasteboard has text;
text views that take images paste an image from apps that offer both). The
FSF copyright assignment is still the owner's to settle with GNUstep.

ScreenshotTool's Windows MSI (danjboyd/ScreenshotTool#120) bundles the theme
at `c9dbf91` and was tested on a clean OCI Windows Server 2025 VM. Clean
machines lack MSYS2's GNUstep tools and resources: an MSI must ship `gdnc`,
`gpbs`, `make_services` and gnustep-gui's `Images`, `KeyBindings` and the
rest, and its `GNUstep.conf` must name a library path holding the themes.
danjboyd/gnustep-packager#4 makes the MSI smoke launch catch an app that
can't start without the build toolchain.

Other repositories:

- ObjcMarkdown: build issues #55-#57. The owner may have someone else on them.
  MarkdownViewer now runs here, from `MarkdownViewer-dev.ps1`.
- Adwaita theme: #45 (plist).

The theme is also installed system-wide
(`/clang64/lib/GNUstep/Themes/WinUITheme.theme`), so
MarkdownViewer loads it; `C:\Users\Support\GNUstep\Defaults\NSGlobalDomain.plist`
selects it. Reinstall with `make GNUSTEP_INSTALLATION_DOMAIN=SYSTEM install`
in a CLANG64 shell; never install it into
`C:\Users\Support\GNUstep\Library\Themes`, where a copy would shadow it.
It was last installed from `b3a6b20`. If an app holds the DLL, rename it to
`*.dll.old` first: Windows allows renaming a loaded DLL. Delete it after the
app closes.

### Open issues not yet addressed

| Area | Issues |
| --- | --- |
| Tracking | #105 remaining WinUI gaps (its checklist hasn't been ticked: motion, measured checks and #30/#67/#82/#92/#102 are done; see below); #50 Adwaita parity |
| Windows | #72 tabs on by default (draft PR #97, phase 2 of the shared code, awaits the owner's review); #83 title-bar tabs |
| Fidelity | #91 single-row chrome (`GSThemeToolbarInMenuBar`) |
| System | #47 Mica (investigate, upstream) |
| Testing | #19 real-app backlog |

**Suggested next five** (the owner decides):

1. **0.1.0-alpha3**, for the stack-overrun fix and everything since
   alpha2. Then repin ObjcMarkdown and tell the ScreenshotTool session.
2. **Real clicks on menus.** Menus are now `WS_EX_NOACTIVATE` (#30). Check
   with real input (owner's permission) that clicking a menu item, a pop-up's
   item and a context menu item still chooses it, in ThemeDemo and ObjcMarkdown.
3. **The rest of #105's motion:** list-row and menu-item hover fades, the
   radio dot, the switch knob stretching while pressed, flyouts sliding from
   the side they open on, the overlay scroll bar's rail, the indeterminate
   ProgressBar and ProgressRing. Then tick #105's checklist.
4. **Upstream libs-back:** `setmaxsize`'s XOR (#67; the theme works round
   it) and, with the ScreenshotTool session, per-monitor DPI. Upstream
   patches follow the formal process above.
5. **#19 real-app pass** with real input: ObjcMarkdown, ScreenshotTool, Gorm,
   TinyRetroPad. Also #72's hand checks, and #91 after ObjcMarkdown 0.2.2.

### Known gaps in finished work

- **Menus never take activation (#30), not checked with real clicks.**
  Windows delivers clicks to `WS_EX_NOACTIVATE` windows, and the probe's
  synthesized and pointer-moving checks pass. A real click on a menu item
  hasn't been tried: the session's permission check blocked SendInput.
- **Motion's limits:** WinUI's ContentDialog also scales as it opens; a
  layered window's alpha can't, so alerts only fade. High contrast's pressed
  buttons change at once, with their titles. Only menus from the bar,
  context menus, pop-up lists and flyouts slide; a submenu doesn't, so it
  opens beside its menu where that menu will settle.
- **A rounded control redrawn from `-setNeedsDisplay:`** has its antialiased
  corners a shade darker than `-display` gives: libs-gui draws it a second
  time over itself. It doesn't grow, and isn't visible, but a probe check
  comparing renders must draw both the same way (`QuirkProbeAnimates`).
- **libs-back's `setmaxsize`** still XORs the maximize box; the theme sets
  both boxes again after `-setMaxSize:` (#67). A window whose style changes
  some other way isn't corrected.
- **Placeholder while focused (#102)** only for TextBoxes (fields the theme
  fills). The field editor's clip view stops drawing its background once a
  field with a placeholder has been edited; the editor draws its own for
  fields without one.
- **The probe opening menus:** opening a pop-up's list outside a click
  (`-attachPopUpWithFrame:inView:`) and handling events left a later check
  waiting, in 2 of 3 full runs. Open lists with a click and a timer during
  tracking (`checkContrastPopUpSelection`).
- **Menu and tool tip rounding and shadow (#39) are untested.** The theme
  sets `DWMWA_WINDOW_CORNER_PREFERENCE`, but this machine is a VM with a
  QXL display adapter and no GPU. Windows 11 rounds no windows here, the WinUI
  reference app's included. libs-back creates every window `WS_EX_LAYERED`,
  and its cairo build turns borderless windows into captionless
  `WS_OVERLAPPED` windows rather than `WS_POPUP`. Either may stop DWM
  rounding menus on real hardware. Check on Windows 11 with a GPU.
- **Combo box list:** the list that opens from a combo box is still
  libs-gui's.
- **Live settings (#46):** checked by sending the theme's listener window
  ImmersiveColorSet with an accent override, not by changing Windows'
  settings, which would disturb the desktop. Toggle light/dark, the accent
  and a contrast theme by hand once. libs-back's windows are DPI-unaware, so
  Windows sends no `WM_DPICHANGED`. After a text-size change only controls
  made afterwards get the new fonts.
- **Hover when the pointer is already inside:** a tracking rect added under
  the pointer gets no entering, only the exit. Tables work round it from
  `-mouseMoved:`; buttons and scroll bars show their hover once the pointer
  has crossed their edge.
- **No paused or error progress state, no slider ticks:** NSProgressIndicator
  has no such states, and libs-gui draws no tick marks.
- **Pointer checks can flake** when something else on the desktop takes the
  pointer or focus: once in this work, `button-hover`, `table-row-hover` and
  `scroller-hover-expands` all failed in one configuration and passed on
  reruns. Rerun before suspecting the theme.
- **Date picker (#56):**
  - A picker with a date and a time shares one hover state between its two
    fields.
  - The flyout has no up and down buttons at its columns' ends; the wheel,
    clicks and arrow keys move them.
  - On libs-gui after 0.32 the theme's flyout replaces libs-gui's field
    selection and stepper, so a field can't be stepped from the keyboard
    without opening the flyout.
  - The clock style (time only, calendar style) draws a TimePicker field;
    a calendar-style picker with a time shows only the calendar.
  - TimePicker has no seconds, so a picker set to show seconds hides them.
- **Browser (#58):** rows have no hover fill. The columns are cards 8pt
  apart, as in the reference app, rather than one surface split by
  hairlines.
- **Boxes (#27):** a box title keeps the size the box was laid out for
  (GNUstep's small system font by default), in BodyStrong's weight; WinUI's
  BodyStrong is 14px, which would overflow the title's rect.
- **Contrast themes (#45):** checked with Windows' own theme files
  (`--contrast-theme`), not by turning high contrast on, which would
  disturb the desktop. The GetSysColor path and a live switch between
  contrast themes are untested. GNUstep has no link colour, so
  HotTrackingColor goes unused.
- **Gorm palette (#32):** checked in a Gorm 1.5.0 built in a scratch
  directory, not installed, and by archiving the palette's view as Gorm
  saves; dropping a control into a real .gorm file wasn't tried. Caption,
  Subtitle and Title keep fixed sizes under compact metrics and text
  scaling. The palette needed the theme to enable NSSwitch after
  `-initWithCoder:` (gui 0.32 leaves it disabled; QuirkProbe
  `switch-decoded-enabled`).
- **ThemeDemo commands (#17):**
  - An alert closes up to about a second after `dismiss-alert`, when its
    modal loop next runs; wait before capturing what's under it.
  - Windows' fade-in makes a screen capture of a new window translucent for
    a second or more on this VM; window captures use PrintWindow instead.
  - A ring can be left along a control's edge when a key press turned
    keyboard focus on and focus then moves with no event at all (only
    scripts do that).
  - On other platforms the FIFO is opened but screen captures aren't
    implemented.
- **Selected rows (#66):** in light and dark an app's own text colours
  stay on the selection (they read on WinUI's subtle fill); only high
  contrast forces HighlightText. The theme's text on accent fills now has
  its own `accentTextColor` key; `selectedControlTextColor` is a selected
  row's text.
- **Tool tips (#22):** the padding is applied in `GSTTPanel`'s
  `-setFrame:display:` by recognising libs-gui's text-plus-4pt frame; a
  libs-gui that sizes tips differently would get no padding. The probe and
  ThemeDemo show tips through `GSToolTips`' `_timedOut:`; real hover wasn't
  checked (it needs the real pointer).
- **Window tabs (#72):**
  - Above the content, not in the title bar (#83).
  - An app that compiles the shared code in itself (as the shared repo's
    TabDemo does) crashes under the theme: two copies of each class.
    Reported on the spec; apps should rely on the theme.
  - The "+" button's hit area covers the empty strip after the tabs.
  - The theme's `-[NSWindow close]` hook (selecting the neighbour first)
    is installed with `method_setImplementation` and stays after a theme
    switch.
  - Not exercised: Ctrl+Tab, middle click, libs-gui master, real hardware.
- **Pointer checks on 2026-10-08:** `button-hover`, `table-row-hover` and
  `scroller-hover-expands` failed in every configuration at the end of
  phase J, and failed the same way on `main`'s build, so the desktop was
  to blame (other windows were open over the probe's). Rerun with the
  desktop clear.
- **Overriding NSBrowser methods breaks the fonts.** GSTheme sends each
  overridden class a message while it loads the theme, before the theme's
  font defaults are set. +[NSBrowser initialize] makes a title cell, which
  fixes the system font at Tahoma 12 for the session. #58's hooks are on
  the columns' scroll views instead. Check `typography-body` after adding an
  override for a new class.

## Toolchain

- **MSYS2 clang64:** gnustep-make 2.9.3, base 1.31.1, gui 0.32.0, back 0.32.0,
  and clang 21. libdispatch and blocksruntime are held at 5.10.
  - gui 0.31 misparsed theme override names, so 0.32 is required (libs-gui
    `a8018d6c8`).
  - Sources are in `C:\Users\Support\git\gnustep\libs-gui` (and `libs-back`).
    They're newer than the installed 0.32. For example, they have
    `-[GSTheme buttonPushInOffsetForCell:]`, which 0.32 lacks.
  - **Testing against libs-gui master:** export the sources (`git archive
    HEAD`) to a scratch directory, `./configure && make` there in a CLANG64
    shell, then copy `QuirkProbe.app` and put
    `Source/obj/gnustep-gui-0_32.dll` beside its exe as
    `gnustep-gui-0.dll`. Windows loads the DLL from the exe's directory
    first, so the probe and the theme run on master's gui. Phase G's checks
    pass there too.
- **Building:**
  - `Scripts/Invoke-GNUstepMake.ps1 -Directory <dir> [-Clean]` builds the
    theme (repo root, giving `WinUITheme.theme`), `Examples/QuirkProbe` and
    `Examples/ThemeDemo`.
  - The theme plist is `WinUIThemeInfo.plist`, merged by gnustep-make.
  - New source files go in `GNUmakefile`'s `WinUITheme_OBJC_FILES`.
- **WinUI 3 reference app:** `Reference\WinUI3ReferenceApp\build.ps1`
  (dotnet 8). Run it with
  `bin\Debug\net8.0-windows10.0.19041.0\win-x64\WinUI3ReferenceApp.exe --page <id>`.
  Page ids: `controls`, `text-input`, `commands`, `data-views`, `dialogs`,
  `real-app`, `surfaces`. ThemeDemo uses the same ids, with `--page <id>
  --mode light|dark`.

## Regression probe

`Tests/Scripts/Invoke-QuirkProbe.ps1` runs `Examples/QuirkProbe`.

- **Configurations:** light, dark, high-contrast, light-150 (150% desktop
  scale), large-text (150% Windows text size), compact (compact metrics,
  #31), and dusk and desert (two of Windows' contrast themes, #45). The
  exit code is the number of failures.
- **Isolation:** each run gets a scratch home (`GNUstepTestHome.ps1`:
  HOMEDRIVE and HOMEPATH point under `%TEMP%`, with a fixed
  `NSGlobalDomain`), so the probe and ThemeDemo scripts don't touch the
  owner's `C:\Users\Support\GNUstep\Defaults`. MSYS2's gnustep-base ignores
  `GNUSTEP_CONFIG_FILE`, so Adwaita's private `GNUstep.conf` doesn't work
  here.
- **Options:**
  - `-Pointer` runs the four checks that move the real pointer, which
    skip by default (`-NoPointer` is still accepted);
  - `-Configuration light,dark` picks configurations;
  - `-Theme <path>` checks another build;
  - `-OutputDirectory <dir>` saves renders.
- **Coverage:** 137 checks in light, dark and the 150% configurations (139 in
  the compact one), 4 of them moving the pointer. In high contrast and the
  contrast themes some checks skip with a reason.
- **ThemeDemo scripts:** `Tests/Scripts/Invoke-ThemeDemoScript.ps1 -Script
  FILE -OutputDirectory DIR` drives ThemeDemo with commands (#17, listed in
  `Examples/ThemeDemo/README.md`) for states the probe can't render: open
  menus, alerts, focus from the keyboard, the title bar.
- **Desktop scale:** the theme scales metrics by `--scale`, the probe's
  drawing stays 1:1; `QuirkProbeDesktopScale()` gives the factor.

**Every fix gets a check that fails on the previous build and passes on the
new one.** Build the previous phase's theme in a scratch worktree
(`git worktree add --detach <dir> <commit>`, then `Invoke-GNUstepMake.ps1
-Directory <dir>`) and run the probe with `-Theme <dir>\WinUITheme.theme`.
Before a PR, clean-build every commit, theme and probe.

How checks are written (`Examples/QuirkProbe/QuirkProbe.m`):

- **Structure:** one `- (void) checkSomething` method per area, declared in
  the interface and called from the run list. Report with
  `[self pass:/fail:/skip: @"check-id" detail: ...]`.
- **Rendering:**
  - `QuirkProbeRender(view)` returns a bitmap; pixel coordinates run from
    the top left (`QuirkProbePixel`, `QuirkProbeBrightnessAt`), and
    `QuirkProbeScale` gives device pixels per point.
  - Renders copy the window's backing store. Call `[window display]`, or
    `[view display]` after a state change that doesn't redraw by itself
    (such as `-highlight:`), before rendering.
- **Helpers:**
  - `QuirkProbeInkIn`, `QuirkProbeMeasureIn`, `QuirkProbeDifferingPixels`;
  - `QuirkProbeClickAt` (synthetic click), `QuirkProbeDispatchEvents(seconds)`;
  - `QuirkProbeSetPointer` (real pointer, Windows `SetCursorPos`).
  - Running the run loop alone doesn't dispatch events, because the probe
    runs inside one event. Use `QuirkProbeDispatchEvents` so timers, hover
    and tracking rects work.
- **Scale and colour:** at light-150 the theme scales metrics (such as corner
  radii) with the desktop scale, while the probe's drawing is 1:1. Scale
  sample offsets with `--scale`. Match colours against the palette, for
  example `[NSColor selectedControlColor]` for the accent, rather than loose
  tests like "bluer than red".
- **Object lifetime:** keep any view that needs its model alive (a menu
  view's `NSMenu`, a table's data source) alive, or detach it, before the
  check returns. A later theme switch notifies every view.

## Theme code conventions

- **Overrides:** they're GSTheme hooks, named
  `_override<Class>Method_<selector>` in a `WinUITheme (...)` category.
  - Inside one, `self` is the overridden object, not the theme. Get the theme
    with `[GSTheme theme]`, checking `isKindOfClass: [WinUITheme class]` (or
    `WinUIThemeActiveTheme()` in Controls.m).
  - Call the original with
    `WinUIThemeOriginalMethod(_cmd, self, [BaseClass class])`; libs-gui's own
    lookup only matches the exact class.
  - For a private selector, double the underscore:
    `_overrideNSTextFieldCellMethod__drawBackgroundWithFrame:inView:`.
- **Colours:** Fluent's colours are white or black at an opacity over a
  layer, so the theme blends them over the window background
  (`WinUIThemeBlendColor(window, white, 0.70)` and so on). Palette:
  `Source/Rendering/WinUIThemePalette.m`. Metrics:
  `Source/Settings/WinUIThemeMetrics.m`, scaled by desktop DPI. Settings and
  registry: `Source/Settings/WinUIThemeSettings.m`.
- **Type:** Segoe UI Variable at 14px times Windows' text size
  (`-textScaleFactor`). For bold use `WinUIThemeSemiboldFont(font, size)`,
  WinUI's Semibold; `NSBoldFont` is set to it.
- **Live settings:** `-[WinUITheme systemSettingsDidChange]` reloads, posts
  `GSThemeDidActivateNotification` (NSColor recaches its system colours only
  then) and redraws. The integration controller's listener window calls it.
- **Shared drawing** (`Source/Rendering/WinUIThemeDrawing.h`):
  - `WinUIThemeDrawButtonChrome` for buttons, pop-ups and non-editable combo
    boxes;
  - `WinUIThemeDrawTextBoxChrome` for text inputs;
  - `WinUIThemeControlCornerRadius` (4pt) and `WinUIThemeOverlayCornerRadius`
    (8pt);
  - `WinUIThemeTrackHover` and `WinUIThemeViewIsHovered`, pointer-over state
    from a tracking rect added on first draw; `WinUIThemeSetViewHovered` for
    views that learn of the pointer otherwise (tables, from `-mouseMoved:`);
  - `WinUIThemeKeyboardFocusVisible`.
- **Files by area:**

  | Area | File |
  | --- | --- |
  | Controls | `WinUIThemeControls.m` |
  | Menus and data views | `WinUIThemeMenusAndData.m` |
  | Menu tracking (#54) | `WinUIThemeMenuTracking.m` |
  | Windows menu conventions | `WinUIThemeApplicationMenu.m` |
  | Alerts | `WinUIThemeAlerts.m` |
  | Toolbar | `WinUIThemeToolbar.m` |
  | Template images | `WinUIThemeTemplateImages.m` |
  | Hover | `WinUIThemeHover.m` |
  | Scroll bars | `WinUIThemeScrollers.m` |
  | Focus visual | `WinUIThemeFocus.m` |
  | DWM and window integration | `Source/Native/WinUIThemeWindowIntegration.m` |
  | Boxes and forms (#27) | `WinUIThemeBoxes.m` |
  | Window tabs (#72) | `WinUIThemeWindowTabs.m`, shared code in `Source/WindowTabbing` |
  | Cell sizes (#86) | `WinUIThemeCellSizes.m` |

- **Porting from Adwaita:** its versions of most of these are in
  `plugins-themes-Adwaita/Source/Rendering/`. Ported pieces include the
  overlay scrollers and the focus-visible handling.

## Working on Windows: gotchas

- **Notification order:** GNUstep's notification centre tells the most
  recent observer of a name first (the opposite of what one might assume);
  it's why closing a tab quit the app before the theme's close hook.

- **Use the Write tool for code containing escapes.** In this shell, bash
  heredocs feeding Python turned `"\n"` inside Objective-C string literals
  into real newlines several times. Write Python edit scripts with the Write
  tool, or edit with the Edit tool. Sources are CRLF; scripts read and write
  bytes and keep the line endings.
- **Screenshots:**
  - `Tests/Scripts/Capture-Window.ps1 -ProcessId <pid> -OutPath <png>` sometimes
    grabs the wrong window. Bringing the window to the front
    (`SetForegroundWindow`) and copying the screen over its `GetWindowRect`
    is more reliable.
  - `GetWindowRect` includes the invisible resize border.
  - Synthesize clicks and keys with `mouse_event`/`keybd_event` and
    `SetCursorPos` (via `Add-Type` in PowerShell).
  - Menus and tool tips are separate windows, so copy the screen rather than
    capturing one window.
  - Other programs' windows can get in the way. A `MarkdownViewer.exe`
    error dialog appeared during this work; it wasn't ours, and was left
    alone.
- **Windows API:** libs-back's Windows server doesn't implement
  `-setMouseLocation:onScreen:`; use `SetCursorPos`, flipping y from the
  screen height.
- **Command key:** GNUstep's Command modifier is left Ctrl on Windows.
  Shortcuts show as "Ctrl+Shift+Z" via the theme's `-keyForKeyEquivalent:`.
- **Win32 callbacks in Objective-C:** Objective-C's `BOOL` is a `signed char`;
  declare Win32 callbacks (`EnumThreadWindows` and the like) as `WINBOOL`.
- **Tracking rects:** a rect added while the pointer is already inside gets
  no `mouseEntered:`, only the exit. Probe checks move the pointer outside
  the window first, and make the window key.
- **Spinners:** a stopped `NSProgressIndicatorSpinningStyle` indicator hides
  itself unless `-setDisplayedWhenStopped: YES`, as in Cocoa.
- **Theme metrics vs. the probe:** with `--scale`, the theme scales its
  metrics while the probe draws 1:1; expect `20 * QuirkProbeDesktopScale()`,
  not 20 times the render's scale.
