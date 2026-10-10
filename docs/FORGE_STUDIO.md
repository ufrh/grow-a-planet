# FORGE Studio

## Project persistence

FORGE Studio now persists the complete authoring project automatically per Roblox place.

- edits autosave after a short debounce
- direct document mutations autosave even if a tool forgets to push undo history
- Undo / Redo autosave
- imported project packages autosave
- Ctrl+S forces an immediate save
- the Runtime Package popup includes an explicit Save button and save status
- plugin shutdown / dev reload performs a final save
- reopening Studio restores the persistent designer project before falling back to the generated runtime package
- persistence is independent of runtime validation, so invalid/in-progress UI work is still saved

Saved project data is encoded into JSON-safe Roblox datatype records and chunked across plugin settings, keyed by universe/place. Generated runtime packages remain a separate concern for Play/runtime.


FORGE Studio is the visual authoring plugin for FORGE UI.

## Update

For the normal development loop, run:

```bat
tools\UPDATE_FORGE_STUDIO.bat
```

The updater:

1. verifies Git and Rojo are available
2. refuses to overwrite uncommitted local changes
3. fetches and fast-forwards to the newest `origin/dev`
4. builds `forge-studio.project.json`
5. installs the finished plugin directly to:

```text
%LOCALAPPDATA%\Roblox\Plugins\FORGEStudio.rbxm
```

If Roblox Studio is already open, restart Studio so the local plugin reloads.

## Current RUCKUS workflow

FORGE Studio now keeps a validated runtime snapshot synchronized automatically.

1. Author UI normally in FORGE Studio.
2. Watch the bottom status or Build panel for `Runtime Synced`.
3. Press normal Roblox Studio Play.
4. `StarterPlayerScripts.FORGE.Launch.Bootstrap` automatically mounts `ReplicatedStorage.FORGEExports.FORGEAutoProject`.
5. Game code can access the mounted project with `FORGE.UI.GetProject()`.

Every normal editor history change queues a new runtime snapshot. Validation runs before the automatic package is replaced. If the current authoring state contains runtime errors, FORGE Studio leaves the previous valid package intact so Play still boots the last known-good UI.

The Build panel exposes:

- **Sync Now** for an explicit recovery sync
- **Validate** for a full Problems pass
- **Export** for an optional named deterministic package
- **Import** for restoring a selected generated project package
- **Runtime Preview** for exercising the runtime representation in a Play/Test client

When `ReplicatedStorage.FORGEStudioDev` exists, the plugin now prefers that live Rojo source automatically. `Reload` remains available when you want to rebuild the dev runtime after source changes.

## Q1 editor foundation

Quarter 1 establishes the editing foundation used by later component, state, animation, and binding tooling.

### Editing

- multi-root selection
- primary and secondary selection outlines
- Explorer icon toggle for keyboard-independent multi-select
- copy, cut, paste, duplicate, and multi-delete
- undo and redo document history
- arrow-key nudging
- Shift + arrow large nudging
- root locking and visibility controls
- Explorer, Children, and Properties search

### Layout

- align left, center X, right, top, center Y, and bottom
- distribute horizontally and vertically
- equal width, equal height, and equal size
- locked roots are protected from transforms

### Preview

- logical-resolution device canvas
- Desktop 16:9, Laptop, Tablet, Phone Landscape, and Phone Wide presets
- device preset popup
- zoom controls
- mouse-wheel zoom
- middle/right-mouse panning
- Fit reset
- zoom-safe selection handles and transforms

### Snapping

- persistent Snap toolbar toggle
- Shift snapping when Studio keyboard input is available
- nine screen-anchor snap targets
- per-root ScreenMargin
- visible margin guides and snap markers
- snap metadata is cleared when an object is manually repositioned

### Properties

- typed boolean controls
- color swatches with RGB editing
- enum cycling controls
- editable scalar/string/vector/UDim fields
- multi-root property application where supported
- property search
- ScreenMargin editor metadata

### Q1 live-dev note

Q1 adds `History.lua` to `FORGEStudioDev`. After pulling Q1 for the first time, restart the Rojo servers once and reconnect the current place. Normal App/Theme/Widgets/etc. changes return to the usual `Reload Dev` workflow after that.

## Q2 reusable authoring

Quarter 2 adds reusable UI authoring on top of the Q1 editor foundation.

### Insert palette

- searchable native UI insertion palette
- basic GuiObjects
- appearance modifiers
- layouts
- constraints
- first-class UIShadow entry
- inserts under the selected root or child
- inserts as a new root when no parent is selected
- slot-aware insertion marks top-level slot content automatically

