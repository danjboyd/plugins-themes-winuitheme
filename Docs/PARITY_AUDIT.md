# Parity Audit Against the Adwaita Theme

Audit date: 2026-10-06. Baseline: `main` at `48d21f0`, libs-gui master
`549f63913` (pulled the same day), and `plugins-themes-Adwaita` at `121c5cd`.

## Correction: the audit ran on gnustep-gui 0.31

The audit's captures were taken on MSYS2's gnustep-gui **0.31.1**. That
release's theme loader misparses `_override<Class>Method_<selector>` names
(fixed upstream in libs-gui `a8018d6c8`, first released in 0.32.0). As a
result:

- none of the theme's 23 method overrides were installed
- the loader overran a stack buffer once per override, so some symptoms
  changed from build to build

On gui 0.32.0 (installed on this machine 2026-10-06):

- **D3 (scrollers on the left) had a second cause: the build.** The bundle's
  plist was listed as a resource, `Resources/Info-gnustep.plist`. After a
  clean build, gnustep-make's generated `Info-gnustep.plist` replaced it, and
  the shipped theme lost its whole `GSThemeDomain`, including the Windows 95
  menu and scroller styles. The plist is now `WinUIThemeInfo.plist`, which
  gnustep-make merges into the generated file. The theme's "trailing
  scroller" workaround was removed. The probe checks `theme-domain` and
  `scroller-trailing-edge` guard this. The Adwaita theme ships its plist the
  same way.
- **D4 (bitmap checkboxes) does not occur.** The theme's vector checkboxes and
  radios draw, correct in dark mode and in the mixed state. The PNG mappings
  remain only as a fallback, and the WinUI styling work in the issue still
  applies.
- D1, D2 and the subclass-override gap were real on 0.32 too. They are fixed
  on the `adwaita-parity-phase-a` branch, with probe checks.

gnustep-gui 0.31 is no longer supported (see `WINDOWS_BUILD.md`). The other
findings below were not re-verified individually on 0.32.

## The bar

Adwaita's standard is that an ordinary GNUstep app looks and behaves like a
first-rate native app **without changing its code**. To hold that standard,
the Adwaita theme:

- fixed 81 issues found in real apps (`Docs/IMPROVEMENTS.md` there)
- worked around GNUstep bugs and filed them upstream
- runs a regression probe (`make check-quirks`, seven configurations) that
  measures rendered pixels

WinUITheme has the scaffolding (palette, metrics, drawing helpers, native
dialogs, DWM title bars). It does not yet meet that standard. Some of its
gaps are visible on the first page of its own demo.

## How this audit was done

- Built the bundle and `ThemeDemo` with MSYS2 clang64.
- Ran ThemeDemo against the built bundle by absolute path (not the installed
  copy) and captured the `controls`, `text-input`, `data-views`, `commands`,
  `dialogs` and `real-app` pages in light mode, plus `controls` in dark mode.
- Read all theme sources and compared them, surface by surface, against
  Adwaita's fixed list and its theme hooks.

## 1. Defects visible in the current build

Each of these was seen in the captures.

