# WinUI Theme Implementation Roadmap

## Target

Build a GNUstep theme that tracks the visual language of WinUI 3 closely enough
that a GNUstep demo app and a WinUI 3 reference app look intentionally similar
when viewed side by side.

The intended result is not shell imitation. GNUstep applications should retain
GNUstep conventions such as the traditional top menu bar, ordinary document
windows, and normal desktop application structure. The target is WinUI 3 client
area parity and Windows platform fit, not a fake XAML shell.

This roadmap assumes:

1. The theme is code-based rather than image-skin-based.
2. The client area is primarily theme-rendered.
3. Native Windows integration is used selectively for shell-value surfaces.
4. A reference app and real-app validation are part of the project from the
   beginning, not an afterthought.

## Success Criteria

The project is successful when:

1. `ThemeDemo` under GNUstep and the WinUI 3 reference app can be compared page
   for page with only small, explainable differences.
2. The GNUstep result reads as a high-quality Windows desktop application
   rather than a default GNUstep theme with modern colors.
3. The remaining differences from the WinUI 3 reference app are intentional
   GNUstep conventions, not visual drift.
4. Light mode, dark mode, high contrast, reduced-transparency, and common DPI
   scales all look deliberate.
5. Native dialogs and top-level non-client integration feel plausibly Windows.
6. `ObjcMarkdown` looks correct enough to serve as a real-world acceptance app
   before release.

## Explicit Non-Goals

1. Recreating the Windows Settings app shell.
2. Turning GNUstep into a WinUI application framework.
3. Reusing the old `WinUXTheme` native control painting model as the main
   rendering strategy.
4. Driving the theme primarily with bitmap atlases.
5. Copying product-specific shells such as Office, Visual Studio, or Explorer.
6. Preserving every historical GNUstep visual quirk if it conflicts with a
   better Windows desktop result.

## Design Direction

The theme should combine the strongest ideas from the existing neighboring
projects:

- from `plugins-themes-win11theme`: layered architecture, Windows settings
  ingestion, semantic metrics, theme-owned rendering, selective native dialogs,
  and DWM window integration
- from `plugins-themes-Adwaita`: disciplined use of tokens, readable spacing,
  restrained accent usage, and strong desktop-app ergonomics
- from `plugins-themes-WinUXTheme`: only the lesson that a small set of
  shell-native surfaces are worth delegating, not the direct per-control
  `uxtheme` rendering approach

The WinUI 3 visual target should be interpreted as:

- modern Windows desktop
- restrained Fluent styling
- clear surface hierarchy
- high-quality focus, selection, and spacing
- good density for document apps and tool-style applications

## Phase Structure

Each numbered phase is a major milestone. Lettered subphases break the work
into discrete deliverables that can be implemented, validated, and archived.

## Phase 1: Foundation And Constraints

### Goal

Create a stable repository layout, define boundaries early, and remove any
ambiguity about what this theme is trying to become.

### Phase 1A: Repository Skeleton

Tasks:

- create the long-term repository layout:
  - `Docs/`
  - `Source/`
  - `Source/Settings/`
  - `Source/Rendering/`
  - `Source/Native/`
  - `Resources/`
  - `Examples/ThemeDemo/`
  - `Reference/WinUI3ReferenceApp/`
  - `Tests/Scripts/`
  - `Tests/Screenshots/`
- add a minimal `GNUmakefile`
- add a minimal `Info-gnustep.plist`
- ensure the repo can build an empty `.theme` bundle

Deliverables:

- installable empty theme bundle
- stable top-level repo structure

### Phase 1B: Scope And Surface Ownership

Tasks:

- enumerate all relevant surfaces:
  - core controls
  - text inputs
  - menus
  - data views
  - dialogs
  - toolbars
  - top-level window chrome
  - shell integration surfaces
- classify each surface as:
  - theme-owned
  - native-adapter-owned
  - backend-owned
  - probable `libs-gui` work
- identify the primary GNUstep hook or API boundary for each

Deliverables:

- surface ownership matrix
- initial upstream-boundary list

### Phase 1C: Local Workflow And Build Notes

Tasks:

- document the supported Windows build path on this machine
- add scripts for build, install, reinstall, and review loops
- document how the GNUstep theme, WinUI 3 reference app, and `ObjcMarkdown`
  fit into the same workflow

Deliverables:

- Windows build notes
- review-loop scripts

### Phase 1D: Acceptance Vocabulary

Tasks:

- define the language for captures, fixture IDs, page IDs, state names, and
  review metadata
- decide how screenshots and cropped validation images will be named
- define what counts as:
  - intentional GNUstep difference
  - acceptable visual delta
  - release blocker

Deliverables:

- capture vocabulary and naming rules
- review checklist draft

Exit Criteria:

1. The repository can build an empty selectable theme bundle.
2. The repo structure is stable enough to avoid churn.
3. Every major surface has an owner and an acceptance path.

## Phase 2: Reference Harnesses And Visual Oracle

### Goal

Establish a trustworthy comparison loop before deep rendering work begins.

### Phase 2A: GNUstep ThemeDemo

Tasks:

- build `Examples/ThemeDemo/` as the GNUstep-side review app
- create pages for:
  - controls
  - text inputs
  - menus and popups
  - data views
  - dialogs
  - stress cases
  - shell-like document layouts
- include dense forms, long labels, disabled states, mixed states, inactive
  selection, and scale-sensitive cases

Deliverables:

- buildable `ThemeDemo`
- stable page and fixture IDs

### Phase 2B: WinUI 3 Reference App

Tasks:

- build `Reference/WinUI3ReferenceApp/` as a real WinUI 3 desktop harness
- mirror the GNUstep demo page for page as closely as practical
- use the same labels, ordering, and state coverage wherever possible
- avoid false shell equivalence:
  - do not turn the app into a Settings clone
  - do not use `NavigationView` unless a specific fixture requires it
  - keep the app as a conventional Windows desktop reference surface

Deliverables:

- buildable WinUI 3 reference app
- documented fixture alignment with `ThemeDemo`

### Phase 2C: Shared Fixture Contract

Tasks:

- define one shared page contract for pages, sections, labels, values, and
  state names
- make the GNUstep and WinUI 3 harnesses consume one source of truth or a
  mechanically synchronized equivalent
- ensure every page can be compared without hand-wavy interpretation

Deliverables:

- shared fixture contract
- synchronized review content across both harnesses

### Phase 2D: Capture And Review Loop

Tasks:

- add capture scripts for both harnesses
- archive fixture-level screenshots rather than only full-window captures
- define side-by-side review output for:
  - GNUstep
  - WinUI 3
  - real Windows reference captures where needed

Deliverables:

- repeatable capture flow
- archived screenshot structure

Exit Criteria:

1. The team can compare the same page between GNUstep and WinUI 3 directly.
2. The review loop is based on captured artifacts rather than memory.
3. The harnesses expose the full v1 surface set before rendering work deepens.

## Phase 3: Platform Settings, Tokens, And Runtime Defaults

### Goal

Build the non-rendering layer that feeds every later visual decision.

### Phase 3A: Windows Settings Ingestion

Tasks:

- ingest Windows settings for:
  - app light/dark preference
  - accent color
  - high contrast
  - reduced transparency
  - interface font and menu font
  - desktop scale factor
- add local override keys for debugging and controlled captures

Deliverables:

- settings model
- documented override behavior

### Phase 3B: Semantic Metrics Model

Tasks:

- derive metrics from the WinUI 3 reference app and supporting captures:
  - menu heights
  - control heights
  - row heights
  - scroller widths
  - paddings
  - corner radii
  - tab metrics
- validate those metrics at common scales:
  - `100%`
  - `125%`
  - `150%`
  - `200%`

Deliverables:

- metrics model
- measurement notes

### Phase 3C: Typography Model

Tasks:

- map interface, menu, menu-bar, and fixed-pitch roles to the right Windows
  fonts