### Components

- create a component definition from the selected root
- selected source root is marked as the component source
- instantiate reusable component roots
- update the source definition
- updating a source refreshes all linked instances
- detach instances from their component relationship
- delete a component definition while leaving document roots detached
- component definitions are cloned templates, never live editor roots
- duplicating a component source produces an instance instead of a second source

### Variants / states

- Default state plus named variants
- save or update a variant from the selected component root
- rename variants
- delete variants
- cycle available states
- Preview / Apply a state to selected component instances
- active variant metadata is preserved on instances

### Slots

- mark any selected child with a named slot
- clear a slot
- edit slot names directly from Properties
- inserting while a slot is selected marks the inserted object as slot content
- slot content survives component source refreshes and variant switches
- slot content is excluded from component templates
- Children shows [SLOT:name] and [CONTENT] markers

### Editor integration

- Explorer badges: SRC, INST, DET
- Component, ComponentKind, Variant, and Slot metadata in Properties
- searchable Component Library popup
- component instance counts
- component library and variants participate in Undo / Redo
- component definitions and selected component/state survive Reload Dev sessions

### Q2 live-dev note

Q2 adds `Components.lua` to `FORGEStudioDev`. After pulling Q2 for the first time, restart the Rojo servers once and reconnect the current place so `ReplicatedStorage.FORGEStudioDev.Components` appears. After that, Q2 code changes return to the normal `Reload Dev` workflow.

## Q3 behavior and data authoring

Quarter 3 adds editor-authored behavior and preview data on top of the Q1/Q2 visual and reusable-authoring foundation.

### Animations

- named animation definitions
- reusable property tracks
- root-relative target paths such as `Root` and `Header/Title`
- typed From and To values
- duration and delay
- easing style and easing direction
- animation-level Loop
- animation-level Reverse
- per-track stagger sequencing
- capture the currently selected object's property value with Use Current
- add, update, and delete tracks
- live TweenService preview in the editor
- Play, Stop, and Reset controls
- preview values are excluded from document history snapshots
- component/variant capture always uses authored values rather than temporary preview values

### Bindings

- static or bound property modes
- bindings are stored directly on UI objects as FORGE metadata
- property-to-path bindings such as `Text <- Player.DisplayName`
- nested data paths
- selected-object binding list
- Preview Target and Preview All
- Auto Preview
- Reset restores exact authored property values
- basic type coercion for common UI cases
- bound properties display a `[B]` marker in Properties
- Children displays binding counts on bound descendants
- bindings clone naturally with components and instances

### Mock Data

- nested preview-only data model
- searchable path list
- String, Number, Boolean, and Color3 values
- create or update arbitrary nested paths
- delete mock values
- bindings resolve directly against mock data
- default Player, Party, and Match preview data
- default avatar thumbnail URI for player-oriented UI
- party member sample data
- match mode, map, stake, pot, team, time, and player-count sample data
- mock data participates in Undo / Redo and Reload Dev sessions

### Preview safety

- animation and binding previews preserve authored values separately
- history snapshots restore authored values before capturing
- document transforms and property edits clear active previews first
- component updates, variants, duplication, and source capture cannot bake preview values into templates
- component replacement safely clears active behavior/data previews

### Q3 live-dev note

Q3 adds `Animations.lua`, `Bindings.lua`, and `MockData.lua` to `FORGEStudioDev`. After pulling Q3 for the first time, restart the Rojo servers once and reconnect the current place so all three modules appear in `ReplicatedStorage.FORGEStudioDev`. After that, Q3 changes return to the normal `Reload Dev` workflow.

## Q4A UI flow authoring

Quarter 4A adds screen/document flow authoring and an interactive UI-flow preview on top of the Q1-Q3 editor foundation.

### Screens

- named screen documents
- create screens
- open screens explicitly
- rename screens
- duplicate screens
- delete screens
- at least one screen is always preserved
- choose a project Start screen
- current and start markers in the Screens list
- searchable Screens panel
- per-screen device preset
- per-screen zoom
- per-screen pan
- screen definitions participate in Undo / Redo
- screen definitions and selected screen survive Reload Dev
- screen rename automatically remaps OpenScreen actions in:
  - current document roots
  - stored screen roots
  - component source templates
  - component variants

### Flow actions

Flow metadata is stored directly on the source GuiButton so it clones with components, variants, screens, history, and later runtime export.

Supported actions:

- None
- OpenScreen
- Back
- Show
- Hide
- Toggle

