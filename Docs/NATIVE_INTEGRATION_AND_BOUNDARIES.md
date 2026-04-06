# Native Integration And Boundaries

This document captures the phase 9 boundary for `WinUITheme`.

## Theme-Owned Native Integration

- `NSOpenPanel` and `NSSavePanel` route to Windows file dialogs through `WinUIThemeOpenPanel` and `WinUIThemeSavePanel` when native APIs are available.
- `NSPrintPanel` and `NSPageLayout` route to Windows print and page setup dialogs through `WinUIThemePrintPanel` and `WinUIThemePageLayout`.
- Window identity is synchronized through `WinUIThemeWindowIntegration`, which applies DWM title-bar dark mode, caption/border/text colors, and Win11-style corner preferences to GNUstep windows.
- All native integrations fall back to GNUstep defaults if the required Windows API is unavailable or the native handoff fails.

## Explicit Non-Goals

- Regular controls are still theme-rendered. The theme does not delegate buttons, fields, menus, tables, tabs, scrollers, or outline views to `uxtheme.dll` or other native control painters.
- The theme does not attempt to reproduce WinUI 3 shell patterns such as `NavigationView`, Mica-hosted custom shells, or XAML-specific layout chrome.
- Native integration is intentionally limited to shell-value surfaces and non-client identity.

## Current Upstream Boundaries

- If GNUstep exposes better hooks for popup-menu placement, menu shortcut alignment, or per-window lifecycle notifications, those should move upstream rather than stay as theme-local workarounds.
- If backend support for window-handle and DPI synchronization improves, the window-identity code should shrink to policy only.
- Any future request for native control delegation should be treated as out of scope for this theme unless the GNUstep architecture changes substantially.

## Acceptance Standard

- Native dialogs should look like current Windows dialogs when available.
- GNUstep client-area widgets should remain theme-owned and visually close to the WinUI 3 reference harness.
- If native APIs are unavailable, the app must still function with GNUstep fallbacks instead of failing to show a dialog.