- apply runtime font defaults early
- confirm text rhythm and density in both harnesses before deep custom paint

Deliverables:

- typography model
- runtime font defaults

### Phase 3D: Semantic Palette

Tasks:

- define semantic colors for:
  - surfaces
  - content
  - separators
  - focus
  - accent
  - active and inactive selection
  - menu states
  - data-view states
- support light, dark, and high-contrast variants

Deliverables:

- semantic palette
- documented token roles

Exit Criteria:

1. The harnesses already feel appropriately dense and typographically correct
   before advanced rendering work.
2. The theme can switch variants coherently.
3. Later control paint can rely on stable tokens instead of ad hoc values.

## Phase 4: Rendering Primitives And Shared Paint Helpers

### Goal

Create the reusable drawing vocabulary for the rest of the theme.

### Phase 4A: Geometry And Pixel Discipline

Tasks:

- implement shared helpers for:
  - integral rect snapping
  - scale-aware stroke alignment
  - rounded geometry
  - border and fill composition
- ensure helpers are safe at common DPI scales

Deliverables:

- geometry helpers
- DPI-safe paint helpers

### Phase 4B: Shared State Mapping

Tasks:

- define one state system for:
  - normal
  - hover
  - pressed
  - focused
  - selected
  - disabled
  - inactive
  - mixed
- map GNUstep control states into that internal model consistently

Deliverables:

- shared state mapping rules

### Phase 4C: Glyph And Icon Set

Tasks:

- implement or prepare the minimal glyph set for:
  - chevrons
  - checkmarks
  - radio dots
  - search
  - disclosure arrows
  - switch marks if needed
- prefer vector-like drawing or very small intentional assets over large image
  atlases

Deliverables:

- reusable glyph set

Exit Criteria:

1. Later control implementations can share one paint system.
2. The repo has a coherent visual vocabulary rather than per-control hacks.

## Phase 5: Core Controls

### Goal

Land the first visually complete control family.

### Phase 5A: Buttons And Focus

Tasks:

- implement push-button rendering
- implement default button emphasis
- implement focused and keyboard focus treatment
- tune disabled and pressed states against the reference app

Deliverables:

- button and focus rendering

### Phase 5B: Selection Controls

Tasks:

- implement checkbox rendering
- implement radio rendering
- implement mixed-state rendering
- implement switch rendering where GNUstep surfaces use it

Deliverables:

- selection-control rendering

### Phase 5C: Range And Increment Controls

Tasks:

- implement sliders
- implement progress indicators
- implement steppers
- validate hover/pressed and active/inactive states

Deliverables:

- range-control rendering

### Phase 5D: First Visual Gate

Tasks:

- review the core controls page against the WinUI 3 reference app
- fix obvious density, radius, focus, or emphasis mismatches before moving on

Deliverables:

- first parity checkpoint

Exit Criteria:

1. Core controls look like one family.
2. The GNUstep controls page no longer looks generically GNUstep.
3. The remaining differences are details, not category-level mismatches.

## Phase 6: Text And Compound Inputs

### Goal

Make form-heavy interfaces feel coherent and Windows-native.

### Phase 6A: Text Fields And Search Fields

Tasks:

- implement text-field bezels and focus treatment
- implement search-field styling and glyph behavior
- handle placeholders, disabled state, and read-only-like presentation

Deliverables:

- text and search field rendering

### Phase 6B: Popups And Combo Controls

Tasks:

- implement popup-button chrome
- implement combo-box styling
- tune arrows, inset behavior, and active states
- validate long values and empty states

Deliverables:

- popup and combo rendering

### Phase 6C: Segmented And Compound Controls

Tasks:

- implement segmented controls
- tune label centering, separators, and selected-state emphasis
- keep visual rhythm aligned with buttons and fields

Deliverables:

- segmented-control rendering

### Phase 6D: Form Density Gate

Tasks:

- review dense forms, long placeholders, and disabled inputs
- tune form spacing against the reference app

Deliverables:

- form-density acceptance checkpoint

