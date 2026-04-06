# Surface Ownership Matrix

## Goal

Keep implementation boundaries explicit from the start so later parity work does
not drift into the wrong layer.

## Ownership

| Surface | Owner | Notes |
| --- | --- | --- |
| Core controls | Theme | Buttons, toggles, sliders, progress, steppers |
| Text inputs | Theme | Text fields, search fields, popup/combo chrome |
| Menus | Theme | GNUstep menu bar remains a GNUstep convention |
| Data views | Theme | Tables, headers, outline disclosure, tabs, scrollers |
| Toolbar styling | Theme | Fits with menu bar and document-window layout |
| Native open/save | Native adapter | Phase 9 |
| Native print/page setup | Native adapter | Phase 9 |
| Task-style dialogs | Native adapter | Phase 9 |
| Window title bar dark mode | Backend or native adapter | Phase 9 |
| Window corner policy | Backend or native adapter | Phase 9 |
| Mixed-DPI window lifecycle | Backend or `libs-gui` | Do not bury this in theme-local hacks |
| Hard-coded AppKit spacing blockers | `libs-gui` | Only if theme-layer control is insufficient |

## Acceptance Source

| Surface | Primary Oracle |
| --- | --- |
| Core controls | WinUI 3 reference app |
| Menus and command surfaces | WinUI 3 reference app plus Windows captures |
| Data views | WinUI 3 reference app plus real content captures |
| Native dialogs | Real Windows native surfaces |
| Real-world app fit | `ObjcMarkdown` |

