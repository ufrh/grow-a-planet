# VAULT / FORGE Data API Reference

VAULT is the persistence engine under FORGE.Engine.Data.

Normal RUCKUS game code should usually use:

~~~lua
FORGE.Profile(Player)
FORGE.Transaction(...)
FORGE.Currency(...)
FORGE.Inventory(...)
FORGE.Schema(...)
FORGE.Migration(...)
~~~

instead of directly importing VAULT internals.

## Architecture

~~~text
RUCKUS gameplay
     ↓
FORGE.Profile / Currency / Inventory
     ↓
FORGE.Engine.Data
     ↓
VAULT Store / Profile
     ↓
Roblox DataStoreService
~~~

VAULT provides:

- session ownership
- schema validation
- migrations
- autosave
- dirty tracking
- path validation
- bounded audit history
- profile replication allow-lists
- idempotent receipt processing
- global stores
- ordered leaderboards
- version history
- offline updates

## Datastore schemas

Store modules are automatically loaded from ServerScriptService/Data/Stores during FORGE server startup.

Typical definition:

~~~lua
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local FORGE = require(ReplicatedStorage.FORGE)

return FORGE.Schema({
	Name = 'Player',
	Version = 4,
	Players = true,
	DataStore = 'RuckusPlayerData',
	Scope = 'production',

	Data = {
		Currency = {
			Credits = 0,
			Cosmetics = 0
		},

		Stats = {
			Wins = 0
		}
	},

	Replicate = {
		'Currency',
		'Stats'
	},

	Rules = {
		['Currency.Credits'] = FORGE.Number({
			Min = 0,
			Integer = true
		}),

		['Stats.Wins'] = FORGE.Number({
			Min = 0,
			Integer = true
		})
	},

	Migrations = {
		FORGE.Migration(4, function(Data)
			Data.Stats = Data.Stats or {Wins = 0}
			return Data
		end)
	}
})
~~~

### Schema fields

| Field | Alias | Purpose |
| --- | --- | --- |
| Name | module filename fallback | Logical Store name |
| Version | SchemaVersion | Positive integer schema version |
| Data | Template | Default profile structure |
| DataStore | DataStoreName | Roblox datastore name |
| Scope | - | DataStore scope |
| Prefix | KeyPrefix | User key prefix |
| Players | BindPlayers | Auto-load/release connected Players |
| Rules | - | Path validation descriptors |
| Migrations | - | Version migration callbacks |
| Replicate | Replication | Client replication allow-list |
| Config | - | Store-local VAULT config overrides |
| Enabled | - | Data.Load skips module when false |

Players = true makes the Store bind to Players automatically.

## Rules

VAULT uses the same public type descriptors as FORGE Contracts.

~~~lua
FORGE.Any()
FORGE.String({MinLength = 1, MaxLength = 40, Pattern = '...'})
FORGE.Number({Min = 0, Max = 100, Integer = true})
FORGE.Boolean()
FORGE.Vector2()
FORGE.Vector3()
FORGE.CFrame()
FORGE.Color3()
FORGE.Table({MaxEntries = 100})
FORGE.Enum(Enum.KeyCode)
FORGE.Maybe(FORGE.String())
~~~

Rules are keyed by dot-delimited profile path.

~~~lua
Rules = {
	['Settings.Music'] = FORGE.Number({
		Min = 0,
		Max = 1
	})
}
~~~

## Replication

Replicate is an explicit allow-list.

~~~lua
Replicate = {
	'Currency',
	'Stats',
	'Progression.Level'
}
~~~

Only those paths are included in client profile snapshots.

Replicate all profile data:

~~~lua
Replicate = true
~~~

Explicit paths are preferred.

No Replicate field means the client gets an empty data view for that Store.

## Migrations

### FORGE.Migration(Version, Callback)

~~~lua
Migrations = {
	FORGE.Migration(2, function(Data)
		Data.Settings = Data.Settings or {}
		return Data
	end),

	FORGE.Migration(3, function(Data)
		Data.Currency.Cosmetics = Data.Currency.Cosmetics or 0
		return Data
	end)
}
~~~

