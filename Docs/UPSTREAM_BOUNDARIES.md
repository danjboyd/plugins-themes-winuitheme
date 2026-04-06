# Upstream Boundaries

These are the boundaries that should stay explicit while phases 1 through 3 are
implemented.

## Theme-Owned

- settings ingestion
- semantic metrics
- semantic palette
- runtime defaults
- future control rendering
- future menu and data-view styling

## Later Native-Adapter-Owned

- native open/save
- native print/page setup
- task-style system dialogs
- DWM-managed top-level window identity

## Likely Upstream Work If Needed

- per-window DPI exposure that the theme cannot obtain cleanly
- setting-change notifications that do not reach the theme bundle reliably
- hard-coded AppKit spacing or layout limits that block release-quality parity

The rule is simple: if a mismatch is fundamentally about framework behavior,
document it here rather than hiding it in brittle theme-local code.
