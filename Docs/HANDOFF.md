# Handoff: Adwaita parity work

State as of 2026-10-15 (night: 0.1.0-alpha7 ready to release, waiting on the owner's merge; alpha6 released that afternoon), for picking the work up in a fresh session. The goal
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
- **libs-back changes are carried** (the owner's decision, 2026-10-13):
  what the theme needs from libs-back goes on `danjboyd/libs-back`'s
  `carry` branch now, released as an MSYS2 package (`carry-0.32.0.N`),
  without waiting for GNUstep. Apps that use the theme ship it too
  (README's "Requirements"). Each change is a topic branch on upstream
  master first, cherry-picked (or hand-ported) onto `carry`; the theme
  must still work on a stock libs-back. `packaging/README.md` on `carry`
  lists what it carries.
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
- **Real input on this VM:** SendInput mouse buttons are blocked here
  (it returns 0; found by the ScreenshotTool session, 10-15); only
  SetCursorPos works. Keyboard SendKeys did reach apps on 10-15. Tell the
  owner before sending any keys: he watches the desktop, and menus
  opening on their own looked like a bug to him.
- **Merging:** the auto-mode permission check blocks `gh pr merge`
  ("Merge Without Review") unless it's allowed. On 10-15 the owner added
  `Bash(gh pr merge:*)` to this repo's local settings (`/permissions`).
  Merge only what the owner has approved.
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
| #114 | `version-0.1.0-alpha3` | the third release, README's Requirements |
| #115 | `popup-shadows` | #39 (menu, tool tip and flyout shadows), probe `-Backend` |
| #116 | `per-monitor-dpi` | per-monitor DPI, tool tips at a scale (part of #105) |
| #117 | `mica` | Mica through the chrome (part of #47) |
| #118 | `title-bar-tabs` | #83 (window tabs in the title bar) |
| #119 | `handoff-2026-10-13-pm` | this file |
| #120 | `motion-rest` | real-input fixes (Mica's caption buttons, context menus staying open), the rest of #105's motion, hover under a still pointer, the combo box drop-down |
| #121 | `handoff-2026-10-13-late` | the previous handoff |
| #122 | `controls-105` | the rest of #105's controls (browser hover, box titles, the combo pill, toolbar separators, text size reaching open windows), #56's gaps, context menus at the screen's edges, submenu clicks (#19, found in Gorm), the scaled-display and second-monitor fixes from the OCI runs |
| #123 | `version-0.1.0-alpha4` | the fourth release |
| #127 | `alpha5-overflow-fix` | the alpha4 scaled-toolbar regression alone (cherry-picked from #125) |
| #128 | `version-0.1.0-alpha5` | the fifth release |
| #125 | `parity-2026-10-15` | #91 (the toolbar in the menu bar's row), slider tick marks and paused/error progress (#105), ContentDialog's scale, the overlay scroller at a fractional scale, the probe's `scaled-150` and libs-gui master fixes |
| #129 | `readme-release` | the README for the release announcement: screenshots (`Docs/Images`, captured by `Examples/ThemeDemo/Scripts/readme-screenshots.txt`), install steps, a feature list |
| #131 | `menu-style-more` | #130 (menus behind "...", `WinUIThemeMenuStyle = more`) |
| #132 | `version-0.1.0-alpha6` | the sixth release |

**Open, not merged:**

| PR | Branch | Issues |
| --- | --- | --- |
| #124 | `handoff-2026-10-14` | the 10-14 handoff (this file's base) |
| #97 (draft) | `window-tabs-phase-2-review` | phase 2 of the shared window tabbing code; awaits the owner's review (#72) |
| #135 | `alpha7-tabs` | alpha7: #133, #72 (tabs on), #134, #136-#141 (see "alpha7" below) |
| #143 (draft) | `gsthemestyle-accent` | #142, `-setGSThemeStyle: @"accent"`, stacked on #135; waits on the owner's yes to the name |
| (no PR yet) | `version-0.1.0-alpha7` | the Version commit `9134e99`, on top of #135 |
| #126 (this one) | `handoff-2026-10-15` | this file, on top of #124; `main` (alpha6) merged in |

**Releases.** The owner approved the release process on 2026-10-08:
- semver pre-release tags (`0.1.0-alphaN`);
- a "Version X" commit that sets `GSThemeVersion` in `WinUIThemeInfo.plist`
  and adds the release's section to `CHANGELOG.md`;
- an annotated tag on `main`;
- a GitHub pre-release with the notes and the bundle zip built in CLANG64;
- apps pin a tag, not `main`.

**0.1.0-alpha6** is tag `0.1.0-alpha6` on `b667a54` (the merge of #132),
a GitHub pre-release with `WinUITheme-0.1.0-alpha6-msys2-clang64.zip`
(SHA-256 `bb900581...4eb752`), tested with `carry-0.32.0.4`.
- **Contents:** #125 and #131 (above) and the README (#129). Both kinds
  of new chrome are off unless an app's Info.plist or a user default asks.
- **How it was released (10-15, afternoon):**
  - the owner approved #125 after seeing its screenshots, and asked for
    `WinUIThemeMenuStyle` in alpha6 ("merge 125 and let's include this
    WinUIThemeMenuStyle in alpha6; proceed");
  - #131, #129 and #132 were merged by this session once the owner
    allowed `gh pr merge`;
  - the zip was built from a clean tree at `7e47183`, whose tree is
    identical to `b667a54`'s. QuirkProbe light and dark on the carried
    backend and light on stock passed at that commit, the unzipped
    bundle ran ThemeDemo, and the downloaded asset's checksum matched.
- **The announcement:** the ReleaseCoordinator session (Remote Control)
  gathers each project's release for one GNUstep mailing list post by
  the owner. It has the URL, the notes and the carried-backend note.
  Don't post to the list.
- **Apps:** on 10-15 the owner asked for ObjcMarkdown (the "Markdown
  Viewer Windows" session) and ScreenshotTool ("ScreenshotTool Windows")
  to re-pin to alpha6 with `carry-0.32.0.4` at once. Both were messaged.
  ScreenshotTool's v0.1.3 pins alpha5. ObjcMarkdown declares
  `GSThemeToolbarInMenuBar`, so it's the first real app with #91.

**0.1.0-alpha5** is tag `0.1.0-alpha5` on `e97e54a` (the merge of #128),
a GitHub pre-release with `WinUITheme-0.1.0-alpha5-msys2-clang64.zip`
(SHA-256 `AC0E6F98…C1FA`), tested with `carry-0.32.0.4`.
- **Contents:** alpha4 plus one fix, the toolbar's ">>" overflow at
  125% and 150% on the DPI-aware carried backend (#127), and nothing
  from #125.
- **How it was released (night of 10-14):**
  - the macOS release coordinator asked for it, and #127 and #128 were
    merged under the owner's account;
  - this session tagged it and published the pre-release, on the
    owner's "proceed with everything we can get done overnight" given
    in the session after the steps were listed;
  - the zip was built by hand from `b461455`, whose tree is identical
    to `e97e54a`'s.
- **ScreenshotTool's PR #198** re-pins to it for v0.1.3.

**0.1.0-alpha4** is tag `0.1.0-alpha4` on `d83406b` (the merge of #123),
a GitHub pre-release with `WinUITheme-0.1.0-alpha4-msys2-clang64.zip`,
tested with `carry-0.32.0.4`. It has everything through #122. The
ScreenshotTool and Markdown Viewer sessions were told on 2026-10-14; the
ScreenshotTool session passes it to the macOS release coordinator.

**0.1.0-alpha3** is tag `0.1.0-alpha3` on `f2aaa60` (the merge of #114),
tested with `carry-0.32.0.1`. ScreenshotTool's v0.1.1 MSI pins it with
`carry-0.32.0.1`. ObjcMarkdown's `main` pins it too (`f2aaa603`, its
commit `21aa2ff`; rc3-pre of its 0.2.2 passed a clean-VM check on it) on
the stock MSYS2 libs-back: the carried one was left out of 0.2.2 on
purpose. Moving it to alpha4 with `carry-0.32.0.4` is the owner's call,
for 0.2.2 or 0.2.3.

**0.1.0-alpha2** is tag `0.1.0-alpha2` on `104b12e`. It has a stack overrun
(reading Windows' "Animation effects" can stop an app once hover fades
run); nothing should stay on it.

**Carried libs-back releases** (`danjboyd/libs-back`, packages built by
each tag's GitHub Actions run):

| Tag | Adds | Topic branch |
| --- | --- | --- |
| `carry-0.32.0.1` | client-drawn captions (`GSBackClientDrawsCaptions`); clipboard images | `win32-client-caption`, `win32pbs-images` |
| `carry-0.32.0.2` | `-setShadow::` for borderless windows (DWM shadow, Windows 11 rounding); `setmaxsize` no longer toggles the maximize box (#67) | `win32-popup-shadows`, `win32-setmaxsize` |
| `carry-0.32.0.3` | per-monitor DPI awareness (`GSBackDPIAware`), each monitor's resolution, `WM_DPICHANGED` | `win32-per-monitor-dpi` |
| `carry-0.32.0.4` | each monitor's frame flipped against the primary's height (`c778fc1`); `WM_DPICHANGED` keeps a window the gui placed itself and has the gui lay it out at the new scale (`28119d9`, `d3f9def`); hinted glyph metrics off for a DPI-aware server (`57b3469`); `285c614` | `win32-monitor-frames`; `win32-per-monitor-dpi` (`85a0bc8`, `da386e8`, `1d753ca` there) |

The three new topic branches are hand-ported to upstream master (it has
moved on from 0.32 in `WIN32Server.m`) and **build there with clang and
with GCC**. The GCC build is MinGW GCC 16 with GCC's own runtime
(`gnu-gnu-gnu`): tools-make, libs-base and libs-gui master built into
`C:\gsgcc` (53 MB, kept for later GCC checks; sources and logs in the
2026-10-13 session's scratchpad, `gccgs`), then libs-back with
`--enable-server=win32 --enable-graphics=cairo`. MSYS2's own GNUstep
(clang64 and mingw64) is built on libobjc2, which GCC can't compile
against, and WSL2 can't run on this VM. GCC found one real issue:
`-resolutionForScreen:` called `-monitorHandleForScreen:` before any
declaration, so GCC took it to return `id`. `dcced43` on
`win32-per-monitor-dpi` (and `285c614` on `carry`) declares it in
`WIN32Server.h`; **squash it into the DPI commit before posting**. The
remaining warnings in the changed lines are the file's existing
`(HWND)winNum` casts; the DPI branch now has master's 95 warnings. None
is sent upstream; the owner reviews first.

**GCC builds of the 10-14 commits (2026-10-14 night):** both pass. The
script is `gcc/build-back.sh` in the 10-14 night session's scratchpad
(`d551d6d3-...`); it builds a clone of the local libs-back in that
scratchpad against `C:\gsgcc`:
- `win32-monitor-frames` (`216b061`): GCC build OK, master's 95
  `WIN32Server.m` warnings.
- `win32-per-monitor-dpi-squashed` (`38c77f2`): GCC build OK, 96. The
  extra warning is the `(int)hwnd` cast in the new `WM_DPICHANGED`
  resize event, written as the file writes it 19 times already.
  `CairoFontInfo.m` has none.

`win32-per-monitor-dpi-squashed` is a new **local** branch (worktree
`libs-back-dpi-squashed`): `6f253fd`, `dcced43`, `85a0bc8`, `da386e8`
and `1d753ca` squashed into one commit. Its tree is identical to
`win32-per-monitor-dpi`'s, and it has one message covering all of it. It
isn't pushed and nothing was posted. The X11 build of `da386e8`'s
`CairoFontInfo.m` is still unchecked: no Linux here. On reading,
`windows_are_scaled()` only uses `GSDisplayServer.h` and
`-respondsToSelector:`, both on every platform.

Older notes: the 2026-10-14 commits (`win32-monitor-frames`' `216b061`, and
`85a0bc8`, `da386e8` and `1d753ca` on `win32-per-monitor-dpi`, the last
three worth squashing into the DPI commit too) were built with clang
only: **build them with GCC (`C:\gsgcc`) before posting**. `da386e8`
touches `Source/cairo/CairoFontInfo.m`, which other platforms build:
`windows_are_scaled()` asks the server with `-respondsToSelector:`, so
it's a no-op elsewhere, but check an X11 build too.

**Testing on the carried backend:** `Invoke-QuirkProbe.ps1 -Backend
<bundle>` and `Invoke-ThemeDemoScript.ps1 -Backend <bundle>` copy a
libs-back bundle (`C:\Users\Support\git\gnustep\libs-back-carry\Source\libgnustep-back-032.bundle`)
into the test home's `GNUstep/Library/Bundles`, where gnustep-gui finds it
before MSYS2's. MSYS2 itself still has the stock `gnustep-back 0.32.0`.
Run every change on both backends. Worktrees beside `libs-back`:
`libs-back-carry` (`carry`), `libs-back-setmaxsize`, `libs-back-shadows`,
`libs-back-dpi`, `libs-back-monitors` (`win32-monitor-frames`). Build
`carry` with `Scripts/Invoke-GNUstepMake.ps1 -Directory
C:\Users\Support\git\gnustep\libs-back-carry`.

**0.1.0-alpha1** is tag `0.1.0-alpha1` on `eb9f8b8`.

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
- **Title-bar tabs (#83, #118):** with the theme's caption the bar sits
  in the caption row (`GSWindowTabBarInTitleBar`) after the icon, sized to
  its tabs, with at least 48px left to drag by; the rows beside it are
  drag regions. Every caption is 40px while tabs are on. A stock
  libs-back keeps the bar above the content.

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

### alpha7 (2026-10-15, evening; the owner away overnight)

The owner asked for tabs in the title bar as Notepad and Terminal open,
then tried the candidate in Markdown Viewer and ScreenshotTool and
reported what's fixed below. ReleaseCoordinator (Remote Control) holds
ScreenshotTool v0.1.4 and Markdown Viewer 0.2.3 for it, and wants the
release URL and the tag's commit SHA.

**In #135 (`alpha7-tabs`), one commit per issue:**
- #133: a window that can tab shows its strip with one tab and a "+";
  the theme replaces `-[NSWindowTabGroup isTabBarVisible]` and
  `-_toggleTabBar` (the rule belongs in danjboyd/gnustep-window-tabbing).
- #72 (part): tabs on by default; `WinUIThemeWindowTabs NO` turns them
  off.
- #134: with `WinUIThemeMenuStyle = more`, title-bar tabs and no toolbar,
  the "..." sits right after the "+" and the menu row goes
  (`-menuHeightForWindow:` 0; the menu view stays the decoration's
  subview, placed over the caption).
- #136: submenus beside their item (`-locationForSubmenu:`), the
  safe-triangle aim (0.3s rest), menus closing as the window moves or
  resizes.
- #137: no flash on "+". Recordings showed two causes: layered windows
  show nothing until flushed, then Windows drew its own title bar over
  blank content. A never-shown tab's window now goes behind the old one
  and comes forward 0.1s later, drawn; Windows' show/hide transitions are
  off for the swap (`DWMWA_TRANSITIONS_FORCEDISABLED`, back on after
  0.5s). Switching to a tab shown before is immediate (a 50ms delay there
  broke Ctrl+Tab's check). `_switchToWindow:` is replaced too; upstream
  it to the shared code.
- #138, #141: segmented control: label centred over the pill; every
  label in the primary text colour (Toolkit Segmented). #141 is one
  commit to revert if the owner prefers grey.
- #139: per-app defaults read from the bundle-identifier domain, as
  NSUserDefaults names it (`defaults write com.danboyd.screenshottool
  ...` was ignored). QuirkProbe has a bundle identifier now.
- #140: in the single row, view items (segmented controls, push buttons)
  are compact 24pt controls, centred, segment icons 16pt.

Every new check fails on the build before its fix. Full matrix (8
configurations, both backends): see the PR for the last run.

**Release prep (ready):**
- `version-0.1.0-alpha7` (`9134e99`), the Version commit on #135's head;
- the zip, built from `9134e99`:
  `WinUITheme-0.1.0-alpha7-msys2-clang64.zip`, SHA-256
  `c8e67d70fbd0b5cd85bc46f1773930545df2bf6d1796fcb4c796ff732f47932c`, in
  the 10-15 session's scratchpad (`rel7`); rebuild it if anything moves.
- **To release:**
  1. the owner merges #135 (and #143 if he says yes to the accent API; then
     rebase the Version commit onto it, add #142 to its notes, rebuild the
     zip);
  2. open and merge the Version PR;
  3. check the merge commit's tree equals the built commit's;
  4. annotated tag `0.1.0-alpha7`;
  5. `gh release create --prerelease` with the zip and alpha7's changelog
     section;
  6. download it back and compare the checksum;
  7. send ReleaseCoordinator the URL and the tag's SHA, and ScreenshotTool
     Windows and Markdown Viewer Windows the same.
- **MSYS2:** don't update this VM's MSYS2 before releasing. clang 23 with
  gnustep-base 1.31.1-10 fails on `__block` ivars (libs-base#807, fixed by
  #809); this VM has clang 21.1.8 and gnustep-base 1.31.1-5. If it's
  updated, patch the header as danjboyd/tools-xctest v0.5.1 does.

**Decisions waiting on the owner:**
1. Merge #135 and release.
2. #143's name, `-setGSThemeStyle: @"accent"` on NSButton and
   NSButtonCell, matching Adwaita's branch `gsthemestyle-accent`
   (3c2c1da); in alpha7 or after. ScreenshotTool's Copy and Take
   Screenshot already call it, guarded.
3. Keep #141 (primary-colour segment labels) or revert.
4. The two hand checks: Snap with Win+arrow on a tabbed window, and a
   click on a new tab's close button. Real mouse buttons don't work on
   this VM (above).
5. Segmented control's look after alpha7: the Toolkit Segmented (ours)
   or WinUI's own SelectorBar (a text row with an underline). Neither is
   in the reference app yet; add both and measure.

**Known gaps in alpha7:**
- The first new tab in a session showed the wrong cursor once for the
  owner (not caught by the recordings, which have no pointer); fixed
  itself after a move.
- The menu row's height is 0 while the "..." is in the title bar, and
  libs-gui adjusts a window's frame by the theme's row height when the
  menu is added and removed: a menu removed after the "..." moved in or
  out leaves the window a row off.
- The toolbar's ">>" and the "..." are separate overflows (CommandBar
  has one).
- NSColorWell in a toolbar is a square swatch in a bordered button;
  WinUI's is a DropDownButton (a rounded swatch, or Paint's glyph and
  colour bar, and a chevron). Asked for by ScreenshotTool's redesign.
- Mica and DWM rounding still unseen on a GPU.

**Other sessions tonight:** ScreenshotTool Windows (local) shares the
desktop and asks before taking it; ScreenshotTool's WinUI redesign
(v0.2.0, ScreenshotTool#221) leans on #140 and #142.
plugins-themes-adwaita (Remote Control) has the same accent API on a
branch, waiting on the owner's name. ReleaseCoordinator collects hand-offs
into a morning digest.

### Open issues not yet addressed

| Area | Issues |
| --- | --- |
| Tracking | #105 remaining WinUI gaps (checklist below); #50 Adwaita parity |
| Windows | #72 tabs on by default (draft PR #97, phase 2 of the shared code, awaits the owner's review) |
| Fidelity | none: #91 (single-row chrome) and #130 (menus behind "...") shipped in alpha6 and are closed |
| System | #47 Mica: implemented (#117), the blurred backdrop unchecked on a GPU |
| Testing | #19 real-app backlog |

### WinUI 3 parity: what's left

The static look measures 0 out of tolerance against the WinUI 3
reference app, and two-monitor checks at 125% and 150% pass. #105's
checklist, done since it was written: the hover, pressed and toggle
motion, the menu slide, the alert fade, measured reference checks,
per-monitor DPI, browser row hover, box titles, the date picker's hover
and buttons, the combo list, text size reaching open windows, context
menus at the screen's edges, real input in ScreenshotTool and Gorm.
What still separates an app from a first-rate WinUI app:

1. **Unchecked on a GPU:** Mica's blur, DWM rounding and shadows on
   Windows 11 (the OCI VMs have no GPU either), and Snap with Win+arrow
   on real hardware (it works on the VMs).
2. **Second-monitor edges** (OCI run 3): the first menu after launch can
   show a dark strip until it reopens (the panel's first screen is screen
   0); a pop-up list on a monitor at another scale than it last opened on
   is narrower than its button (sized at the previous scale); a window
   grows about 6px per round trip between monitors. The likely causes
   are under "The second-monitor edges" below.
3. **Minimum and maximum sizes:** `-setMinSize:` in points is taken as
   pixels on a scaled display (gnustep-gui's frame sizes are device
   pixels; `-setContentMinSize:` is scaled). A libs-gui question, not
   changed.
4. **Motion:** done; ContentDialog's scale shipped in alpha6. #105's
   checklist still shows it, and paused/error progress and slider
   ticks, as open: tick them.
5. **API decision:** made. Paused and error progress are
   `-setGSThemeState:` (option 1 below), shipped in alpha6 with the
   owner's approval of #125. Slider ticks needed no decision: NSSlider has
   `-setNumberOfTickMarks:` and `-setTickMarkPosition:`, which libs-gui
   just doesn't draw. The theme draws them now (#125).
6. **Chrome:** tabs on by default (#72); per-window compact metrics for
   nib windows. That's a design question (how to tell a nib window from
   a code-built one); Adwaita doesn't do it either, despite #105's note
   (its HANDOFF_OPEN_ISSUES #24 lists it as open). Single-row chrome
   (#91) and menus behind "..." (#130) shipped in alpha6. Still open
   there: the toolbar's ">>" and the "..." are two overflows where a
   CommandBar has one, and Terminal's placement (the menu beside the
   tab row's "+") isn't done.
7. **Upstreaming** the carried libs-back changes (GCC, then the owner's
   review).

### Real input (2026-10-13 and 14, owner's permission)

`RealInput.psm1` and `Start-App.ps1` (now in the 2026-10-14 session's
scratchpad, `real`) drive real clicks (SendInput) and start an app in a
test home on the carried backend (`-ExtraPath` adds DLL directories, as
Gorm's frameworks need). Checked in ObjcMarkdown and ThemeDemo on
10-13: menu bar items, pop-up choices, File > New opening a tab, tab
clicks, dragging and double-clicking the strip beside the tabs, the
restore button, context menus. Found and fixed in #120: Mica's doubled
caption buttons, context menus closing on the opening release, the
maximize button's stuck hover.

On 10-14:
- **ScreenshotTool:** the File menu, the Open split button's menu, the
  Highlighter Settings popover (a flyout), tool tips. Nothing found.
- **Gorm** (1.5.0 in the 2026-10-08 session's scratchpad, `gorm`):
  menus, the "…" overflow, the palettes. Found: a click on an item with
  a submenu (Tools > Palettes) closed every menu; fixed in #122
  (`menu-submenu-click-stays-open`). Escape closes a closable palette
  panel: that's libs-gui's `-[NSPanel keyDown:]`, as in AppKit. Gorm's
  palettes take clicks for dragging, so their controls don't respond;
  dropping a control into a real .gorm file is still untried.
- **A real 150% on this VM:** set with `DisplayConfigSetDeviceInfo`
  (the scratchpad's `stage/lib.ps1`, which needs Windows PowerShell 5.1,
  `powershell.exe`), with the ScreenshotTool session told first, and set
  back to 100%. No text gaps on the QXL adapter.

### OCI (2026-10-13 and 14)

Test VMs go in the `OracleTestVMs` compartment (`us-phoenix-1`,
`oracletestvms-vcn`, public subnet); the tenancy runs production VMs, so
nothing else is touched. On 10-14 the owner allowed a Windows Server 2025
VM and VirtualDrivers' signed virtual display driver (its signer added to
TrustedPublisher) for a second monitor. Each run had its own NSG (SSH
from this machine only) and was reached over OpenSSH set up by the
launch script (`#ps1_sysnative` user data), with no WinRM. The
interactive desktop came from autologon and `schtasks /it`. Three runs
(`winuitheme-dpi`, `-dpi2`, `-dpi3`), all terminated with their boot
volumes, their NSGs deleted. Scripts and screenshots are in the
2026-10-14 session's scratchpad (`stage/`, `oci/`, `dpiinfo/`,
`shots*/`). The layout: the virtual display 1920x1080 primary at 150%,
the VM's adapter 1280x800 at 125% beside it, top-aligned. A test home's
`NSGlobalDomain.plist` written by Windows PowerShell's `Set-Content
-Encoding UTF8` gets a byte-order mark and is ignored; pass `-GSTheme`
and `-GSBackDPIAware YES` as arguments.

What the runs found, all fixed in #122 and `carry-0.32.0.4` except the
edges listed above: the caption covered by the menu bar at 125% and
150%; the date flyout ~110px high and the combo list a row short; a
window taller than the screen losing its caption; secondary-monitor
frames flipped against the wrong height; reused menus shrunk and laid
out at the old scale; tool tips on the wrong monitor; text views spaced
unevenly (hinted metrics).

### Overnight, 2026-10-14 to 15 (unattended)

The owner asked for work without check-ins and allowed pushing branches
and draft PRs, but not merging. What was done:
- **#91, the toolbar in the menu bar's row** (draft #125). An app
  declares `GSThemeToolbarInMenuBar`; README "Toolbar in the Menu Bar"
  has the details.
  - The code is in `Source/Native/WinUIThemeToolbarInMenuBar.m`, a
    category on GSWindowDecorationView that the theme's two decoration
    views call.
  - Probe checks: `toolbar-in-menu-bar` and `toolbar-in-menu-bar-off`.
  - All 8 configurations pass on both backends.
  - ObjcMarkdown's viewer (dev build 20261009, which declares the key)
    shows two chrome rows in light, dark and high contrast, with
    Read/Edit/Split at the row's end. Captured with PrintWindow; no
    input was used, and the window was widened with `MoveWindow`.
  - That run found the row's line missing under buttons over Mica,
    fixed in #125 (the probe runs without Mica).
  - At 486px wide, Read/Edit/Split (182pt) folds into ">>", which is
    correct.
- **Slider tick marks** (#105, in #125), probe check `slider-ticks`.
- **Paused and error progress** (#105, in #125): option 1 of the
  proposal below, `-[NSProgressIndicator setGSThemeState:]`. It's an
  API choice the owner reserved, so it's its own commit (`57abccd`), easy
  to drop.
- **An alpha4 regression, fixed in #125 (`4303574`).** The ScreenshotTool
  session's alpha4 pin check found it: at 125% and 150% on
  `carry-0.32.0.4`, ScreenshotTool's Copy (after a flexible space) went
  into the toolbar's ">>" menu with the row half empty.
  - libs-gui rounds the flexible space's frame to device pixels
    (`-centerScanRect:`), a fraction of a point past the toolbar's width,
    and its fit test (`-_visibleBackViews`) then fails.
  - alpha3 didn't show it: its process was DPI-unaware, so the gui drew
    at 1.0.
  - QuirkProbe `toolbar-flexible-space-scaled` uses GSScaleFactor 1.5 at
    40 widths.
  - **ScreenshotTool's PR #198 (alpha4 + carry `.4`) is on hold** for a
    release with this fix. Send the ScreenshotTool session the
    alpha5 tag and commit once it's tagged.
  - That session also saw posted quick clicks on the Open split button
    not leave its menu open at 125% (they did at 100%), though the menu
    opens on press. It may be the input simulation; worth one
    real-mouse check.
- **libs-gui master** (`fdc5cfe83`, built in the scratchpad's
  `gui-master`, not installed): the probe passed in light, dark, high
  contrast and light-150. The one failure first seen was the probe's
  own: master renumbers NSTextAlignment as AppKit does. Fixed in #125.
- **Compare-Reference** on #125: 0 out of tolerance in light and dark.
  That includes the body text's width (277 vs WinUI's 274px), so
  #105's "text width" item has been measured since #108.
- **GCC builds** of the 10-14 libs-back commits and a squashed DPI
  branch (above).
- **The ScreenshotTool session** borrowed the desktop three times: its
  alpha4 pin check at 100/125/150% (set back to 100%), a clipboard
  check, and its v0.1.2-rc1 check. This session used no desktop while
  it had it.
- **#125's head (`f1eab64`):**
  - all 8 configurations: 0 failures on `carry-0.32.0.4`, and on stock
    but for one "dusk" run that stalled at startup (no check had run)
    and passed on a rerun;
  - every commit clean-builds, theme and probe.

- **A `/code-review` of #125** found ten candidates. Nine are fixed
  in #125:
  - the setting's domain order;
  - defaults changes from other threads;
  - a theme switch leaving toolbars in the row;
  - libs-gui's own decoration views being touched;
  - image-less items in the row;
  - a baseline turned on while in the row;
  - ticks from the unrounded track;
  - the scaled check passing vacuously;
  - copying every defaults domain on each change.

  The tenth: the flexible-space rounding fix belongs in libs-gui
  (`-[GSToolbarView _visibleBackViews]`, a half-device-pixel tolerance),
  where it would help every theme. A candidate for a libs-gui carry
  branch or upstream; the theme's fix stays meanwhile.

Choices made without the owner, each a small revert:
- In the menu bar's row:
  - toolbar items are 32pt with 16pt icons;
  - there's 4pt between the menus and the commands, and 4pt at the
    row's end;
  - the toolbar keeps at least 60pt before the menus fold;
  - the row has the menu bar's background and line.
- Ticks are 4pt out from the track, under the thumb, rather than in
  rows of their own.
- The DPI squash's commit message is new: one description covering
  the five commits.

### A real 1.5 scale in the probe (`scaled-150`, in #125)

The alpha4 toolbar regression showed only with the gui drawing at 1.5,
which no configuration covered: `light-150` scales the theme's metrics,
not the gui. `-Configuration scaled-150` passes `-GSScaleFactor 1.5` and no
`--scale`: a DPI-aware process gets the theme's metrics at 1.0
(`WinUIThemeSystemDpi`), and the gui does the scaling. It's opt-in, not
in the default list.

It first hung: the probe's synthetic clicks took window coordinates (device
pixels at 1.5) as points, and a press landed on a button whose tracking
loop waited forever. Fixed in #125.

On the stock backend it now runs clean: 187 passed, 0 failed, 2 known.
- **Probe fixes (#125):**
  - at a fractional scale the backing-store read leaves up to 6px
    transparent along a render's top and right, which checks took for
    black; `QuirkProbeRender` fills it;
  - `menu-bar-overflow` narrows its window in device pixels;
  - two checks allow a pixel of rounding at a fractional scale only.
- **A theme fix (#125):** the overlay scroll bar showed its indicator over
  content at rest. The clip view's sub-pixel snap was taken for a
  scroll.
- **Known at 1.5:** a checkbox's and a radio's edges after their
  animations.
  - The cause, measured against a full window redraw: any non-opaque
    control redrawn from `-setNeedsDisplay:` differs at its antialiased
    edges (a button 24px, a switch 92, a checkbox about 95). libs-gui
    draws it again over its old pixels, without what's behind it;
    animations do that once a frame.
  - It's barely visible at 1.0, plainly at 1.5.
  - The fix belongs in libs-gui: redraw the opaque ancestor's area for
    a non-opaque view, as Cocoa does. A candidate for a libs-gui carry
    branch.
  - Marking the motion clock's views' opaque ancestors from the theme
    was tried and didn't settle it.
- **On the carried backend** the forced factor contradicts per-monitor
  DPI on a 100% monitor (`dpi-per-monitor-aware` and the caption hit
  tests fail). A real check there needs the monitor at 150%.

Suggested: add `scaled-150` to the default list, or at least run it
before each release.

ObjcMarkdown at `-GSScaleFactor 1.5` on the carried backend looks right:
one chrome row, Read/Edit/Split at the end, no stray indicator. Making
scaled-150 pass, by fixing the checks to measure in points, would make
it a regression gate for the DPI-aware backend.

### Tried overnight

- **ContentDialog's scale** (#105) is done in #125 (`76b21d0`), on the
  second try.
  - The first (`5696766`, reverted in `2c1a955`) scaled the alert's
    content view's bounds. Its title and message didn't draw while it
    scaled, and the bounds-only probe check missed that.
  - Now a snapshot of the drawn content is shown scaled over it from
    105% to 100% over 250ms, passing clicks through, and removed at the
    end.
  - The check looks at the drawing: the snapshot must have the text's
    ink in it.
  - A ThemeDemo capture 60ms in shows everything drawn, slightly
    larger.
- **libs-gui rounding a non-opaque view's invalid rect** to device
  pixels, as it does an opaque one's (`NSView.m`,
  `-_setNeedsDisplayInRect_real:`). The patch is in the 10-14 night
  session's scratchpad (`gui-nonopaque-invalidrect.patch`). Built on the
  carry branch and run under the probe, it didn't change the 1.5 edge
  differences. Either it isn't the cause, or the probe didn't load the
  patched DLL; it wasn't proven which.

### The second-monitor edges: what the code says

Nothing was changed: none of this shows without a second monitor at
another scale, so a fix would go out unchecked. What reading the code
found, for the next OCI run:

- **Frames are converted at the key window's scale.**
  - gnustep-gui's `+[GSWindowDecorationView
    contentRectForFrameRect:styleMask:]` and
    `+frameRectForContentRect:styleMask:` scale by `[[NSScreen
    mainScreen] userSpaceScaleFactor]`. Their own FIXME says they should
    take a screen. `[NSScreen mainScreen]` is the key window's screen.
  - A window is drawn at `[window userSpaceScaleFactor]`, its own
    `_screen`'s.
  - So a menu panel or pop-up list opened from a key window on one
    monitor and shown on the other is sized at the first one's scale
    and drawn at the second's:
    - sized at 125% and drawn at 150%, it's narrower than its button;
    - sized at 150% and drawn at 125%, it's wider than what's drawn in
      it, leaving a dark strip on its right. A new panel's `_screen` is
      screen 0, the 150% primary, until it's first placed.
  - The proper fix is gnustep-gui's: give the conversions the window's
    screen. The instance methods could; the class methods can't.
  - The theme could size its own pop-up lists and flyouts from the
    target screen, as the date flyout and combo list already do. Menus
    the gui draws still go through the class methods.
- **The 6px growth per round trip** is likely the frame offsets.
  - libs-back's `-styleoffsets::::` asks `AdjustWindowRectEx`. In a
    per-monitor-aware process that gives the primary's (the system
    DPI's) border sizes.
  - On the 125% monitor the real resize border is a pixel or two
    thinner each side.
  - Each move converts frame to content with one and content to frame
    with the other, about 3px a move.
  - To check: log `-styleoffsets` against `AdjustWindowRectExForDpi(...,
    GetDpiForWindow(hwnd))` on the 125% monitor.
  - If they differ: convert with the window's own DPI where the backend
    has the window (`WM_SIZE`, `-placewindow::`), or report offsets for
    the monitor the window is on.

### Paused and error progress: a proposal

WinUI's ProgressBar has `ShowPaused` (a yellow bar,
SystemFillColorCaution) and `ShowError` (red, SystemFillColorCritical).
For an indeterminate bar, both stop the animation and show a full bar.
NSProgressIndicator has neither, and Cocoa has no equivalent. Options:

1. **A theme-neutral informal property** that apps set and any theme
   may read, like `GSThemeToolbarInMenuBar`: a category declared by the
   app, `-[NSProgressIndicator setGSThemeState:]` taking `@"paused"`,
   `@"error"` or nil, stored with `objc_setAssociatedObject`. The theme
   draws it. Other themes and AppKit ignore it, and apps can call it
   behind `-respondsToSelector:`.
2. **Upstream in libs-gui**: a real `GSProgressIndicatorState` property.
   Cleanest, but it waits on GNUstep.
3. **Reuse `-setControlTint:`** (NSGraphiteControlTint as paused, and
   so on). No new API, but the meanings are invented.

Decided: option 1, shipped in alpha6 (`57abccd`, approved with #125 on
10-15). Option 2 can still be proposed upstream later with the same
values.

### Suggested next five (the owner decides)

1. **Release alpha7** (the steps under "alpha7" above), with or without
   #143, then tell ReleaseCoordinator and both app sessions.
2. **Upstream the theme's overrides of the shared tabbing code** to
   danjboyd/gnustep-window-tabbing: the one-tab strip, the toggle, and the
   switch's order and reveal (#133, #137); then the libs-back topic
   branches (#246's FSF question).
3. **The colour well as WinUI's DropDownButton** in toolbars
   (ScreenshotTool#221), and one overflow under `more`.
4. **Segmented control vs SelectorBar:** add the real Toolkit Segmented
   and SelectorBar to the reference app, measure, and let the owner pick.
5. **A stable gate:** rewrite `Docs/RELEASE_READINESS.md` for a
   `0.1.0-beta1`; a GPU session (rounding, Mica, Snap).

### Known gaps in finished work

- **Menus behind "..." (#130):**
  - the toolbar's ">>" and the "..." are separate overflows;
  - a window without a toolbar keeps a whole row for the button;
  - the flyout's items are copies made each time it opens, as the
    narrow bar's overflow menu's are (#77), so their submenus are
    copies too: compare menus by title, not identity;
  - the probe's offscreen render of the flyout is blank (its menu
    views don't draw their items), so the visual check is ThemeDemo
    with `-WinUIThemeMenuStyle more` and `key alt+e`. ThemeDemo's
    command scripts have no F10 key; the probe covers it.

- **Shadows (#39):** the carried backend gives a borderless window a
  thick frame and a caption with `WM_NCCALCSIZE` returning 0, and extends
  DWM's frame one pixel; on this VM the shadow shows, the rounding can't.
  `CS_DROPSHADOW` draws nothing here. The theme asks from
  `WinUIThemeWindowIntegrationMakePopup` and `...RoundPopupWindow`.
- **DPI:** gnustep-gui scales through the decoration view's bounds;
  window base coordinates are device pixels, so what a theme gives the
  backend in base coordinates (caption regions) is already in pixels.
  The class methods (`+contentRectForFrameRect:styleMask:`) scale by the
  main screen's factor and leave the content's origin unscaled; the
  theme's caption offsets allow for both (#122). Window placement code
  that mixes a view's points with screen pixels (flyouts, the combo list)
  multiplies by `[[NSScreen mainScreen] userSpaceScaleFactor]`. Probe
  checks at 1.5 set `GSScaleFactor` in the defaults (`*-scaled`).
  `AdjustWindowRectEx` in `styleoffsets` uses the system DPI, so frame
  offsets on a monitor at another scale may be a pixel off. ThemeDemo's
  window is taller than a 1080p screen at 150%: its fixed-frame content
  then sits partly under the toolbar (its layout, not the theme).
- **Mica:** the probe turns it off (`WinUIThemeMica NO`) for every check
  but `mica-chrome`, because the others measure ink against the chrome's
  background, which is transparent under Mica. The theme's opaque blended
  fills on the menu bar and toolbar (other than hover) are tuned for the
  solid window colour.
- **Context menus (#120):** the opening release is dropped while the
  pointer stays within 2px of the press. The probe's real-click check
  passes on the previous build too (its window doesn't put the menu
  where ObjcMarkdown's did); the ObjcMarkdown runs are the evidence.
- **Switches (#120):** they flip on a release over them, not on the
  press; the theme runs its own tracking loop (10s timeout) in
  `-[NSSwitch mouseDown:]`. Keyboard toggling is libs-gui's.
- **Menu-item fades (#120):** checked in ObjcMarkdown only; the probe's
  offscreen menu views don't redraw highlighted items through the theme.
  `motion-row-hover-fades` is known at 150% (no hover fill in the probe
  there, cause not found).
- **Hover (#120):** a hover is dropped when the window's frame changed
  since the pointer entered and Windows says the pointer isn't over the
  view (`WindowFromPoint`).
- **Title-bar tabs:** the drag regions are the rows either side of the
  bar; the "+" sits right after the tabs because the bar is sized to them.
  Tabs narrow to 40px, then run past the bar. Only `WM_NCHITTEST` was
  checked, not real clicks or drags.
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
- **Menu and tool tip rounding (#39) is untested on a GPU.** This VM
  (QXL adapter) rounds no windows, the WinUI reference app's included.
  The carried backend now frames them for DWM; check on Windows 11 with a
  GPU.
- **Live settings (#46):** checked by sending the theme's listener window
  ImmersiveColorSet with an accent override, not by changing Windows'
  settings, which would disturb the desktop. Toggle light/dark, the accent
  and a contrast theme by hand once. libs-back's windows are DPI-unaware, so
  Windows sent them no `WM_DPICHANGED` (the carried backend is DPI aware
  now). A text-size change reaches open windows (#122) for fonts at the
  theme's sizes; frames stay as the app laid them out, so text can
  outgrow a fixed control.
- **Hover when the pointer is already inside:** a tracking rect added under
  the pointer gets no entering, only the exit. Tables work round it from
  `-mouseMoved:`; buttons and scroll bars show their hover once the pointer
  has crossed their edge.
- **No paused or error progress state, no slider ticks:** NSProgressIndicator
  has no such states, and libs-gui draws no tick marks.
- **Pointer checks can flake** when something else on the desktop takes the
  pointer or focus: once in this work, `button-hover`, `table-row-hover` and
  `scroller-hover-expands` all failed in one configuration and passed on
  reruns. Rerun before suspecting the theme. On 10-14 the first
  configuration of a fresh full run on a just-built carried backend twice
  lost `button-hover`, `table-row-hover` and
  `menu-submenu-click-stays-open`, then passed in two clean reruns. Close
  other apps first (a Gorm left open broke them too).
- **Date picker (#56):**
  - Stepping a field from the keyboard without opening the flyout isn't
    offered: WinUI's DatePicker doesn't either (Space or Enter opens the
    flyout, whose columns step). On libs-gui after 0.32 the flyout
    replaces libs-gui's own field selection and stepper.
  - TimePicker has no seconds, so a picker set to show seconds hides them.
  - The flyout's up and down buttons step once per click; WinUI's repeat
    while held.
- **Browser (#58):** the columns are cards 8pt apart, as in the reference
  app, rather than one surface split by hairlines. Hover is driven by the
  column matrix's `-mouseMoved:` (an NSMatrix override; NSBrowser is
  left alone, see the fonts note below).
- **Boxes (#27):** titles are BodyStrong at the body size when the app
  left libs-gui's default font; a box laid out in Gorm for the small font
  gives its content a few points less. An app's own title font stays.
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
  - `-Backend <bundle>` runs on another libs-back bundle (the carry build);
  - `-Pointer` runs the four checks that move the real pointer, which
    skip by default (`-NoPointer` is still accepted);
  - `-Configuration light,dark` picks configurations;
  - `-Theme <path>` checks another build;
  - `-OutputDirectory <dir>` saves renders.
- **Coverage:** about 185 checks a configuration: in light, 176 pass on
  the carried backend (9 skip) and 170 on stock (15 skip: the caption,
  shadow, DPI and title-bar tab checks need carry), 4 of them moving the
  pointer. In high contrast and the contrast themes some checks skip
  with a reason.
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