| # | Defect | Likely cause |
| --- | --- | --- |
| D1 | **Windows have no menu bar.** ThemeDemo installs its main menu and then creates its window. That window never gets a menu bar. Most apps that build their windows in code do the same. | libs-gui bug: with `NSWindows95InterfaceStyle`, windows created after launch get no menu (Adwaita upstream draft 2). Adwaita works around it with `-windowNeedsMainMenu:`; WinUITheme has no workaround. |
| D2 | **Table and outline headers draw every title twice**, one copy offset from the other ("Name Name", "Size Size", "Status Status", "Project Project", "Documents Documents"). | `drawTableHeaderCell:` draws the title, and libs-gui draws it again. |
| D3 | **Vertical scrollers are on the left edge** of every scroll view (main page, tables, outline, editors), with arrow buttons at bottom-left. | The theme sets `NSScrollViewInterfaceStyle = NSWindows95InterfaceStyle` in `GSThemeDomain`, which should put scrollers on the right. User defaults do not override it. The theme's `_overrideNSScrollViewMethod_tile` "trailing scroller fix" does not take effect. |
| D4 | **Checkboxes and radios are bitmaps.** In dark mode they are white boxes and white dots. A mixed-state checkbox shows a checkmark. They ignore the accent colour and DPI. | `Info-gnustep.plist` maps `NSSwitch`/`NSRadioButton`/`common_*` to five 26×18 light-mode PNGs. The vector drawing in `WinUIThemeDrawCheckboxOrRadioIndicator` is bypassed. |
| D5 | **Switches (NSSwitch) are nearly invisible.** The "On" switch looks the same as "Off": a pale pill with no accent and the knob at the left. | libs-gui 0.32 creates `NSSwitch` disabled (noted by Adwaita), and `drawSwitchBezel:` ignores the state when disabled. Separately, the track stretches to fill its frame; WinUI's ToggleSwitch is a fixed 40×20 (Adwaita fixed the same problem in its #85). |
| D6 | **Stepper arrows are upside down** (∨ on top, ∧ below). | Chevron direction is not adjusted for non-flipped coordinates in `drawStepperCell:`. |
| D7 | **Combo box shows "…" and no value.** | GNUstep's button image shows through. The editable combo's text path isn't reached. |
| D8 | **Search field**: the magnifier sits outside the field, and the cancel button is GNUstep's red ✕ (`GSStop`). | `WinUIThemeDrawSearchGlyph` and `WinUIThemeDrawDismissGlyph` are drawn in the cell frame rather than the field's inset button rects. |
| D9 | **Default button and progress bar have a glossy top highlight.** | A `topHighlight` white overlay over the top 42%. This is a Windows 7–era look; WinUI has no gloss. |
| D10 | **Menus have a grey "icon gutter" strip** and square corners. | `drawBackgroundForMenuView:` paints a Win32-classic gutter. Corners are square because a rounded fill on an opaque popup leaves dark corners (see W6 for the native fix). |
| D11 | **The bundle can't be built with its own script.** The last commit changed `Scripts/Build-ThemeBundle.ps1` to call a `gnustep` CLI that isn't installed. | Revert to the MSYS2 bash recipe, or document how to install the CLI. |

Demo-only problems, not the theme's fault, but they hide theme bugs:
ThemeDemo's labels don't call `setBezeled: NO`, so every label draws as an
empty text field. The sidebar list is laid out bottom-up. The "toolbar" on the
`real-app` page is an `NSBox` of buttons, so `NSToolbar` is never exercised.

## 2. What Adwaita covers and WinUITheme does not

These are behaviours an unmodified app gets under Adwaita. Under WinUITheme it
gets GNUstep's defaults or nothing. Numbers in parentheses refer to rows in
Adwaita's `Docs/IMPROVEMENTS.md`.

### Correctness and robustness

| Area | Adwaita | WinUITheme |
| --- | --- | --- |
| Overrides reached from subclasses (`GSToolbarButtonCell`, `NSSecureTextFieldCell`, `NSTableHeaderCell`, `NSSearchFieldCell`) | `GnomeThemeOriginalMethod()` walks superclasses, because libs-gui's `-overriddenMethod:for:` matches only the exact class. Upstream still has this bug as of `549f63913`. | Calls `-overriddenMethod:for:` directly, which returns `NULL` for subclasses. Image-bearing `GSToolbarButtonCell`s then draw **nothing**. This is the same bug that made Adwaita's toolbar icons disappear (1). |
| Late-created windows get the menu | Yes (19) | No (D1) |
| Methods replaced with Objective-C categories | None | `NSSegmentedCell -drawSegment:...` and 8 `NSMenuItemCell` methods are category overrides. The compiler warns about all 9. They replace the methods for the whole process, survive a theme switch, and can't call the originals. |
| `NSTextAlignment` numbering differs between gui 0.32 and master | Resolved at run time (71) | Not handled. Centred and right-aligned text will swap on master. |
| `sizeToFit` matches drawing geometry (buttons, checkboxes) | (2, 3, 58) | Not audited. Margins are hand-tuned constants. |
| Multi-line labels and alert text | (4) | Not handled |

