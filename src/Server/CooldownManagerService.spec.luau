return function()
	local require = require(script.Parent.loader).load(script)

	local Constants = require("CooldownManagerConstants")
	local CooldownManagerService = require("CooldownManagerService")

	local function makeService()
		local service = table.clone(CooldownManagerService)
		service:Init({})
		service:SetClock({
			Now = function()
				return 100
			end,
		})
		return service
	end

	describe("CooldownManagerService", function()
		it("creates, finds, clears, and destroys owner trackers", function()
			local service = makeService()
			local owner = {}

			local tracker = service:GetTracker(owner)
			expect(service:FindTracker(owner)).to.equal(tracker)

			service:TryStart(owner, "Abilities.Dash", 3)
			expect(service:IsReady(owner, "Abilities.Dash")).to.equal(false)

			service:Clear(owner)
			expect(service:IsReady(owner, "Abilities.Dash")).to.equal(true)

			expect(service:DestroyTracker(owner)).to.equal(true)
			expect(service:FindTracker(owner)).to.equal(nil)
			expect(service:DestroyTracker(owner)).to.equal(false)

			service:Destroy()
		end)

		it("calls the replication adapter only for replicated cooldowns", function()
			local service = makeService()
			local owner = "Global"
			local calls = {}

			service:SetReplicationAdapter({
				CooldownStarted = function(_, callOwner, key, snapshot)
					table.insert(calls, {
						Method = "Started",
						Owner = callOwner,
						Key = key,
						EndTime = snapshot.EndTime,
					})
				end,

				CooldownUpdated = function(_, callOwner, key, snapshot)
					table.insert(calls, {
						Method = "Updated",
						Owner = callOwner,
						Key = key,
						EndTime = snapshot.EndTime,
					})
				end,

				CooldownRemoved = function(_, callOwner, key)
					table.insert(calls, {
						Method = "Removed",
						Owner = callOwner,
						Key = key,
					})
				end,
			})

			service:TryStart(owner, "Server.Only", 1)
			expect(#calls).to.equal(0)

			service:TryStart(owner, "Abilities.Dash", 3, {
				Replicate = true,
			})
			expect(#calls).to.equal(1)
			expect(calls[1].Method).to.equal("Started")
			expect(calls[1].Key).to.equal("Abilities.Dash")

			service:TryStart(owner, "Abilities.Dash", 4, {
				Policy = Constants.CooldownPolicy.Restart,
			})
			expect(#calls).to.equal(2)
			expect(calls[2].Method).to.equal("Updated")

			service:Cancel(owner, "Abilities.Dash")
			expect(#calls).to.equal(3)
			expect(calls[3].Method).to.equal("Removed")

			service:Destroy()
		end)

		it("allows replicated cooldowns without an adapter", function()
			local service = makeService()

			local success = service:TryStart("Global", "Abilities.Dash", 1, {
				Replicate = true,
			})

			expect(success).to.equal(true)
			service:Destroy()
		end)
	end)
end