Flow authoring supports:

- capture selected TextButton or ImageButton as the action source
- use the selected Screen as a screen target
- use the selected UI object as a Root/Child target
- manually edit targets
- Set Action
- Clear
- Test
- Action, ActionTarget, Transition, and TransitionDuration metadata in Properties
- [FLOW:Action] markers in Explorer / Children
- Flow action types are searchable in Explorer / Children

### Transitions

Supported screen transitions:

- None
- Fade
- SlideLeft
- SlideRight
- Scale

Each action stores its own transition duration.

Transitions run only on temporary editor-preview state and never rewrite the authored root transforms.

### Interactive Preview

The Preview toolbar button switches FORGE Studio from edit interception into interactive click-through mode.

Interactive Preview:

- starts from the project's Start screen
- temporarily disables the editor interaction layer over the device
- connects authored Flow actions to actual GuiButton Activated events
- resolves mock-data bindings
- supports screen-to-screen navigation
- maintains a Back stack
- supports Show / Hide / Toggle behavior for modal-style roots and children
- supports Flow Test from the currently edited screen
- Esc exits Preview
- exiting Preview returns to the exact screen that was being edited before Preview started
- exiting Preview restores authored binding / animation / visibility state
- Reload Dev exits Preview first so temporary preview state is never captured
- mid-transition cancellation is generation-safe

### Q4A live-dev note

Q4A adds `Screens.lua` and `Navigation.lua` to `FORGEStudioDev`. After pulling Q4A for the first time, restart the Rojo servers once and reconnect the current place so both modules appear in `ReplicatedStorage.FORGEStudioDev`. After that, Q4A changes return to the normal `Reload Dev` workflow.

## Q4A flow authoring

Quarter 4A adds multi-screen UI flow authoring and interactive navigation preview.

### Screens

- named screen definitions
- create, open, rename, duplicate, and delete screens
- configurable start screen
- current and start screen markers
- per-screen device, zoom, and pan state
- screen definitions participate in Undo / Redo and Reload Dev
- OpenScreen flow targets remap when screens are renamed
- component definitions and variants also remap renamed screen targets

### Flow

- actions stored directly on GuiButtons
- action types: None, OpenScreen, Back, Show, Hide, Toggle
- transitions: None, Fade, SlideLeft, SlideRight, Scale
- target screen or current-screen object path
- transition duration
- source and target capture helpers
- action metadata appears in Properties and Children

### Interactive Preview

- starts from the configured Start screen
- disables editor interaction interception
- clickable authored GuiButtons
- navigation back stack
- Show / Hide / Toggle object behavior
- screen transitions
- Escape returns to Edit mode
- preview exits back to the exact screen that was being edited
- active transitions are safely canceled during preview exit or reload

## Q4B-1 RUCKUS design system integration

The first half of Q4B integrates the RUCKUS authored-UI design system into FORGE Studio while keeping FORGE's runtime/editor machinery generic.

### Style packs

- RUCKUS is the default authored-UI style pack
- Generic remains available as a fallback pack
- style selection participates in Undo / Redo and Reload Dev
- normal Insert uses the active style pack automatically
- style metadata is stored on authored objects for later runtime packaging

### RUCKUS tokens

- regular cream depth base around #DDD0B9
- Ivory and Warm
- cyan Accent, AccentMuted, and AccentSoft
- Danger and Success
- Gold and Silver surfaces
- Satin texture: rbxassetid://113178592047341
- Rubik font family: rbxassetid://12187365977
- Rubik Heavy headers
- square/angular default geometry
- explicit Pill geometry
- miter outline treatment
- persistent Gold / Silver shine metadata
- UIShadow support
- Common, Uncommon, Rare, Epic, Legendary, and Mythic rarity palette

### Style authoring

- Style toolbar popup
- switch active style pack
- cycle and apply surfaces
- Body, Strong, Header, and Caption typography roles
- cycle and apply rarity
- active-pack palette swatches feed the current color property
- StylePack, Surface, StylePreset, Typography, and Rarity metadata appears in Properties
- generated style helpers are hidden from the Children tree

### Built-in RUCKUS components

Built-in presets are installed into the same Q2 component library as protected style definitions:

- Panel
- InsetPanel
- Button
- PillButton
- GoldButton
- SilverButton
- IconButton
- BottomNavButton
- TextBox
- SectionHeader
- ProgressBar
- ProfileCard
- RarityTag

Button-like presets include Default, Hover, Pressed, Selected, and Disabled states where applicable. RarityTag includes rarity variants.