Migrations are normalized to a version -> callback map internally.

## Profiles

### FORGE.Profile(Player?, Options?) -> Profile?

Server:

~~~lua
local Profile = FORGE.Profile(Player)
~~~

Client:

~~~lua
local Profile = FORGE.Profile()
~~~

Client may only request the local Player profile and receives a read-only replicated view.

Options:

| Field | Purpose |
| --- | --- |
| Store | Store name, default Player |
| Wait | Server waits for profile unless false |
| Timeout | Server wait timeout, default 30 |

Example alternative Store:

~~~lua
local Profile = FORGE.Profile(Player, {
	Store = 'Account',
	Wait = true,
	Timeout = 10
})
~~~

## Transparent profile access

Server profile wrappers support table-like reads and writes:

~~~lua
local Profile = FORGE.Profile(Player)

print(Profile.Currency.Credits)

Profile.Currency.Credits += 100
Profile.Settings.Music = .5
~~~

Nested tables become proxy nodes so assignment still goes through VAULT validation.

Client profile wrappers support the same read shape:

~~~lua
local Profile = FORGE.Profile()

print(Profile.Currency.Credits)
~~~

Writes on client replicas throw.

## Profile methods

### Profile:Get(Path) -> value

~~~lua
local Credits = Profile:Get('Currency.Credits')
~~~

Returns copied data.

### Profile:Set(Path, Value) -> success, reason?

~~~lua
local Success, Reason = Profile:Set('Settings.Music', .5)
~~~

Server only.

### Profile:Has(Path) -> boolean

~~~lua
if Profile:Has('Inventory.Owned.GoldenGloves') then
	
end
~~~

### Profile:Increment(Path, Delta) -> success, valueOrReason

~~~lua
local Success, Credits = Profile:Increment('Currency.Credits', 100)
~~~

Server only.

### Profile:Update(Path, Callback) -> success, reason?

~~~lua
Profile:Update('Matchmaking.MMR', function(Current)
	return Current + 25
end)
~~~

Server only.

### Profile:Transaction(Callback) -> success, reason?

~~~lua
Profile:Transaction(function(Data)
	Data.Currency.Credits -= 500
	Data.Inventory.Owned.GoldenGloves = true
end)
~~~

VAULT deep-copies the entire draft, runs the callback, validates the complete result, then atomically replaces live in-memory profile data.

Returning false from the callback aborts the transaction.

### Profile:Snapshot() -> table

~~~lua
local Data = Profile:Snapshot()
~~~

Returns a copy.

### Profile:Watch(Path, Callback) -> Connection

~~~lua
Profile:Watch('Currency.Credits', function(Value, Previous, ChangedPath)
	print(Value)
end)
~~~

A full transaction change path of * also triggers path watchers.

### Profile:Save()

Server only.

Forces persistence while keeping the session active.

### Profile:Raw()

Returns the underlying raw VAULT Profile on the server.

Use only when you need advanced methods such as receipt processing, audit metadata or release behavior.

## FORGE.Transaction

### FORGE.Transaction(PlayerOrProfile, Callback, Options?) -> success, reason?

Player:

~~~lua
FORGE.Transaction(Player, function(Data)
	Data.Stats.Wins += 1
	Data.Stats.Matches += 1
end)
~~~

Existing Profile:

~~~lua
local Profile = FORGE.Profile(Player)

FORGE.Transaction(Profile, function(Data)
	Data.Currency.Credits += 50
end)
~~~

## Currency

### FORGE.Currency(Name, Options?) -> Currency

Default:

~~~lua
local Credits = FORGE.Currency('Credits')
~~~

Default path:

~~~text
Currency.Credits
~~~

Options:

| Field | Purpose |
| --- | --- |
| Store | Store name, default Player |
| Path | Data path, default Currency.Name |

Methods:

### Currency:Get(Player) -> number

~~~lua
local Balance = Credits:Get(Player)
~~~

### Currency:Set(Player, Amount)

~~~lua
Credits:Set(Player, 1000)
~~~

### Currency:Add(Player, Amount)

