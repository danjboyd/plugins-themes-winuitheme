# Post-Release Backlog

This document records the first follow-up wave after the initial `WinUITheme`
release.

## Theme Repo Follow-Up

1. Stabilize `ThemeDemo` self-capture so the phase 10 corpus does not depend on
   desktop-level fallback screenshots.
2. Remove the `NSMenuItem *` type warning in
   `Examples/ThemeDemo/TDAppDelegate.m`.
3. Tighten the Windows capture flow so GNUstep apps can be captured without a
   foreground desktop session.
4. Add a dedicated install/reinstall helper that also switches the active theme
   for local review sessions.

## Cross-Repo Follow-Up

1. Re-run the phase 11 validation after `ObjcMarkdown` fixes the current
   Windows test/build failures.
2. Decide whether `ObjcMarkdown` should grow its own deterministic capture hook
   for release validation.
3. Revisit any remaining `libs-gui` or backend issues that still force theme-
   local workarounds in menus, scrollers, or window integration.