### Surfaces Adwaita themes and WinUITheme leaves to GNUstep

| Surface | Adwaita | WinUITheme |
| --- | --- | --- |
| **NSToolbar** | Content-sized items, icon-only default, hover and pressed backgrounds, view items keep their width, labels in the text colour (25, 26, 32, 40, 64, 66) | Nothing. libs-gui's fixed 62pt rows and dark-grey bottom line. |
| **Tool tips** | Native look (61, 79). Wayland workarounds (29) aren't needed on Windows. | GNUstep's pale-yellow box. WinUI tool tips have 8px corners, a 1px border and a shadow. |
| **NSAlert** | Re-laid out as the platform's dialog (34) and attached as a modal of its window (78) | GNUstep's NeXT layout: icon, left title, groove line. A WinUI `ContentDialog` has a title, body, and right-aligned equal-width buttons with the accent button first, on a card with a footer band. Alternatively, hand off to `TaskDialogIndirect`. |
| **Application menu** | An empty app menu is removed; Hide, Hide Others and Show All are dropped; Cocoa-style app menus are adopted (27, 37, 38) | The app-name menu and Hide/Services appear in a Windows menu bar. A Windows app has File… Exit and Help › About instead. |
| **Template / symbolic images** | Tinted with the surrounding text colour, in light, dark and high contrast (77, 84) | No tinting. Monochrome icons are invisible in dark mode. |
| **Colour wells** | Platform colour button (60) | NeXT bevel |
| **NSBox** (grooved/bezelled), **NSForm**, box titles | (42, 43, 44) | GNUstep groove with an inset title (visible on the `real-app` page) |
| **Bold font** (`NSBoldFont`) | Set to the interface font's bold face (18) | Not set. Also, WinUI uses Semibold (600), not Bold, and uses it for headings, not button titles; the theme bolds the default button's title. |
| **Focus rings shown only after keyboard use** | Like GTK's focus-visible (30) | Always drawn, in the accent colour (see W2) |
| **Table defaults** (row height, no grid unless asked, no frame around table scroll views, header style, cell insets) | (21, 22, 23, 31) | Partial: palette entries exist, but grid and frame policy are not handled |
| **Overlay or modern scrollbars** | Fading overlay indicators (82, 86) | Classic GNUstep scroller with arrow buttons. WinUI's `ScrollBar` is a thin 2px rail that expands to a 6px thumb with arrows on hover. |
| **Window types and attachment** | `_NET_WM_WINDOW_TYPE` per window (73) | The Windows equivalent is owner windows and `WS_EX_TOOLWINDOW` for popups, menus and tool tips. Not audited at the HWND level. |
| **Per-app metrics for nib/Gorm apps** | `gnome` and `compact` metrics; Info.plist keys (45, 48) | One set of metrics. 32–34pt controls will clip in nib layouts made at GNUstep's 22pt. |
| **Gorm palette** | `Palettes/Adwaita` | None |
| **Unsaved-changes and document titles** | Shown in the header bar (75, 87) | The native caption shows GNUstep's `name  --  ~/path` title. Windows convention is `name - App`, with `*` or `●` for unsaved. |
| **Native file chooser** | XDG portal, with fallbacks (README) | Present (`WinUIThemeShellDialogs.m`, 1055 lines) but **not verified at run time** in this audit |

### Testing and process

| | Adwaita | WinUITheme |
| --- | --- | --- |
| Automated pixel and geometry probe | `Examples/QuirkProbe`: about 40 named checks, PASS/FAIL/KNOWN/SKIP, seven configurations | None. Screenshots are reviewed by hand, and the corpus is not frozen (see `RELEASE_READINESS.md`). |
| Scriptable demo | ThemeDemo command FIFO and script (`click`, `focus`, `open-dropdown`, `capture-alert`, …) | `--page` and `--capture-path` only |
| Real-app backlog | `IMPROVEMENTS.md`, driven by OneDriveServiceManager, Gorm, ScreenshotTool and MarkdownViewer | ObjcMarkdown smoke launch only |
| Upstream issue drafts with repro programs | `Docs/upstream-issues/` (9 drafts) | None |