Exit Criteria:

1. Form-heavy windows read as intentional Windows desktop UI.
2. Text and compound inputs fit the same visual system as the core controls.

## Phase 7: Menus, Toolbars, And Command Surfaces

### Goal

Make command surfaces feel Windows-native while preserving GNUstep conventions.

### Phase 7A: GNUstep Menu Bar Styling

Tasks:

- style the traditional GNUstep top menu bar with WinUI 3-informed spacing,
  typography, and selection treatment
- keep it recognizably a GNUstep menu bar rather than forcing an in-window
  command bar model

Deliverables:

- GNUstep menu-bar treatment

### Phase 7B: Popup And Context Menus

Tasks:

- implement popup menu backgrounds, borders, separators, and selection
- tune submenu arrows, checkmarks, radios, and key-equivalent columns
- validate disabled, hovered, and inactive states

Deliverables:

- popup and context menu rendering

### Phase 7C: Toolbar And Command-Cluster Fit

Tasks:

- tune toolbar buttons and grouped command surfaces
- ensure menu bar, toolbar, and dialog-action surfaces feel related

Deliverables:

- command-surface cohesion pass

### Phase 7D: Stress Validation

Tasks:

- test long menu items, deep submenus, key equivalents, and disabled rows
- archive stress captures for later regressions

Deliverables:

- menu stress acceptance set

Exit Criteria:

1. Command surfaces look deliberate and readable.
2. The theme preserves GNUstep command conventions without looking foreign on
   Windows.

## Phase 8: Data Views And Complex Containers

### Goal

Handle the surfaces that real document applications depend on.

### Phase 8A: Scroll Views And Scrollers

Tasks:

- style scroll-view borders and corners
- tune scroller tracks, thumbs, hover, and inactive states

Deliverables:

- scroll-view and scroller rendering

### Phase 8B: Tables And Headers

Tasks:

- implement table-header styling
- tune grid lines, row spacing, and active/inactive selection
- validate content-bearing rows rather than only empty fixtures

Deliverables:

- table and header rendering

### Phase 8C: Outline Views, Sidebars, And Split Views

Tasks:

- implement disclosure arrows and outline row treatment
- tune source-list-like layouts and split-view separators
- ensure inspector/sidebar surfaces fit the same hierarchy

Deliverables:

- outline and split-view rendering

### Phase 8D: Tabs And Secondary Containers

Tasks:

- implement tab-strip treatment
- tune panels, grouped containers, and optional secondary widgets as needed

Deliverables:

- tab and secondary-container rendering

Exit Criteria:

1. Data-heavy windows no longer break the visual illusion.
2. The theme is strong enough to move from harnesses into real applications.

## Phase 9: Native Windows Integration And Upstream Boundaries

### Goal

Use native Windows APIs where they materially improve fidelity without turning
the theme into a thin wrapper around old Windows control rendering.

### Phase 9A: Native Dialogs

Tasks:

- integrate native open/save dialogs
- integrate native print and page setup
- integrate task-style informational dialogs where appropriate
- define explicit fallback rules when native ownership is unsafe

Deliverables:

- shell-dialog adapter layer
- fallback policy

### Phase 9B: Non-Client Window Integration

Tasks:

- integrate dark title-bar handling
- integrate corner policy
- integrate caption, border, and title-text policy
- synchronize with per-window scale and appearance changes where possible

Deliverables:

- DWM window-integration layer

### Phase 9C: Upstream Boundary Management

Tasks:

- track remaining `libs-gui` and backend limitations
- avoid papering over framework issues with fragile theme-local hacks
- classify each remaining mismatch as:
  - fix in theme
  - fix in backend
  - fix in `libs-gui`
  - acceptable limitation for v1

Deliverables:

- upstream-boundary document
- prioritized follow-up list

Exit Criteria:

1. Native shell-value surfaces feel plausible on Windows.
2. Remaining framework gaps are explicit and manageable.

## Phase 10: Variants, Scale, And Accessibility Gates

### Goal

