# GNUstep WinUI Theme

`plugins-themes-winuitheme` is a GNUstep theme project that targets WinUI 3 as
closely as practical while preserving GNUstep desktop application conventions.

The target is a Windows-native result for ordinary GNUstep desktop software:
document windows, top menu bars, toolbars, inspectors, data views, dialogs, and
split-window layouts.

This repository is intentionally not trying to recreate the Windows Settings
app shell or turn GNUstep into a XAML application framework. The visual target
is WinUI 3 client-area parity with GNUstep structure intact.

## Current Status

The repository now has the full phase 1-12 implementation scaffold in place:

- theme settings, metrics, palette, and runtime defaults
- shared drawing helpers and client-area control rendering
- menu, data-view, and container rendering
- native Windows file/print/page-setup integration
- DWM-backed window integration
- GNUstep `ThemeDemo` and WinUI 3 reference harnesses
- variant-review and real-app validation scripts
- release-readiness and backlog documentation

Current blockers are release-gate items rather than missing implementation:

- the screenshot corpus still needs a final manual freeze
- `ObjcMarkdown` is not green enough yet to close the hard real-app gate

## Key Documents

- [Implementation Roadmap](./Docs/IMPLEMENTATION_ROADMAP.md)
- [Windows Build Notes](./Docs/WINDOWS_BUILD.md)
- [Surface Ownership Matrix](./Docs/SURFACE_OWNERSHIP_MATRIX.md)
- [Harness Review Notes](./Docs/HARNESS_REVIEW.md)
- [Upstream Boundaries](./Docs/UPSTREAM_BOUNDARIES.md)
- [Variant And Accessibility Review](./Docs/VARIANT_AND_ACCESSIBILITY_REVIEW.md)
- [ObjcMarkdown Validation](./Docs/OBJCMARKDOWN_VALIDATION.md)
- [Release Readiness](./Docs/RELEASE_READINESS.md)
- [Post-Release Backlog](./Docs/POST_RELEASE_BACKLOG.md)

## Repository Layout

```text
Source/                    Theme implementation
Source/Settings/           Settings and metrics model
Source/Rendering/          Palette and future rendering code
Source/Native/             Reserved for later Windows adapters
Resources/                 Theme bundle metadata and future assets
ThirdParty/gnustep-window-tabbing/
                           Shared window tabbing code (vendored)
Examples/ThemeDemo/        GNUstep-side review harness
Examples/Shared/PageContract/
Reference/WinUI3ReferenceApp/
Tests/Scripts/             Validation and capture helpers
Docs/                      Roadmap and design notes
```

## Build

Build the theme bundle:

```sh
make
```

Build and install the theme bundle on this Windows/MSYS2 machine:

```powershell
powershell -ExecutionPolicy Bypass -File Scripts/Build-ThemeBundle.ps1
powershell -ExecutionPolicy Bypass -File Scripts/Install-ThemeBundle.ps1
```

Build the GNUstep demo harness:

```sh
make -C Examples/ThemeDemo
```

Build the WinUI 3 reference harness:

```powershell
powershell -ExecutionPolicy Bypass -File Reference/WinUI3ReferenceApp/build.ps1
```

## Metrics for Gorm and Nib Apps

Apps whose windows are built in code get WinUI's metrics: 14px Segoe UI
Variable, 32px controls and tabs, WinUI's button margins. Apps with a main
Gorm or nib file (`NSMainNibFile`, `NSMainStoryboardFile` or
`GSMainMarkupFile` in their Info.plist) get `compact` metrics instead:
GNUstep's 12pt interface font, WinUI's compact 24px control height, no
minimum tab height and GNUstep's own button margins, so layouts made at
GNUstep's sizes keep fitting their text. Menus keep WinUI's size either way.

`WinUIThemeMetrics`, `winui` or `compact`, overrides the choice: in the
app's Info.plist (an app laid out for WinUI's metrics declares `winui`), or
as a user default, which wins over the Info.plist:

```sh
defaults write SystemPreferences WinUIThemeMetrics compact
```

### Designing a WinUI app in Gorm