Built-in definitions:
- instantiate through the normal Components workflow
- use Q2 slots and variants
- are filtered by active style pack
- cannot be overwritten, variant-edited, or deleted
- are reinstalled deterministically after history/session restore
- are excluded from history snapshots to avoid clone bloat
- coexist with user-created components, which remain visible across style packs

### Q4B-1 live-dev note

Q4B-1 adds `StylePacks.lua` and `ComponentPresets.lua`. Q4A also added `Screens.lua` and `Navigation.lua`. After pulling this checkpoint for the first time, restart the Rojo servers once and reconnect the current place so all four files appear in `ReplicatedStorage.FORGEStudioDev`. After that, normal changes return to the `Reload Dev` workflow.

## Q4B-2 production packaging and runtime

Quarter 4B-2 turns authored FORGE Studio projects into validated runtime data for frozen FORGE.UI 1.0.0.

### Runtime packages

The Package panel captures the authored project into the `FORGE.UI.Project` schema.

Production export creates a deterministic package under `ReplicatedStorage.FORGEExports`:

```text
<ProjectName>/
├─ Runtime
├─ Project
├─ Animations
├─ Styles
├─ Editor
├─ Screens/
│  ├─ 001_<Screen>
│  └─ ...
└─ Components/
   ├─ 001_<Component>
   └─ ...
```

- `Runtime` contains only runtime-safe project data
- `Project` adds editor metadata back for lossless re-import
- screens and components are split into deterministic modules instead of one oversized source blob
- generated module names are stable and ordered for clean Rojo/Git diffs
- mock data, device view state, snap zones, screen margins, and editor lock metadata are excluded from `Runtime`
- editor-only metadata is retained in `Editor` so reopening the package restores the authoring project
- custom components are preserved
- protected built-ins are exported for runtime use but reinstalled from the current protected preset definitions when imported back into FORGE Studio

### Studio / Rojo workflow

Normal RUCKUS development no longer requires a manual export step.

1. Author normally in FORGE Studio.
2. Automatic validation and packaging maintain `ReplicatedStorage.FORGEExports.FORGEAutoProject`.
3. Fix any Error entries if the editor reports `Validation Failed`.
4. Press Play when the status is `Runtime Synced`.
5. The shared FORGE client bootstrap mounts the auto project before controller startup.
6. Use named **Export** only when you intentionally want a deterministic package copy for source control, handoff, or archival.

The automatic package contains the same split runtime/editor structure as a named export. The current screen is captured directly from the live document, so automatic packaging does not stop previews, reset bindings, or mutate stored screen state.

Direct project access:

```lua
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local FORGE = require(ReplicatedStorage.FORGE)

local Runtime = FORGE.UI.GetProject()
Runtime:SetData({
	Player = {
		DisplayName = 'Player'
	}
})
```

Manual package mounting is also available when needed:

```lua
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local FORGE = require(ReplicatedStorage.FORGE)
local Package = ReplicatedStorage.FORGEExports.RUCKUSUIProject

local Runtime = FORGE.UI.MountPackage(Package, {
	Data = {}
})
```

Reopening an authored package is done from FORGE Studio by selecting the generated package folder or its `Project` ModuleScript and using Import.

### FORGE.UI runtime bridge

`src/shared/ReplicatedStorage/FORGE/Engine/UI/ProjectRuntime.lua` consumes generated runtime data. `FORGE.UI` exposes additive project helpers through `MountProject`, `MountPackage`, `GetProject`, and `UnmountProject` while the existing widget/control surface remains stable.

Runtime behavior uses existing FORGE.UI systems:

- Widget / UserWidget ownership
- InputRouter hit testing and routing
- UIEvent propagation
- State for component state changes
- Animation for authored Q3 animation tracks
- StyleSet for packaged style resources

Supported authored flow behavior:

- OpenScreen
- Back
- Show
- Hide
- Toggle
- None, Fade, SlideLeft, SlideRight, and Scale transitions
- runtime screen stack

### Component states

Runtime components support:

- Default
- Hover
- Pressed
- Selected
- Disabled
- custom authored base variants

Regular RUCKUS surfaces keep shine hidden at rest, reveal it on hover/press, and return smoothly to the base state.

Gold and Silver surfaces keep their persistent shine and outline treatment across state changes. Shine remains a separate non-interactive overlay so it never blocks text/content or InputRouter targeting.

Runtime component creation also supports named authored Q2 slots and slot content. Code can use `GetComponentSlots`, `FillComponentSlot`, and `ClearComponentSlot` for dynamic lists such as friends, party members, inventories, or match rows.

