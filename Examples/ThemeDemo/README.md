# ThemeDemo

This directory contains the GNUstep-side review app for `WinUITheme`.

Build from the repo root:

```powershell
powershell -ExecutionPolicy Bypass -File Scripts/Build-ThemeDemo.ps1
```

Run from the repo root:

```powershell
powershell -ExecutionPolicy Bypass -File Scripts/Run-ThemeDemo.ps1
```

On this Windows/MSYS2 GNUstep setup, launching `ThemeDemo.exe` directly is not
reliable unless the runtime environment points at the matching `clang64`
GNUstep tree. The run helper script sets `GNUSTEP_PATHLIST=C:\msys64\clang64`
and the required DLL `PATH` before launching the app.

The harness now includes real widget surfaces for the roadmap's phase 4-9
review pages:

- `Controls`
- `Text Input`
- `Commands`
- `Data Views`
- `Dialogs`
- `Stress`

## Scripted commands

ThemeDemo can be driven without a person, to capture states a static
capture can't: an open pop-up menu, a focused field, keyboard focus, an
alert. `--command-script PATH` runs a file of commands, one a line (blank
lines and `#` comments are skipped); `--command-fifo NAME` reads more as they
come from the named pipe `\.\pipe\NAME`, which a driver writes lines to.
ThemeDemo reports each command on stdout as `ThemeDemo: <command>`, and
`ThemeDemo: idle` when it has run out of them.

`Tests/Scripts/Invoke-ThemeDemoScript.ps1 -Script FILE -OutputDirectory DIR`
runs a script against the theme built in this checkout, with `{out}` in the
script standing for `DIR`, and exits with the number of commands that
failed. `Scripts/acceptance.txt` captures an open pop-up, a focused text
field, keyboard focus on a button and a stock alert.

Commands run one per run-loop turn, in the default, modal and
event-tracking modes, so they go on while a pop-up's menu is open or an
alert runs. Controls are named by their title, value or placeholder, or by
the caption under them, in lower case with hyphens for spaces: `save`,
`text-field`, `popup-button`; `page-selector` is the page pop-up.

| Command | What it does |
| --- | --- |
| `page ID` | shows a page (`controls`, `text-input`, `commands`, `data-views`, `dialogs`, `real-app`, `surfaces`, `stress`) |
| `wait SECONDS` | waits before the next command |
| `click X Y`, `double-click X Y` | clicks at a point, in points from the content's top left |
| `click-control NAME` | clicks a control's middle |
| `focus NAME`, `blur-to NAME` | makes a control the focus (a text field with its caret at the end) |
| `select-all` | selects the focused field's text |
| `type TEXT` | types text into the focus |
| `key KEY` | presses a key: `tab`, `shift+tab`, `return`, `escape`, `space`, `up`, `down`, `left`, `right`, `home`, `end`, `backspace`, `delete`, or a character, with `shift+`, `ctrl+` (GNUstep's Command) or `alt+`. A key press shows keyboard focus, as it does for a user |
| `report-focus` | reports the focused control |
| `tooltip NAME`, `tooltip-hide` | shows a control's tool tip as its timer would (below the pointer, which isn't moved), and hides it; capture it with `screenshot-app` |
| `open-dropdown NAME`, `close-dropdown` | opens a pop-up button's menu or a combo box's list, and closes it |
| `capture-dropdown NAME PATH` | opens it, captures the app's windows to `PATH`, and closes it |
| `alert`, `dismiss-alert [BUTTON]` | runs the demo's stock "save changes" NSAlert, and presses one of its buttons (Cancel unless named). The alert closes within about a second of `dismiss-alert`: wait before capturing what's under it |
| `capture-alert PATH` | runs the alert, captures it to `PATH` and dismisses it |
| `screenshot PATH` | the window's content, drawn offscreen (no title bar, menus or alerts) |
| `screenshot-window PATH` | the window from the screen, with its title bar and menu bar |
| `screenshot-key-window PATH` | the alert (or other modal or key window) |
| `screenshot-app PATH` | the app's visible windows together, open menus included |
| `screenshot-screen PATH` | the whole screen |
| `display` | redraws the window |
| `quit` | quits |

Captures are PNG files. Window captures use `PrintWindow`, so other windows
over ThemeDemo don't spoil them; `screenshot-app` raises the app's windows
over the others for the moment it takes.
