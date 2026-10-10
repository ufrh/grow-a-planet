# FORGE 4.4.1 API Reference

FORGE is the centralized developer-facing layer for RUCKUS.

## Entry point

~~~lua
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local FORGE = require(ReplicatedStorage:WaitForChild('FORGE'))
~~~

Current version:

~~~lua
print(FORGE.Version)
~~~

## Service

### FORGE.Service(Name, Options?) -> Service

Server only.

Creates and registers a Layer-2 server service.

~~~lua
local Inventory = FORGE.Service('Inventory')
~~~

Options:

| Field | Purpose |
| --- | --- |
| Name | Alternative table-definition name |
| Priority | Lifecycle ordering priority |
| Uses | Required dependencies |
| Optional | Optional dependencies |
| Dependencies / Requires | Compatibility aliases for Uses |
| OptionalDependencies | Compatibility alias for Optional |

Required dependency list:

~~~lua
local Shop = FORGE.Service('Shop', {
	Uses = {'PlayerDataService', 'InventoryService'}
})
~~~

Aliased dependencies:

~~~lua
local Shop = FORGE.Service('Shop', {
	Uses = {
		Data = 'PlayerDataService',
		Inventory = 'InventoryService'
	}
})

function Shop:Start()
	print(self.Data)
	print(self.Inventory)
end
~~~

Optional dependency:

~~~lua
local Shop = FORGE.Service('Shop', {
	Optional = {
		Analytics = 'AnalyticsService'
	}
})
~~~

If the optional system is absent, the alias is simply not injected.

### Service lifecycle

Supported lifecycle methods:

~~~lua
function Service:Init()
	
end

function Service:Start()
	
end

function Service:Stop()
	
end

function Service:Destroy()
	
end
~~~

Typical rule:

- Init configures local state and dependencies.
- Start connects runtime behavior.
- Stop pauses runtime behavior.
- Destroy releases final owned state.
- Automatic Scope cleanup happens during lifecycle shutdown.

## Controller

### FORGE.Controller(Name, Options?) -> Controller

Client only.

~~~lua
local HUD = FORGE.Controller('HUD', {
	Priority = 50,
	Uses = {
		Party = 'PartyController'
	}
})
~~~

Controllers use the same lifecycle and Scope helpers as Services.

## Automatic component Scope

Every Layer-2 Service/Controller receives:

| Method | Behavior |
| --- | --- |
| self:Track(Object, Method?) | Track cleanup resource |
| self:Connect(Signal, Callback) | Connect and auto-disconnect |
| self:After(Delay, Callback) | Delayed task tied to component lifetime |
| self:Every(Interval, Callback, Immediate?) | Repeating task tied to lifetime |
| self:Spawn(Callback, ...) | Spawn task tied to lifetime |
| self.Scope | Underlying Scope object |

Example:

~~~lua
function Lobby:Start()
	self:Connect(game.Players.PlayerAdded, function(Player)
		print(Player.Name)
	end)

	self:Every(5, function()
		print('tick')
	end)
end
~~~

No manual Connections table is required.

## Scope

### FORGE.Scope() -> Scope

Standalone cleanup container.

Methods:

| Method | Returns |
| --- | --- |
| Add(Object, Method?) | Object |
| Track(Object, Method?) | Object |
| Connect(Signal, Callback) | Connection |
| After(Delay, Callback) | thread |
| Every(Interval, Callback, Immediate?) | thread |
| Spawn(Callback, ...) | thread |
| Child() | child Scope |
| Cleanup() | nil |
| Destroy() | nil |

Example:

~~~lua
local Scope = FORGE.Scope()

Scope:Connect(workspace.ChildAdded, function(Object)
	print(Object.Name)
end)

Scope:Track(function()
	print('cleaned')
end)

Scope:Destroy()
~~~

## Getting systems

### FORGE:Get(Name)

Server:

Returns the registered local component.

Client:

Returns the network facade for a remote Service after FORGE has started.

~~~lua
local Party = FORGE:Get('PartyService')
~~~

### FORGE:Find(Name)

Nonblocking optional lookup.

Returns nil if the component/service facade is unavailable.

~~~lua
local Analytics = FORGE:Find('AnalyticsService')
~~~

### FORGE.GetService(Name)

Compatibility/specialized service lookup.

Server returns a local Service. Client returns a remote facade.

### FORGE.GetController(Name)

Returns a local Controller.

