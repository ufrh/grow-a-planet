local RunService = game:GetService('RunService')

local Bootstrap = {} do
	function Bootstrap.Start(FORGE)
		if RunService:IsStudio() then
			local Report = require(script.Parent.ReforgeTests).Run(FORGE)
			print(string.format(
				'[FORGE Reforge Tests] %d/%d passed • %.2fms',
				Report.Passed,
				Report.Total,
				Report.Duration * 1000
			))

			for _, Result in ipairs(Report.Results) do
				if not Result.Passed then
					warn(string.format('[FORGE Reforge Test FAIL] %s\n%s', Result.Name, tostring(Result.Error)))
				end
			end
		end

		local Matchmaking = FORGE.GetMatchmaking()
		local Harness = Matchmaking.Test

		if not Harness then
			Harness = require(script.Parent.Matchmaking.Harness).new(Matchmaking, Matchmaking.Config, Matchmaking.Stats)
			Matchmaking.Test = Matchmaking.AttachExtension('Developer.Matchmaking', Harness)
		end

		return Harness
	end
end

return Bootstrap