~~~lua
Credits:Add(Player, 100)
~~~

### Currency:CanAfford(Player, Amount) -> boolean

~~~lua
if Credits:CanAfford(Player, 500) then
	
end
~~~

### Currency:Spend(Player, Amount) -> success, balanceOrReason

Spend runs through a profile transaction.

~~~lua
local Success, Balance = Credits:Spend(Player, 500)
~~~

Custom currency path:

~~~lua
local Tickets = FORGE.Currency('Tickets', {
	Path = 'Events.Summer.Tickets'
})
~~~

## Inventory

### FORGE.Inventory(Name, Options?) -> Inventory

~~~lua
local Cosmetics = FORGE.Inventory('Cosmetics')
~~~

Default paths:

~~~text
Inventory.Owned
Inventory.Equipped
~~~

Options:

| Field | Purpose |
| --- | --- |
| Store | Store name |
| Path / Owned | Owned-items path |
| Equipped | Equipped-items path |

### Inventory:GetOwned(Player) -> table

### Inventory:GetEquipped(Player) -> table

### Inventory:Has(Player, ItemId) -> boolean

~~~lua
Cosmetics:Has(Player, 'GoldenGloves')
~~~

### Inventory:Grant(Player, ItemId) -> success, grantedOrReason

~~~lua
Cosmetics:Grant(Player, 'GoldenGloves')
~~~

Already-owned item returns success with false for newly granted.

### Inventory:Remove(Player, ItemId)

Removes ownership and clears matching equipped slots.

### Inventory:Equip(Player, Slot, ItemId)

~~~lua
Cosmetics:Equip(Player, 'Hands', 'GoldenGloves')
~~~

Fails when the item is not owned.

### Inventory:Unequip(Player, Slot)

~~~lua
Cosmetics:Unequip(Player, 'Hands')
~~~

Custom paths:

~~~lua
local Weapons = FORGE.Inventory('Weapons', {
	Owned = 'Loadout.Weapons',
	Equipped = 'Loadout.EquippedWeapons'
})
~~~

## Advanced raw VAULT Profile

~~~lua
local Profile = FORGE.Profile(Player)
local Raw = Profile:Raw()
~~~

Raw Profile methods:

| Method | Purpose |
| --- | --- |
| Get(Path) | Copied path read |
| Has(Path) | Path exists |
| Snapshot() | Full copied data |
| Metadata() | Persistence metadata |
| GetAuditTrail() | Bounded in-memory mutation journal |
| IsDirty() | Unsaved mutation status |
| IsReleased() | Session released status |
| Set(Path, Value) | Validated write |
| Increment(Path, Delta) | Validated numeric mutation |
| Update(Path, Callback) | Validated transform |
| Transaction(Callback) | Full draft transaction |
| HasReceipt(Id) | Receipt already processed |
| ProcessReceipt(Id, Callback) | Atomic idempotent receipt mutation |
| Save() | Persist and retain lock |
| Release() | Save and release session ownership |

### Receipt processing

Use for Developer Product / purchase-style idempotency.

~~~lua
local Raw = FORGE.Profile(Player):Raw()

local Success, Result = Raw:ProcessReceipt(PurchaseId, function(Data)
	Data.Currency.Cosmetics += 1000
end)
~~~

The mutation and receipt id are committed together.

## Advanced Store API

Normal gameplay should not need this.

~~~lua
local Data = FORGE.GetData()
local Store = Data.GetStore('Player')
~~~

Data manager methods:

| Method | Purpose |
| --- | --- |
| Data.Store(Name, Definition?) | Get/create Store |
| Data.CreateStore(Definition) | Create Store from definition |
| Data.Load(Folder) | Load schema ModuleScripts |
| Data.GetStore(Name) | Get Store |
| Data.GetPublicSnapshot(Name, Player) | Replication-safe snapshot |
| Data.DestroyStore(Name) | Destroy Store |
| Data.Global(Name, Options?) | Get/create GlobalStore |
| Data.GetGlobal(Name) | Get GlobalStore |
| Data.DestroyGlobal(Name) | Destroy GlobalStore |
| Data.DestroyAll() | Shutdown all data systems |