## 3. Where the rendering departs from WinUI

These are departures from WinUI 3 / Fluent 2's default control styles (the
values in `generic.xaml`). Each one, on its own, is enough to tell a user
"this isn't a WinUI app".

| # | Control | WinUI 3 | WinUITheme |
| --- | --- | --- | --- |
| W1 | Corner radius | `ControlCornerRadius` is 4px; `OverlayCornerRadius` (flyouts, menus, dialogs) is 8px | Buttons 7px, inputs and segments 7px, focus 8px |
| W2 | Focus visual | 2px outer stroke in the text colour plus a 1px inner stroke in the background colour, just outside the control. Shown only for keyboard focus. Never the accent colour. | Translucent accent double ring, always shown |
| W3 | TextBox | Fill `ControlFillColorDefault`; 1px border with a darker bottom edge. When focused, a **2px accent underline** and a lighter fill. | A plain rounded box whose border is blended toward the accent. The signature underline is missing. |
| W4 | Button | Elevation border (bottom edge darker than the top). Hover and pressed fills (`ControlFillColorSecondary` and `Tertiary`). Pressed text uses the secondary text colour. Text never moves. | No hover state. The pressed title shifts 1px. Gloss highlight. Default button title is bold. |
| W5 | Accent shades | Light theme uses `SystemAccentColorDark1`; dark theme uses `SystemAccentColorLight2`, read from `HKCU\…\Explorer\Accent\AccentPalette`. Hover and pressed use reduced opacity. | One colour read from DWM `ColorizationColor`, which is the frame colour, not the app accent. Dark mode uses the light-theme accent, which is too dark on #202020. |
| W6 | Menus (MenuFlyout) | 8px corners, a DWM shadow, Acrylic or a solid fallback, items inset 4px with 4px-rounded hover, no gutter, shortcuts in the secondary text colour | Square, gutter, no shadow. **Setting `DWMWA_WINDOW_CORNER_PREFERENCE` on GNUstep's popup HWNDs gives native rounding and shadow on Windows 11 for free.** Today `WinUIThemeShouldManageWindow` skips every untitled window and every popup level. |
| W7 | ComboBox (pop-up button) | One rounded box, chevron at the right, **no divider** | Divider and a tinted "lane" behind the chevron |
| W8 | ToggleSwitch | 40×20 track. Off: transparent with a strong-stroke border and a **dark 12px knob** (14px on hover). On: accent track with a white knob. | Stretched track, white knob in every state |
| W9 | CheckBox and RadioButton | 20px box; accent fill with a white glyph. Radio: accent ring around a white centre that grows on hover and shrinks on press. | Bitmaps (D4) |
| W10 | Slider | 4px track; 20px thumb with an elevation border and a **12px accent inner dot** (14 on hover, 10 pressed) | Plain white circle |
| W11 | ProgressBar | 1px track line, 3px rounded accent indicator. Indeterminate is an animated sliding bar. `ProgressRing` for the spinning style. | Bordered bezel with gloss. Spinning style falls back to GNUstep's NeXT spinner. |
| W12 | List and table selection | Subtle fill (`SubtleFillColorSecondary`) plus a **3×16px accent pill** at the leading edge. Rounded 4px row highlight. Hover fill. | Light-blue fill with a 1px border |
| W13 | Typography | Segoe UI Variable: Body 14, Caption 12, BodyStrong 14 Semibold, Subtitle 20, Title 28 | Takes `lfMessageFont` (usually "Segoe UI" 9pt), raises it to 13, and uses Bold |
| W14 | High contrast | Uses the active contrast theme's system colours (`GetSysColor`: `COLOR_WINDOW`, `COLOR_HIGHLIGHT`, `COLOR_HOTLIGHT`, `COLOR_GRAYTEXT`, `COLOR_BTNFACE`…). Aquatic, Desert, Dusk and Night sky each have their own colours. | Pure black or white only. It ignores the user's contrast theme, which is an accessibility regression compared with native apps. |
| W15 | Live settings | Theme, accent, contrast and text scale change live (`WM_SETTINGCHANGE` "ImmersiveColorSet", `WM_DPICHANGED`) | Polled only when a window becomes or resigns key. Accent and text-scale changes are never detected. |
| W16 | Title bar | Seamless with the content (caption colour = window background), Mica on Windows 11 | Caption colour matches the background (good). No Mica or backdrop. `DWMWA_SYSTEMBACKDROP_TYPE` needs a transparent client area, which may need backend work. |

