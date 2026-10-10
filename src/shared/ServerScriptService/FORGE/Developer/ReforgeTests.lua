local ReforgeTests = {}

function ReforgeTests.Register(FORGE)
	FORGE.Test('Reforge/State local mutation', function(T)
		local State = FORGE.State(1)
		local Seen

		local Connection = State:Subscribe(function(Value)
			Seen = Value
		end)

		State:Set(2)
		T:Equal(State:Get(), 2)
		T:Equal(Seen, 2)

		Connection:Disconnect()
		State:Destroy()
	end)

	FORGE.Test('Reforge/Contract validation', function(T)
		local Contract = FORGE.Contract({
			FORGE.String({MinLength = 2, MaxLength = 8}),
			FORGE.Number({Min = 1, Max = 10, Integer = true})
		})

		local Valid = Contract:Validate('ok', 5)
		T:Truthy(Valid)

		local Invalid = Contract:Validate('x', 5)
		T:Falsy(Invalid)
	end)

	FORGE.Test('Reforge/Scope cleanup', function(T)
		local Scope = FORGE.Scope()
		local Cleaned = false

		Scope:Track(function()
			Cleaned = true
		end)

		Scope:Destroy()
		T:Truthy(Cleaned)
	end)

	FORGE.Test('Reforge/Metrics', function(T)
		local Metric = FORGE.Metric('Tests.ReforgeMetric')
		Metric:Reset()
		Metric:Add(2)
		Metric:Add(3)

		local Snapshot = Metric:Snapshot()
		T:Equal(Snapshot.Value, 5)
		T:Equal(Snapshot.Count, 2)
		T:Near(Snapshot.Average, 2.5)
	end)

	FORGE.Test('Reforge/Trace', function(T)
		local Value = FORGE.Trace('Tests.ReforgeTrace', function()
			return 42
		end)

		T:Equal(Value, 42)
		local Snapshot = FORGE.Inspect()
		T:Truthy(#(Snapshot.Tooling.Traces or {}) > 0)
	end)

	FORGE.Test('Reforge/Simulation actors', function(T)
		local Actors = FORGE.Simulate.Players(12)
		T:Equal(#Actors, 12)
		T:Truthy(Actors[1].Synthetic)
		T:Equal(Actors[1].UserId, -1)
	end)

	FORGE.Test('Reforge/Dependency graph', function(T)
		local Graph = FORGE.Graph()
		T:Truthy(type(Graph) == 'table')
		T:Truthy(#Graph > 0)
	end)

	FORGE.Test('Reforge/Health snapshot', function(T)
		local Health = FORGE.Health()
		T:Truthy(type(Health) == 'table')
		T:Truthy(type(Health.Issues) == 'table')
	end)
end

function ReforgeTests.Run(FORGE)
	ReforgeTests.Register(FORGE)
	return FORGE.Tests:Run('Reforge/')
end

return ReforgeTests