## Signals

### FORGE.Signal() -> Signal

Local-only event primitive.

Common methods:

~~~lua
local Changed = FORGE.Signal()

local Connection = Changed:Connect(function(Value)
	print(Value)
end)

Changed:Fire(true)
Changed:Once(function() end)
Changed:Wait()

Connection:Disconnect()
Changed:Destroy()
~~~

Use Signal when data never needs to cross the network.

## State

### FORGE.State(Value) -> State

Local reactive state.

~~~lua
local Queueing = FORGE.State(false)

Queueing:Subscribe(function(Value, Previous)
	print(Value, Previous)
end)

Queueing:Set(true)

Queueing:Update(function(Value)
	return not Value
end)

print(Queueing:Get())
~~~

### Replicated State

Assign a State with Replicate to a Service.

~~~lua
local Match = FORGE.Service('Match')

Match.Status = FORGE.State('Waiting', {
	Replicate = FORGE.To.All
})
~~~

Server owns writes:

~~~lua
Match.Status:Set('Playing')
~~~

Client receives a read-only State facade:

~~~lua
local Match = FORGE:Get('Match')

print(Match.Status:Get())

Match.Status:Subscribe(function(Status)
	print(Status)
end)
~~~

Client Set/Update calls on replicated State throw.

### State audiences

~~~lua
FORGE.To.All
FORGE.To.Player(Player)
FORGE.To.Players({PlayerA, PlayerB})
FORGE.To.Party(PartyId)
FORGE.To.Match(MatchId)
~~~

Change audience:

~~~lua
Match.Status:SetAudience(FORGE.To.Match(MatchId))
~~~

Alias:

~~~lua
Match.Status:Audience(FORGE.To.Match(MatchId))
~~~

Force current visibility/value to selected clients:

~~~lua
Match.Status:Refresh()
Match.Status:Refresh(Player)
Match.Status:Refresh({PlayerA, PlayerB})
~~~

## Replication scopes

### FORGE.Replication:SetScope(Player, Name, Key)

Server only.

~~~lua
FORGE.Replication:SetScope(Player, 'Party', PartyId)
FORGE.Replication:SetScope(Player, 'Match', MatchId)
~~~

Changing scope membership refreshes registered replicated States for that Player.

### FORGE.Replication:GetScope(Player, Name)

Returns the current scope key.

### FORGE.Replication:RegisterScope(Name, Resolver?)

Custom scope.

Function resolver:

~~~lua
FORGE.Replication:RegisterScope('Team', function(Player)
	return Player.Team and Player.Team.Name
end)
~~~

Then:

~~~lua
local Audience = FORGE.To.Team('Red')
~~~

String resolver registers a Player attribute name.

## Events

### FORGE.Event(ContractOrOptions?) -> Event

A Service Event can receive client fire-and-forget messages and send server events back to clients.

Server:

~~~lua
local Chat = FORGE.Service('Chat')

Chat.Message = FORGE.Event(
	FORGE.Contract({
		FORGE.String({MinLength = 1, MaxLength = 100})
	})
)

Chat.Message:Connect(function(Player, Text)
	Chat.Message:Broadcast(Player.DisplayName, Text)
end)
~~~

Client:

~~~lua
local Chat = FORGE:Get('Chat')

Chat.Message:Connect(function(Name, Text)
	print(Name, Text)
end)

Chat.Message:Fire('hello')
~~~

Server send methods:

~~~lua
Chat.Message:Fire(FORGE.To.Player(Player), 'private')
Chat.Message:Fire(FORGE.To.Party(PartyId), 'party')
Chat.Message:Fire(FORGE.To.Match(MatchId), 'match')
Chat.Message:Broadcast('global')
~~~

Event:Fire requires an explicit target/audience. Use Broadcast for everyone.

Other methods:

| Method | Purpose |
| --- | --- |
| Connect | Subscribe |
| Once | One-shot subscription |
| Wait | Yield for next event |
| Fire | Server: audience send; client: send to server |
| Broadcast / FireAll | Server send to all |
| Destroy | Release local signal |

## Exposed RPC methods

### Service:Expose(Name, ContractOrOptions?)

Turns an ordinary Service method into a client-callable RPC.

Server:

~~~lua
local Shop = FORGE.Service('Shop')

function Shop:Buy(Player, ItemId)
	return true
end

Shop:Expose('Buy')
~~~

