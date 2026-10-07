# Handoff: Adwaita parity work

State as of 2026-10-06, for picking the work up in a fresh session. The goal
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

## Where things stand

The work is a stack of PRs, each based on the one before. Merge them in this
order:

| PR | Branch | Base | Issues |
| --- | --- | --- | --- |
| #52 | `adwaita-parity-phase-a` | `main` | #11, #2, #1, #4, #3, #16 |
| #55 | `adwaita-parity-phase-b` | phase A | #15, #19, #12, #6, #7 |
| #59 | `adwaita-parity-phase-c` | phase B | #54, #53, #24, #23, #34, #18 |
| #60 | `adwaita-parity-phase-d` | phase C | #25, #21, #38, #10, #35, #39, #29 |
| #61 | `adwaita-parity-phase-e` | phase D | #36, #37, #40, #8, #43, #51, #9 |

None are merged. The issues close when their commits (`Fixes #N`) reach
`main`. If a base branch is deleted when its PR merges, retarget the next PR
by hand.

Other repositories:

- ObjcMarkdown: build issues #55-#57. The owner may have someone else on them.
- Adwaita theme: #45 (plist).

### Open issues not yet addressed

| Area | Issues |
| --- | --- |
| Correctness | #14 sizeToFit/cellSize vs. drawn geometry; #13 NSTextAlignment numbering; #5 checkbox/radio bitmaps (ThemeDemo draws them as vectors now, so check what's left) |
| Fidelity | #44 typography (Segoe UI Variable ramp, Semibold); #41 slider; #42 ProgressBar/ProgressRing; #28 table defaults; #27 NSBox/forms as cards; #26 colour well; #48 segmented control; #49 tab view; #22 tool tips (colours done in #39; padding and font remain); #30 popup window owner/tool-window style |
| System | #46 live settings changes; #45 high-contrast system colours; #47 Mica (investigate, upstream) |
| Nib apps | #31 compact metrics for nib/Gorm apps; #32 Gorm palette; #33 document window titles |
| Controls | #56 NSDatePicker; #57 NSLevelIndicator; #58 NSBrowser |
| Testing | #17 ThemeDemo automation; #19 real-app backlog; #20 native dialogs at run time |

**Suggested next five:**

1. **#14 sizeToFit:** text gets clipped wherever an app sizes controls with `-sizeToFit`.
2. **#44 typography:** it touches everything, and the controls have now settled.
3. **#28 table defaults**, with the remaining row-hover gap from #43.
4. **#41 and #42 slider and progress:** small, very visible, and similar work.
5. **#46 live settings:** theme, accent, contrast and DPI changes without relaunching.

### Known gaps in finished work

- **Menu and tool tip rounding and shadow (#39) are untested.** The theme
  sets `DWMWA_WINDOW_CORNER_PREFERENCE`, but this machine is a VM with a
  QXL display adapter and no GPU. Windows 11 rounds no windows here, the WinUI
  reference app's included. libs-back creates every window `WS_EX_LAYERED`,
  and its cairo build turns borderless windows into captionless
  `WS_OVERLAPPED` windows rather than `WS_POPUP`. Either may stop DWM
  rounding menus on real hardware. Check on Windows 11 with a GPU.
- **No hover fill on table rows (#43):** libs-gui tracks no row hover.
- **Combo box list:** the list that opens from a combo box is still
  libs-gui's.
- **Untested states:**
  - editable combo boxes while editing (ThemeDemo's combo box isn't editable);
  - the search field's pressed fill;
  - the scroll bar's expanded hover state (#29), checked only on screenshots.

## Toolchain

- **MSYS2 clang64:** gnustep-make 2.9.3, base 1.31.1, gui 0.32.0, back 0.32.0,
  and clang 21. libdispatch and blocksruntime are held at 5.10.
  - gui 0.31 misparsed theme override names, so 0.32 is required (libs-gui
    `a8018d6c8`).
  - Sources are in `C:\Users\Support\git\gnustep\libs-gui` (and `libs-back`).
    They're newer than the installed 0.32. For example, they have
    `-[GSTheme buttonPushInOffsetForCell:]`, which 0.32 lacks.
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

- **Configurations:** light, dark, high-contrast and light-150 (150% desktop
  scale). The exit code is the number of failures.
- **Options:**
  - `-NoPointer` skips checks that move the real pointer;
  - `-Configuration light,dark` picks configurations;
  - `-Theme <path>` checks another build;
  - `-OutputDirectory <dir>` saves renders.
- **Coverage:** about 55 checks in light, dark and 150%. In high contrast
  some checks skip with a reason.

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
- **Shared drawing** (`Source/Rendering/WinUIThemeDrawing.h`):
  - `WinUIThemeDrawButtonChrome` for buttons, pop-ups and non-editable combo
    boxes;
  - `WinUIThemeDrawTextBoxChrome` for text inputs;
  - `WinUIThemeControlCornerRadius` (4pt) and `WinUIThemeOverlayCornerRadius`
    (8pt);
  - `WinUIThemeTrackHover` and `WinUIThemeViewIsHovered`, pointer-over state
    from a tracking rect added on first draw;
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

- **Porting from Adwaita:** its versions of most of these are in
  `plugins-themes-Adwaita/Source/Rendering/`. Ported pieces include the
  overlay scrollers and the focus-visible handling.

## Working on Windows: gotchas

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
