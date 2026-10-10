# FORGE Reforge

FORGE Reforge makes the framework easier to use by separating implementation complexity from normal game code.

## Status

- Phase 0 — Clean slate: complete
- Phase 1 — Foundation: complete
- Phase 2 — Developer API: complete
- Phase 3 — Data: complete
- Phase 4 — Replication and state: complete
- Phase 5 — Tooling: complete
- Phase 6 — RUCKUS systems: complete
- Reforge implementation: complete
- Full Studio runtime validation: pending
- Combat archive: `archive/combat-pre-reforge-2026-09-26`
- Active FORGE version: `4.4.1`

Layer 2 is now proven in live RUCKUS systems: `PlayerDataService` uses `FORGE.Service`/`:Expose`, `MatchSessionService` uses `Uses` dependency injection, and the Central party/matchmaking services use typed Contracts, scopes, permissions, and FORGE matchmaking.

## North star

FORGE should make Roblox infrastructure disappear.

Normal RUCKUS code should read like game logic. Common work should require one obvious API, minimal setup, and no knowledge of serialization, transports, registries, lifecycle internals, persistence plumbing, or replication machinery.

Complexity is allowed below the surface. Complexity is not allowed to leak upward without a reason.

## Layers

```text
FORGE
├─ Kernel
│  ├─ Core
│  └─ Networking
├─ Engine
│  ├─ UI
│  ├─ Gameplay
│  ├─ Data
│  ├─ Matchmaking
│  └─ future engine systems
└─ init.lua
```

Server-only pieces mirror the same architecture under `ServerScriptService/FORGE`.

### Kernel

Kernel is Layer 0.

Kernel owns substrate only:

- lifecycle
- registry
- dependency ordering
- loading
- logging
- local signal primitive
- cleanup primitive
- protocol
- serialization
- transport
- validation
- sessions
- rate limiting
- middleware
- low-level runtime state

Kernel must not own UI, VAULT/Data, Matchmaking, gameplay systems, analytics, inventories, currencies, or other game-facing systems.

Normal game code should almost never import Kernel directly.

### Engine

Engine is Layer 1.

Engine turns Kernel machinery into reusable systems:

- UI
- Data / VAULT
- Matchmaking
- Avatar
- Progression
- future Party, Analytics, Testing, Simulation, Transactions, etc.

Advanced code may use Engine directly when necessary.

### FORGE

The root `require(ReplicatedStorage.FORGE)` is Layer 2.

This is the normal developer experience.

Target vocabulary:

```lua
local FORGE = require(game.ReplicatedStorage.FORGE)

local Inventory = FORGE.Service('Inventory')
local HUD = FORGE.Controller('HUD')
local Party = FORGE:Get('Party')

local Changed = FORGE.Signal()
local Queueing = FORGE.State(false)

local UI = FORGE.UI
```

Current high-level primitives:

```lua
FORGE.Service(...)
FORGE.Controller(...)
FORGE:Get(...)

FORGE.State(...)
FORGE.Signal()
FORGE.Event()
FORGE.Scope()

FORGE.Profile(Player)
FORGE.Transaction(...)
FORGE.Currency(...)
FORGE.Inventory(...)

FORGE.Contract(...)
FORGE.Permission(...)
FORGE.To
FORGE.Replication

FORGE.Schema(...)
FORGE.Migration(...)

FORGE.Config
FORGE.Context
FORGE.Diagnostics
```

## Syntax rules

1. Nouns create concepts: `Service`, `Controller`, `State`, `Signal`.
2. Verbs perform actions: `Get`, `Open`, `Set`, `Expose`, `Grant`.
3. One obvious way for common tasks.
4. Same concept uses the same name on server and client.
5. Do not wrap Luau or Roblox APIs unless FORGE adds meaningful centralization.
6. Layer 2 uses game-development words, not infrastructure words.
7. Advanced escape hatches are allowed through `FORGE.Engine` and `FORGE.Kernel`.
8. New RUCKUS code should prefer Layer 2.
9. If a common task requires a Kernel import, the Layer 2 API is incomplete.

## Reforge order

### Phase 0 — Clean slate

