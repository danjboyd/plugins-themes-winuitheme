# Shared Page Contract

This directory contains the shared fixture contract used by:

- `Examples/ThemeDemo`
- `Reference/WinUI3ReferenceApp`

The contract is intentionally small at this stage. Its first job is to
stabilize page IDs, section IDs, and fixture IDs before the full control
rendering exists.

## Rules

- page IDs must remain stable once screenshot naming starts
- section IDs must remain stable once captures exist
- fixture IDs are required for every fixture object
- fixture IDs only need to be unique within a section, because later naming can
  include page and section IDs
- harnesses are review tools, not the final oracle
- real Windows behavior still outranks both harnesses if they disagree

## Current Contract File

- `theme-demo-pages.json`

