# VAULT Data Framework

VAULT is a standalone, server-only Roblox persistence framework designed as one root ModuleScript with a hierarchy of focused submodules.

It does not create RemoteEvents, RemoteFunctions, or client APIs. Persistent writes only happen through server-side profile methods. This removes the most common client exploit path, but no framework can make bad server logic magically safe: if your server blindly accepts an exploiter-supplied value and writes it, that is still a server bug. VAULT's job is to make safe server-authoritative persistence the default and to reject malformed, invalid, stale, or conflicting data.

## Included systems

- Player profile loading and automatic player binding
- Atomic DataStore `UpdateAsync` writes
- Cross-server session locking with stale-lock recovery
- Autosave plus session heartbeat refresh
- Parallel shutdown release
- Retry logic with Roblox request-budget awareness
- Schema templates
- Schema reconciliation
- Strict unknown-path rejection
- Per-path validation rules
- Ordered schema migrations
- Deep-copy reads and writes
- Complete server-side transactions
- Atomic numeric increments
- Idempotent receipt processing
- Bounded persisted receipt history
- Offline profile updates
- Safe destructive wipe guard
- Native DataStore version listing
- Native historical version restore
- Roblox datatype serialization
- Cycle detection
- NaN/infinity rejection
- Serialization depth/node/string limits
- Serialized payload byte-size protection
- Atomic global key/value storage
- Cross-server global-cache invalidation with MessagingService
- Global numeric counters
- OrderedDataStore leaderboards
- Leaderboard query caching
- Runtime change signals
- Save-failure signals
- Corruption signals
- Session-lock-loss signals
- Bounded in-memory audit trail
- No client-facing storage surface

## Supported serialized values

VAULT serializes ordinary Lua values plus:

- `Vector2`
- `Vector3`
- `Color3`
- `CFrame`
- `UDim`
- `UDim2`
- `Rect`
- `NumberRange`
- `BrickColor`
- `DateTime`
- `EnumItem`
- `NumberSequence`
- `ColorSequence`
- nested tables with string, boolean, or finite numeric keys

Unsupported Instances/functions/threads/userdata are rejected before they reach DataStore.

## Clean datastore structure

VAULT now separates framework internals from game datastore definitions. Your game code only needs one `Data` ModuleScript, and each datastore is its own definition module.

```text
ServerScriptService
├── VAULT [ModuleScript]
│   ├── Config
│   ├── Core
│   ├── Global
│   ├── Security
│   ├── Serialization
│   └── Util
│
└── Data [ModuleScript]
    └── Stores [Folder]
        ├── Player [ModuleScript]
        ├── Season [ModuleScript]
        └── Competitive [ModuleScript]
```

`Data/init.lua` is intentionally tiny:

```lua
local VAULT = require(game.ServerScriptService.VAULT)

local Data = VAULT.Load(script:WaitForChild('Stores'))

return Data
```

The rest of the server can then use:

```lua
local Data = require(game.ServerScriptService.Data)

local PlayerData = Data.Player
```

## Creating a datastore

The filename becomes the logical store name, so a module named `Player` can simply return its data definition.

```lua
local VAULT = require(game.ServerScriptService.VAULT)
local Rules = VAULT.Rules

return {
	Version = 1,
	Players = true,

	DataStore = 'RuckusPlayerData',
	Scope = 'production',

	Data = {
		Currency = {
			Credits = 0,
			Cosmetics = 0;
		},

		Stats = {
			Wins = 0;
		},

		Inventory = {};
	},

	Rules = {
		['Currency.Credits'] = Rules.Number({Min = 0; Integer = true;}),
		['Currency.Cosmetics'] = Rules.Number({Min = 0; Integer = true;}),
		['Stats.Wins'] = Rules.Number({Min = 0; Integer = true;});
	};
}
```

`Players = true` automatically binds player joining, profile loading, session locking, autosaving, leaving and shutdown release. No separate `BindPlayers()` call is required.

The cleaner aliases map to the original internals:

- `Version` → `SchemaVersion`
- `Data` → `Template`
- `DataStore` → `DataStoreName`
- `Prefix` → `KeyPrefix`
- `Players = true` → automatic player binding

The original `VAULT.CreateStore({...})` API remains supported for compatibility.

## Loaded profiles

```lua
local Profile = PlayerData:GetProfile(Player)

local Credits = Profile:Get('Currency.Credits')

Profile:Set('Currency.Credits', 500)
Profile:Increment('Stats.Wins', 1)

Profile:Update('Currency.Credits', function(Current)
	return Current + 100
end)

Profile:Transaction(function(Draft)
	Draft.Currency.Credits += 250
	Draft.Stats.Wins += 1
end)

Profile:Save()
```

`Get` and `Snapshot` return deep copies. Do not mutate private fields beginning with `_`.

## Dynamic tables

An empty table in the template is treated as a dynamic map.

```lua
Inventory = {};
```

With strict schema enabled, arbitrary keys are allowed below `Inventory`, while arbitrary root-level fields are rejected.

## Validation rules

```lua
Rules = {
	['Currency.Credits'] = VAULT.Rules.Number({Min = 0; Max = 1000000; Integer = true;}),
	['Settings.Title'] = VAULT.Rules.String({MinLength = 1; MaxLength = 24;}),
	['Settings.Mode'] = VAULT.Rules.Values({'Casual', 'Ranked';}, 'string');
}
```