- preserve the current combat implementation on an archive branch
- remove old combat from active development
- keep unrelated working systems intact
- document the new architecture

### Phase 1 — Foundation

- replace the old monolithic `Runtime` hierarchy with `Kernel` and `Engine`
- move Core and networking substrate into Kernel
- move UI, Data, Matchmaking, Avatar, and Progression into Engine
- keep `require(ReplicatedStorage.FORGE)` as the single public entry
- add simple `Service`, `Controller`, `Get`, `Signal`, and `State` APIs
- preserve lower-level compatibility APIs while RUCKUS migrates

### Phase 2 — Developer API

Complete.

- `FORGE.Scope()` and automatic component scopes
- bidirectional `FORGE.Event()`
- `FORGE.Contract()` backed by Kernel validation
- `Uses` / `Optional` dependency injection with aliases
- `FORGE.Config` and environment layers
- `FORGE.Context` plus environment shortcuts
- `FORGE.Diagnostics`, `FORGE.Inspect()`, and `FORGE.Debug()`
- `FORGE:Find()` for optional non-blocking lookups
- public type helpers such as `FORGE.String()` and `FORGE.Number()`

### Phase 3 — Data

Complete.

- `FORGE.Profile(Player)` server profile proxy
- transparent nested profile reads and validated writes
- read-only client profile replicas
- schema-controlled `Replicate` allow-lists
- `Profile:Watch(...)`
- `FORGE.Transaction(...)`
- `FORGE.Currency(...)`
- `FORGE.Inventory(...)`
- `FORGE.Schema(...)` and `FORGE.Migration(...)`
- shared public type syntax between networking contracts and datastore rules
- existing VAULT locking, auditing, autosave, validation, migrations and persistence retained under Engine/Data

### Phase 4 — Replication and state

Complete.

- Service-attached replicated `FORGE.State(...)`
- automatic client read-only State facades
- `FORGE.To.All`, Player, Players, Party and Match audiences
- automatic State refresh when scope membership changes
- custom replication scopes through `FORGE.Replication:RegisterScope(...)`
- scope-aware `FORGE.Event():Fire(...)`
- named `FORGE.Permission(...)` rules
- Contract `:Permission(...)`
- Any/All permission composition
- permission checks routed through the existing Kernel middleware boundary
- MatchSessionService now exposes a real Match-scoped replicated Session State
- PartyService now maintains Party scope membership and uses declarative PartyLeader permissions

### Phase 5 — Tooling

Complete.

- `FORGE.Metric(...)`
- `FORGE.Trace(...)`
- `FORGE.Test(...)` and `FORGE.Tests:Run()`
- lightweight `FORGE.Simulate` actors/scenarios
- dependency graph snapshots through `FORGE.Graph()`
- health checks through `FORGE.Health()`
- network request/event counters
- richer `FORGE.Inspect()`
- Studio-only Reforge self-tests
- FORGE Studio Framework Inspector backed directly by `FORGE.Inspect()`
- specialized matchmaking live-transport harness retained under Developer tooling

### Phase 6 — RUCKUS systems

Complete for the currently active non-combat game.

- PlayerDataService now uses `FORGE.Profile()` and automatic data-schema loading
- MatchmakingService uses `FORGE.Queue()`, `FORGE.Profile()`, dependency injection, Scope cleanup, Contracts, Permissions, Metrics and Trace
- PartyService uses Layer 2 endpoints, Scope cleanup, Party replication scopes and declarative leader permissions
- MatchSessionService uses `FORGE.Match()`, Match-scoped State, injected dependencies and automatic Scope cleanup
- MatchmakingDiagnosticsController uses `FORGE.Controller()` and Scope lifecycle
- Central now directly owns party and matchmaking
- obsolete separate Lobby place and relay source removed
- combat-era Game Server analytics and UI scratch tests removed from active runtime

Combat remains intentionally archived and is reintroduced only after the complete Reforge runtime test passes.

## Design test

Before adding a public FORGE feature, ask:

> Could a developer reasonably guess how to use this without understanding FORGE internals?

If the answer is no, simplify the public API before adding more machinery.