Client:

~~~lua
local Shop = FORGE:Get('Shop')
local Success = Shop:Buy('GoldenGloves')
~~~

The Player is injected automatically on the server.

## Contracts

### FORGE.Contract(Schema?, Options?) -> Contract

~~~lua
local Buy = FORGE.Contract({
	FORGE.String({MinLength = 1, MaxLength = 40}),
	FORGE.Number({Integer = true, Min = 1})
}, {
	Rate = {
		Capacity = 10,
		Refill = 5
	}
})
~~~

Methods:

| Method | Purpose |
| --- | --- |
| Validate(...) | Validate locally |
| ToOptions(Overrides?) | Produce endpoint options |
| Rate(Capacity, Refill) | Configure rate limit |
| Rate(false) | Disable rate limit |
| Middleware(...) | Replace middleware list |
| AllowExtra(Boolean) | Allow extra arguments |
| Permission(Rule) | Attach permission rule |

### Type descriptors

~~~lua
FORGE.Any()
FORGE.String({MinLength = 1, MaxLength = 40, Pattern = '...'})
FORGE.Number({Min = 0, Max = 100, Integer = true})
FORGE.Boolean()
FORGE.Vector2()
FORGE.Vector3()
FORGE.CFrame()
FORGE.Color3()
FORGE.Table({MaxEntries = 20})
FORGE.Enum(Enum.KeyCode)
FORGE.Maybe(FORGE.String())
~~~

The same descriptors are used by VAULT schema Rules.

## Permissions

### FORGE.Permission(Name, Callback)

Registers reusable server authority logic.

~~~lua
FORGE.Permission('PartyLeader', function(Player)
	return Party:IsLeader(Player), 'Only the party leader can do that.'
end)
~~~

Contract:

~~~lua
local Kick = FORGE.Contract({
	FORGE.Number({Integer = true, Min = 1})
}):Permission('PartyLeader')
~~~

Direct endpoint option:

~~~lua
Service:Expose('AdminAction', {
	Permission = 'Admin'
})
~~~

Composition:

~~~lua
Permission = {
	All = {'Authenticated', 'PartyLeader'}
}
~~~

~~~lua
Permission = {
	Any = {'Admin', 'Moderator'}
}
~~~

Permission callback signature:

~~~text
Callback(Player, Context) -> allowed:boolean, reason:string?
~~~

## Config

### FORGE:Configure(Values)

Deep-merges public game/framework configuration.

~~~lua
FORGE:Configure({
	Match = {
		MaxPlayers = 12,
		Time = 300
	}
})
~~~

### FORGE.Config:Get(Path, Default?)

~~~lua
local Time = FORGE.Config:Get('Match.Time', 300)
~~~

### FORGE.Config:Set(Path, Value)

~~~lua
FORGE.Config:Set('Match.Time', 360)
~~~

### FORGE.Config:Merge(Values)

Same concept as FORGE:Configure.

### FORGE.Config:Layer(Name, Values)

Environment-aware config override.

~~~lua
FORGE.Config:Layer('Studio', {
	Match = {
		MaxPlayers = 2
	}
})
~~~

### FORGE.Config:Snapshot()

Returns merged config copy.

Kernel config remains available at FORGE.Kernel.Config but is an advanced escape hatch.

## Context

Properties:

~~~lua
FORGE.Context.Server
FORGE.Context.Client
FORGE.Context.Studio
FORGE.Context.Production
FORGE.Context.Running
FORGE.Context.PlaceId
FORGE.Context.GameId
FORGE.Context.JobId
FORGE.Context.Side
FORGE.Context.Environment
~~~

Shortcuts:

~~~lua
FORGE.IsServer
FORGE.IsClient
FORGE.IsStudio
FORGE.IsProduction
~~~

Check:

~~~lua
if FORGE.Context:Is('Studio') then
	
end
~~~

Snapshot:

~~~lua
local Context = FORGE.Context:Snapshot()
~~~

## Middleware

Advanced server API.

### FORGE.RegisterMiddleware(Name, Callback)

Registers named Kernel endpoint middleware.

### FORGE.UseMiddleware(Callback)

Adds global server middleware.

Use permissions/contracts before custom middleware when possible.

## Data shortcuts

Detailed reference: [VAULT.md](VAULT.md)

Root methods:

~~~lua
FORGE.Profile(Player, Options?)
FORGE.Transaction(PlayerOrProfile, Callback, Options?)
FORGE.Currency(Name, Options?)
FORGE.Inventory(Name, Options?)
FORGE.Schema(Definition)
FORGE.Migration(Version, Callback)
~~~

Advanced:

~~~lua
FORGE.GetData()
FORGE.Engine.Data
~~~

## Matchmaking shortcuts

Detailed reference: [MATCHMAKING.md](MATCHMAKING.md)

~~~lua
FORGE.Queue(Name, Definition?)
FORGE.Match(MatchId)
FORGE.GetMatchmaking()
~~~

## UI

Detailed reference: [UI.md](UI.md)

~~~lua
local UI = FORGE.UI
local Runtime = UI.GetProject()
~~~

## Metrics

### FORGE.Metric(Name) -> Metric

~~~lua
local Completed = FORGE.Metric('Match.Completed')

Completed:Add(1)
Completed:Set(10)
Completed:Observe(14.2)
Completed:Reset()

local Snapshot = Completed:Snapshot()
~~~

Snapshot includes:

- Name
- Value
- Count
- Sum
- Min
- Max
- Last
- Average

## Tracing

### FORGE.Trace(Name, Callback, Fields?, ...) -> callback results

~~~lua
local Result = FORGE.Trace('Shop.Buy', function()
	return BuyItem()
end, {
	Item = 'GoldenGloves'
})
~~~

Manual span:

~~~lua
local Span = FORGE.Trace('Inventory.Load', {
	UserId = Player.UserId
})

Span:Finish(true)
~~~

Failed traces increment a trace error metric.

## Tests

### FORGE.Test(Name, Callback, Options?)

~~~lua
FORGE.Test('Currency math', function(T)
	T:Equal(2 + 2, 4)
	T:Truthy(true)
end)
~~~

### FORGE.Tests:Run(Filter?)

~~~lua
local Report = FORGE.Tests:Run('Currency')
~~~

### FORGE.Tests:Snapshot()

Returns test registration/latest-result data.

Test context:

| Assertion | Purpose |
| --- | --- |
| T:Equal(A, B, Message?) | Equality |
| T:Truthy(Value, Message?) | Truthy |
| T:Falsy(Value, Message?) | Falsy |
| T:Near(A, B, Epsilon?, Message?) | Numeric approximation |
| T:Type(Value, RobloxType, Message?) | typeof check |
| T:Throws(Callback, Message?) | Must throw |
| T:NoError(Callback, Message?) | Must not throw |

## Simulation

### FORGE.Simulate.Players(Count, Factory?) -> synthetic actors

~~~lua
local Actors = FORGE.Simulate.Players(12)
~~~

Synthetic actors support:

~~~lua
Actor.UserId
Actor.Name
Actor.DisplayName
Actor.Data
Actor.Synthetic

Actor:GetAttribute(Name)
Actor:SetAttribute(Name, Value)
~~~

These are logic-test actors, not real Roblox clients.

### FORGE.Simulate.Run(Name, Callback, Options?) -> report

~~~lua
local Report = FORGE.Simulate.Run('12 player test', function(Context)
	return #Context.Players
end, {
	Players = 12
})
~~~

## Diagnostics

### FORGE.Inspect() -> snapshot

Includes:

- Version
- Context
- Started / Starting
- Components
- Dependency graph
- Health
- Network counts/stats
- Tooling metrics/traces/tests
- Boot report

### FORGE.Debug()

Prints human-readable snapshot summary.

### FORGE.Graph()

Returns dependency graph nodes.

Each includes:

- Name
- Kind
- Priority
- Requires
- Optional
- Dependents

### FORGE.Health()

Returns:

~~~lua
{
	Healthy = true,
	Issues = {}
}
~~~

### FORGE.Diagnostics:Get(Name)

Returns one component lifecycle/dependency snapshot.

## Lifecycle control

Normally Launch scripts own this.

Advanced methods:

~~~lua
FORGE.Start(Options)
FORGE.Stop()
FORGE.Destroy()
FORGE.Shutdown()
FORGE.GetBootReport()
~~~

Do not manually Start FORGE from normal services/controllers.

## Escape hatches

~~~lua
FORGE.Engine
FORGE.Kernel
FORGE.Class
FORGE.Janitor
FORGE.Types
~~~

These exist for framework and compatibility work.

New RUCKUS gameplay should prefer Layer-2 APIs documented above.