## 4. Candidates for upstream GNUstep patches

All of these go through the agreed process:

1. Review GNUstep's AI-contributed patch policy.
2. Make sure the patch follows it.
3. Build and test with GCC as well as clang.
4. Daniel reviews the patch personally before anything is posted.

The theme ships its own workaround in every case, so nothing here blocks theme
work.

- **`-[GSTheme overriddenMethod:for:]` matches only the exact class.** Still
  present on master `549f63913` (`Source/GSTheme.m:1079`). Adwaita's draft 4 is
  written but not filed.
- **`NSWindows95InterfaceStyle` windows created after launch get no menu.**
  Adwaita's draft 2. Now confirmed on Windows too (D1).
- **Scroll view interface style from `GSThemeDomain` isn't honoured (D3).**
  The root cause is still to be found. It may be a libs-gui caching-order
  problem rather than the theme's.
- **`NSSwitch` created disabled.** Adwaita noted this against 0.32. Check
  whether master still does it before drafting.

## 5. Proposed plan

Ordered by user-visible impact per unit of effort.

**Phase A: stop the visible breakage (D1–D11)**

1. Port `GnomeThemeOriginalMethod()` as `WinUIThemeOriginalMethod()` and route
   every override through it.
2. Port the late-window menu workaround.
3. Fix the duplicated header titles, the scroller side, the inverted stepper
   arrows, the combo box and the search field.
4. Remove the PNG indicator mappings so the vector checkbox and radio drawing
   runs, and make it follow WinUI.
5. Fix NSSwitch geometry and its disabled-on state.
6. Remove the gloss.
7. Replace the category overrides with GSTheme `_override…Method_` hooks.
8. Fix the build script and the demo's labels; add a real `NSToolbar` and an
   `NSAlert` to ThemeDemo.

**Phase B: a regression probe.** Port `Examples/QuirkProbe` and its
check-runner to Windows, running light, dark and high contrast at 100% and
150% scale. Every Phase A fix lands with a probe check. This is what keeps
parity once reached.

**Phase C: WinUI fidelity (W1–W14).** Accent palette and shades. 4px and 8px
radii. Focus visual shown only after keyboard use. TextBox underline. Button
hover, pressed and elevation border. ToggleSwitch, CheckBox, RadioButton,
Slider, ProgressBar and ProgressRing. List selection pill. Typography ramp.
Real high-contrast system colours. DWM rounding and shadow on menu and tool
tip popups.

**Phase D: the surfaces Adwaita covers.** Toolbar (content-sized, icon
buttons with hover, WinUI `CommandBar` look). Tool tips. NSAlert as a
ContentDialog. Windows menu conventions (no app-name menu; About moves to
Help, Quit to File › Exit, Preferences to Edit or Tools › Options). Template
image tinting. Colour well, NSBox, NSForm. `NSBoldFont`. Compact metrics for
nib and Gorm apps. Document titles. Live `WM_SETTINGCHANGE` handling.

**Phase E: real-app validation.** Run ObjcMarkdown, TinyRetroPad, Gorm and
ScreenshotTool under the theme and keep an `IMPROVEMENTS.md` backlog,
following Adwaita's practice.