Custom validators are server functions:

```lua
local function validateRating(Value)
	return Value >= 0 and Value <= 5000, 'rating outside accepted range'
end

Rules['Ranked.Rating'] = VAULT.Rules.Custom(validateRating, 'number')
```

## Migrations

Migration functions are keyed by the version they migrate *into*.

```lua
local function migrateTo2(Data)
	Data.Currency.Cosmetics = Data.Currency.Cosmetics or 0

	return Data
end

local function migrateTo3(Data)
	Data.Stats.Matches = Data.Stats.Wins + Data.Stats.Losses

	return Data
end

Migrations = {
	[2] = migrateTo2,
	[3] = migrateTo3;
}
```

A profile stored at schema 1 and loaded by schema 3 runs migration 2 and then migration 3 before reconciliation and validation.

## Session locking

Every loaded profile has a unique session token persisted inside the same DataStore record. Loads use `UpdateAsync` and refuse to overwrite a fresh lock from another server.

Autosaves refresh the lock heartbeat. If a server crashes, the lock becomes reclaimable after `SessionLockTimeout`.

Every save verifies the token again. If another session somehow becomes authoritative, the old profile is invalidated instead of overwriting the newer session.

## Receipts

For Developer Products or any idempotent server transaction:

```lua
local function grantPurchase(Draft)
	Draft.Currency.Cosmetics += 500
end

local Success, Result = Profile:ProcessReceipt(PurchaseId, grantPurchase)
```

The receipt id and data mutation are persisted in the same `UpdateAsync`. Reprocessing the same id returns `already processed`.

## Offline mutations

Use this for admin grants, delayed rewards, or systems that operate when a user is not in the current server.

```lua
local function grantOffline(Draft)
	Draft.Currency.Credits += 1000
end

local Success, Reason = PlayerData:UpdateOffline(UserId, grantOffline)
```

VAULT refuses the write if the profile is loaded locally or has a non-stale session lock in another server.

Offline callbacks must not yield.

## Globals

```lua
PlayerData.Global:Set('CurrentSeason', 4)

local Success, Season = PlayerData.Global:Get('CurrentSeason', 1)

PlayerData.Global:Increment('MatchesPlayed', 1)

local function updateRecord(Current)
	Current = Current or {Pot = 0;}

	Current.Pot = math.max(Current.Pot, NewPot)

	return Current
end

PlayerData.Global:Update('RecordPot', updateRecord, {Pot = 0;})
```

Global data uses the same serializer and payload limits. Writes publish tiny MessagingService invalidations so other servers discard stale cache entries.

## Leaderboards

```lua
PlayerData.Leaderboards:Set('Wins', Player.UserId, Wins)
PlayerData.Leaderboards:Increment('Knockouts', Player.UserId, 1)

local Success, Entries = PlayerData.Leaderboards:GetTop('Wins', 50, false)
```

Entries look like:

```lua
{
	{
		rank = 1,
		key = '123456',
		value = 938;
	};
}
```

## Version history

```lua
local Success, Versions = PlayerData:ListVersions(UserId, 20)
```

To restore an old native DataStore version, the user must be offline:

```lua
PlayerData:RestoreVersion(UserId, VersionId)
```

The historical data is migrated and validated against the current schema before becoming current.

## Wiping data

Production wipes are disabled by default.

A wipe requires the profile to be offline and an exact confirmation string:

```lua
PlayerData:WipeUserId(UserId, 'WIPE:' .. tostring(UserId))
```

To permit this in the `production` scope, explicitly set:

```lua
Config = {
	AllowProductionWipes = true;
}
```

## Signals

```lua
PlayerData.Loaded:Connect(onLoaded)
PlayerData.Released:Connect(onReleased)
PlayerData.SaveFailed:Connect(onSaveFailed)
PlayerData.LockLost:Connect(onLockLost)
PlayerData.Corrupted:Connect(onCorrupted)

Profile.Changed:Connect(onChanged)
Profile.Released:Connect(onProfileReleased)
```

## Important security rules

1. Keep VAULT in `ServerScriptService`.
2. Never require VAULT from client code.
3. Never expose a generic `Set(path, value)` RemoteEvent.
4. Client requests should describe intent, not final authoritative values.
5. Validate gameplay permissions before calling profile mutations.
6. Use VAULT rules as a second line of defense, not as game-design authorization.
7. Never directly mutate `Profile._Data`.
8. Never directly write to the underlying Roblox DataStore.
9. Use `ProcessReceipt` for idempotent purchases.
10. Use `UpdateOffline` instead of bypassing session locks.

## FORGE integration

VAULT is intentionally independent of FORGE.

A FORGE service can require the store on the server and expose narrow intent-based methods:

```lua
function ShopService.Client.BuyItem(Player, ItemId)
	local Profile = PlayerData:GetProfile(Player)

	if not Profile then return false end

	-- validate item, ownership, price and permissions here
	-- then mutate through Profile methods

	return true
end
```

Do not expose VAULT itself to FORGE clients.

## Studio

Roblox DataStore APIs require Studio API access when testing live persistence. Use a non-production scope such as `development` while testing destructive or migration behavior.

## DataStore size

VAULT intentionally caps encoded payloads below Roblox's hard record limit. The default safety ceiling is 3.5 MB, leaving room for record metadata and serialization overhead.

If you are approaching that size, split the data model instead of simply raising the limit.