Make the theme hold together outside the default happy path.

### Phase 10A: Dark Mode Parity

Tasks:

- review every major fixture in dark mode
- deepen the reference corpus where dark-mode gaps exist
- tune emphasis, separators, and content contrast

Deliverables:

- dark-mode acceptance set

### Phase 10B: High Contrast And Reduced Transparency

Tasks:

- validate high-contrast token behavior
- validate reduced-transparency behavior
- ensure focus and selection remain legible

Deliverables:

- accessibility variant acceptance set

### Phase 10C: DPI And Scale Validation

Tasks:

- review `100%`, `125%`, `150%`, and `200%`
- verify snap rules, corner radii, and glyph sharpness
- capture variant artifacts for regressions

Deliverables:

- scale-acceptance set

Exit Criteria:

1. The theme is stable across variants and common scales.
2. Accessibility-related regressions are visible before release.

## Phase 11: Real-App Validation With ObjcMarkdown

### Goal

Confirm the theme works in a real GNUstep application with nontrivial content
and document-window structure.

### Phase 11A: ObjcMarkdown Integration Pass

Tasks:

- build and run `ObjcMarkdown` from the sister directory
- validate menu bar, toolbar density, split views, tables, editors, and preview
  surfaces under the theme
- capture representative windows and focused crops

Deliverables:

- initial `ObjcMarkdown` validation captures

### Phase 11B: Real-World Polish Loop

Tasks:

- compare `ObjcMarkdown` against the WinUI 3 reference app where the surfaces
  overlap meaningfully
- classify each mismatch as:
  - intended GNUstep convention
  - real theme defect
  - framework/backend issue
- tune the theme based on actual usage rather than demo-only surfaces

Deliverables:

- real-app mismatch ledger
- targeted polish fixes

### Phase 11C: Secondary Real-App Coverage

Tasks:

- validate native-dialog and shell behavior using additional local apps where
  useful
- confirm `ObjcMarkdown` is not the only app that looks correct

Deliverables:

- broader real-app validation notes

Exit Criteria:

1. `ObjcMarkdown` looks correct enough to serve as a release gate.
2. Real-world usage does not reveal category-level visual failures that were
   hidden by the harnesses.

## Phase 12: Release Readiness

### Goal

Freeze the implementation, make validation repeatable, and prepare the project
for release and maintenance.

### Phase 12A: Acceptance Freeze

Tasks:

- finalize the acceptance capture sets
- clean stale screenshots and obsolete notes
- ensure every required fixture has a current capture

Deliverables:

- final acceptance corpus

### Phase 12B: Install And Release Docs

Tasks:

- document build, install, switch, and troubleshooting flows
- document known limitations and upstream-boundary issues
- document how to rerun the validation and capture pipeline

Deliverables:

- install notes
- release checklist
- maintenance notes

### Phase 12C: Post-Release Follow-Up List

Tasks:

- record deferred `libs-gui` and backend work
- record any intentionally deferred controls or variants
- define the first post-v1 cleanup wave

Deliverables:

- post-release backlog

Exit Criteria:

1. The repo can be handed to a future contributor without hidden context.
2. The validation pipeline is repeatable.
3. The project is ready to ship.

## Recommended Execution Order

The recommended execution order is:

1. complete Phase 1 fully
2. complete Phase 2 before deep rendering work
3. complete Phase 3 before trying to polish controls visually
4. land Phases 4 through 8 as the main client-area implementation wave
5. land Phase 9 after the client area is stable
6. close Phase 10 before claiming parity
7. treat Phase 11 and `ObjcMarkdown` as a hard release gate, not optional polish
8. finish with Phase 12 documentation and release cleanup

## Final Acceptance Standard

The final acceptance question for this project is:

When `ThemeDemo`, the WinUI 3 reference app, and `ObjcMarkdown` are placed side
by side, do they clearly belong to the same Windows desktop design language,
with the GNUstep result differing only where GNUstep conventions intentionally
require it?

If the answer is no, the roadmap is not complete.