FORGE automatically calls Data.Load on ServerScriptService/Data/Stores during normal server startup.

## Store API

Signals:

~~~text
Store.Loaded
Store.Released
Store.SaveFailed
Store.LockLost
Store.Corrupted
~~~

Public methods:

| Method | Purpose |
| --- | --- |
| LoadUserId(UserId, Player?) | Load profile/session |
| LoadPlayer(Player) | Load Player profile |
| GetProfile(PlayerOrUserId) | Get loaded profile |
| WaitForProfile(PlayerOrUserId, Timeout?) | Wait for load |
| UpdateOffline(UserId, Callback) | Update non-loaded user |
| ListVersions(UserId, Limit?) | Version history |
| RestoreVersion(UserId, Version) | Restore saved version |
| WipeUserId(UserId, Confirmation) | Destructive wipe |
| BindPlayers() | Auto Player load/release |
| Shutdown() | Save/release all profiles |
| Destroy() | Final cleanup |

Store properties include:

~~~lua
Store.Name
Store.DataStoreName
Store.SchemaVersion
Store.Template
Store.Rules
Store.Migrations
Store.Replicate
Store.Config
Store.Scope
Store.Global
Store.Leaderboards
Store.Versions
~~~

## Global data

Every Store owns Store.Global.

Or:

~~~lua
local Data = FORGE.GetData()
local Global = Data.Global('World')
~~~

GlobalStore methods:

| Method | Purpose |
| --- | --- |
| Get(Key, Default?) | Read |
| Set(Key, Value) | Write |
| Update(Key, Callback, Default?) | Atomic transform |
| Increment(Key, Delta) | Numeric atomic add |
| Delete(Key) | Delete |
| Destroy() | Cleanup |

Example:

~~~lua
local Global = FORGE.GetData().Global('World')

Global:Update('Season', function(Current)
	Current = Current or {}
	Current.Number = (Current.Number or 0) + 1
	return Current
end)
~~~

## Leaderboards

Every Store owns Store.Leaderboards.

Methods:

| Method | Purpose |
| --- | --- |
| Set(Name, Key, Score) | Set ordered score |
| Increment(Name, Key, Delta) | Increment score |
| Remove(Name, Key) | Remove entry |
| GetTop(Name, Limit?, Ascending?) | Query sorted page |
| Destroy() | Cleanup |

Example:

~~~lua
local Store = FORGE.GetData().GetStore('Player')

Store.Leaderboards:Set('Wins', Player.UserId, 100)

local Success, Top = Store.Leaderboards:GetTop('Wins', 50, false)
~~~

## Versioning and destructive operations

VAULT has version history and restoration through Store:ListVersions / RestoreVersion.

WipeUserId is intentionally destructive and requires the Store's confirmation contract. Do not expose it to clients.

## Recommended RUCKUS patterns

Gameplay reward:

~~~lua
local Credits = FORGE.Currency('Credits')

function Rewards:GiveWin(Player)
	Credits:Add(Player, 100)
end
~~~

Atomic purchase:

~~~lua
local Credits = FORGE.Currency('Credits')
local Cosmetics = FORGE.Inventory('Cosmetics')

function Shop:Buy(Player, ItemId, Price)
	return FORGE.Transaction(Player, function(Data)
		if Data.Currency.Credits < Price then return false end

		Data.Currency.Credits -= Price
		Data.Inventory.Owned[ItemId] = true
	end)
end
~~~

Reactive client HUD:

~~~lua
local Profile = FORGE.Profile()

Profile:Watch('Currency.Credits', function(Credits)
	UpdateCredits(Credits)
end)
~~~

## Boundary rules

- Server owns persistent writes.
- Client Profile is read-only.
- Replicate only client-needed data.
- Prefer Transaction for multi-field economic changes.
- Prefer Currency/Inventory views over duplicating persistence systems.
- Use ProcessReceipt for idempotent purchases.
- Use raw Store/Profile APIs only when Layer 2 cannot express the operation.