Gorm itself runs with compact metrics (its own windows come from Gorm files
laid out at GNUstep's). An app meant to look like a WinUI app needs its
windows laid out at WinUI's metrics instead:

1. Declare it in the app's Info.plist, so it runs with WinUI's metrics even
   though it has a main Gorm file:

   ```
   WinUIThemeMetrics = winui;
   ```

   With GNUstep Make, put this in `APPNAMEInfo.plist` next to the makefile.
2. Install the WinUI palette (`Palettes/WinUI`): controls at WinUI's sizes,
   32pt Button and AccentButton (the default button, Return as its key
   equivalent), TextBox, ComboBox (a pop-up button, and an editable combo
   box), AutoSuggestBox (a search field), CheckBox, RadioButton and
   ToggleSwitch (`NSSwitch`), and labels in WinUI's type ramp. Gorm's own
   palettes make 22pt controls. It needs Gorm installed (it links Gorm's
   InterfaceBuilder library):

   ```sh
   make palette installpalette GNUSTEP_INSTALLATION_DOMAIN=USER
   defaults write Gorm UserPalettes \
     "(\"$(cygpath -m "$(gnustep-config --variable=GNUSTEP_USER_LIBRARY)")/ApplicationSupport/Palettes/WinUI.palette\")"
   ```

   (or open it once with Palettes > Open... in Gorm's Tools menu, which
   remembers it). It appears as the last icon in Gorm's palette panel.
3. Lay its windows out in Gorm running with WinUI's metrics, so what you see
   is what the app will show:

   ```sh
   openapp Gorm -WinUIThemeMetrics winui
   ```

   Gorm's own panels and inspectors are cramped at this size, but the
   document's windows show the app's real text and control sizes. Size push
   buttons, text fields and pop-ups 32pt high and keep to WinUI's 4pt grid:
   8pt between related controls, more between groups.
4. Leave control fonts at the system font's default size (Gorm's default,
   and the palette's). Those are archived as "the system font" with no size
   and follow the metrics the app runs with: 14px Segoe UI Variable under
   WinUI's, 12pt under compact. The palette's Body label is the system font
   and its BodyStrong the bold system font (the theme's Semibold), both at
   the default size. Caption (12px), Subtitle (20px Semibold) and Title
   (28px Semibold) have WinUI's fixed sizes: they're archived as the system
   and bold system fonts at that size, so they keep the theme's face but not
   a size change. Any font given an explicit size keeps it.

## High Contrast

With a Windows contrast theme on (Aquatic, Desert, Dusk, Night sky or a
custom one), apps take that theme's colours, as WinUI apps do through their
`SystemColor*` resources: Window and WindowText for surfaces and text,
Hilight and HilightText for selection and the accent, GrayText for disabled
text, and ButtonFace and ButtonText for buttons. They follow a change of
theme while running, and the title bar is left to Windows.

To check an app under a contrast theme without changing the desktop, name
one: `--contrast-theme dusk` on the command line, or the
`WinUIThemeContrastTheme` default (`aquatic`, `desert`, `dusk`,
`night-sky`, or a `.theme` file's path). The colours are read from Windows'
own theme files.

## Window Tabs

Apps get Apple's `NSWindow` tabbing API (`-addTabbedWindow:ordered:`,
`tabbingIdentifier`, `tabGroup`, `-newWindowForTab:`, `-selectNextTab:` and
the rest) from the shared code in `ThirdParty/gnustep-window-tabbing`. The
theme installs it from `-activate` when `NSWindow` lacks it; GSTheme
activates the user's theme as `NSApplication` is made, so the API is there
before an app sets up its first window. Apps that check
`[NSWindow instancesRespondToSelector: @selector(addTabbedWindow:ordered:)]`
(ObjcMarkdown) find it.

**Off by default for now** (#72): apps that find the API use it (ObjcMarkdown
turns its documents into window tabs), and the tabs haven't been checked
with ObjcMarkdown yet. `WinUIThemeWindowTabs YES` (a user default, or
`-WinUIThemeWindowTabs YES` on the command line) turns them on;
QuirkProbe runs with it on.

The theme draws the bar as WinUI's TabView (Notepad, Terminal), from its
`generic.xaml` resources: a 40px strip (8px above 32px tabs) on a step
darker than the window, tabs 100 to 240px wide sharing it, titles at 12px
ending in an ellipsis; the selected tab in the window's colour with 8px top
corners and small flares into the strip's foot, semibold, with no line under
it so it runs into the content; other tabs with a hover fill and a divider
between them; a 32x24 close button on every tab (WinUI's default
CloseButtonOverlayMode, Auto, means Always), shown as a dot while the tab's
window has unsaved changes and the pointer isn't on the tab, as Notepad
does; a "+" right after the last tab when something answers
`-newWindowForTab:`. High contrast uses ButtonFace, Window, WindowText,
Hilight and HilightText as WinUI's TabView does.

Windows 11 apps put their tabs in the title bar. libs-back's Windows
server leaves the title bar to Windows, so here the bar has its own row
above the content, under the menu bar and the toolbar.

An app that compiles the shared code in itself, as its `Examples/TabDemo`
does, can't run under the theme: the process then has two copies of
`NSWindowTabGroup` and the other classes, and crashes. Apps should rely on
the theme (or libs-gui, later) for the API.

## Real-App Gate

Before release, the theme must validate against `ObjcMarkdown` in the sibling
directory at `C:\Users\Support\git\ObjcMarkdown`.

## License

WinUITheme is licensed under the GNU Lesser General Public License, version
2.1 or (at your option) any later version (LGPL-2.1-or-later). That covers
the whole repository: the theme sources, the examples, the scripts, the WinUI 3
reference app and the resources.

`ThirdParty/gnustep-window-tabbing` is a copy of
[danjboyd/gnustep-window-tabbing](https://github.com/danjboyd/gnustep-window-tabbing)
at `2fcb697` (its `Headers`, `Source`, `GSWindowTabbing.make` and
`LICENSE`, unchanged), also LGPL-2.1-or-later. To update it, copy those
from a checkout of that repository over the directory and record the new
hash here.

See [COPYING.LIB](./COPYING.LIB).