### Bindings and animations

- authored `FORGEBinding_<Property>` metadata resolves against the runtime data source
- `ProjectRuntime:SetData(...)` refreshes existing non-reactive authored bindings immediately
- `ProjectRuntime:RefreshBindings(...)` is available for explicit refreshes
- mock data is not included in the runtime package
- true Runtime Preview may use editor mock data as a preview-only fixture
- animation definitions retain root-relative target paths, typed values, delay, duration, easing, reverse, loop, and stagger data
- runtime animation playback maps into FORGE.UI Animation

### Problems / Validation

The Problems panel validates the runtime package before export or true Runtime Preview.

Validation includes:

- missing Start screen
- missing OpenScreen targets
- missing Show / Hide / Toggle targets
- missing component definitions
- invalid component variants
- duplicate or malformed slots
- orphaned slot content
- invalid binding target properties
- mock-data binding paths that should resolve but do not
- invalid animation target paths
- invalid animation properties
- unavailable style packs
- unavailable surfaces
- unavailable rarities
- unavailable presets
- duplicate runtime object paths
- malformed package schema/version/API targets
- stale screen-order references

Problems carry Error, Warning, or Info severity. Screen/object, component/variant, and animation problems navigate back to the relevant authoring context where possible.

Export and Runtime Preview are blocked when validation contains errors.

### True Runtime Preview

Q4A Preview remains the fast editor simulation.

The Runtime toolbar button exercises the generated runtime representation through `ProjectRuntime` and FORGE.UI when the plugin is running in a Studio Play/Test client.

- editor Interactive Preview and Runtime Preview are mutually exclusive
- Runtime Preview validates before mounting
- Runtime Preview consumes the runtime-only view of the generated project
- preview data may use the editor Mock Data fixture without packaging it into Runtime
- reload and plugin destruction tear down the runtime preview first

### RUCKUS StyleSet

FORGE runtime remains generic. RUCKUS-specific styling lives in:

```text
src/shared/ReplicatedStorage/RUCKUS/UI/StyleSets/RUCKUS.lua
```

The RUCKUS StyleSet exposes the RUCKUS surfaces, rarities, Rubik typography roles, Satin asset, square/pill shape metadata, miter outline metadata, UIShadow metadata, and related tokens as a preset layer.

### Q4B-2 live-dev note

Q4B-2 adds `Serializer.lua`, `Packaging.lua`, and `Problems.lua` to `FORGEStudioDev` in Central and Game Server.

It also adds `ProjectRuntime.lua` to FORGE.UI and the RUCKUS runtime StyleSet.

After pulling the current editor pass for the first time, restart the Rojo servers once and reconnect each place so every live-dev module appears, including `Modifiers.lua`. When `FORGEStudioDev` is present, FORGE Studio starts from the live dev source automatically; use `Reload` after subsequent source edits when you want an immediate runtime rebuild.

## Build only

Run:

```bat
tools\BUILD_FORGE_STUDIO.bat
```

This builds `builds/FORGEStudio.rbxm` without pulling or installing it.

## v0.1 editor model

- Preview selection always resolves to a root object.
- Explorer lists only root objects.
- Children lists descendants of the selected root.
- Selecting a child in Children changes the Properties and Color target without changing the selected root.
- Selected roots can be moved and resized directly in Preview.
- Roots are assigned to one of nine zones:
  - TopLeft
  - TopCenter
  - TopRight
  - CenterLeft
  - Center
  - CenterRight
  - BottomLeft
  - BottomCenter
  - BottomRight
- Reassigning a zone preserves the root's current visual position.
- Zone guides can be toggled from the toolbar.
- Color supports classic swatches and RGB entry.
- Properties exposes common Roblox UI properties for direct editing.

## Source

```text
src/plugin/FORGEStudio/
├─ init.server.lua
├─ App.lua
├─ Animations.lua
├─ Bindings.lua
├─ ComponentPresets.lua
├─ Components.lua
├─ Document.lua
├─ History.lua
├─ MockData.lua
├─ Navigation.lua
├─ Packaging.lua
├─ Problems.lua
├─ Screens.lua
├─ Selection.lua
├─ Serializer.lua
├─ StylePacks.lua
├─ Theme.lua
└─ Widgets.lua

src/shared/ReplicatedStorage/FORGE/Engine/UI/
└─ ProjectRuntime.lua

src/shared/ReplicatedStorage/RUCKUS/UI/StyleSets/
└─ RUCKUS.lua
```
