return function()
	local require = require(script.Parent.loader).load(script)

	local CooldownManagerService = require("CooldownManagerService")

	local function makeReplicationService()
		local replicationService = {
			States = {},
		}

		function replicationService:CreateState(config)
			local state = {
				Config = config,
				Sets = {},
				Deletes = {},
				Destroyed = false,
			}

			function state:IsDestroyed()
				return self.Destroyed
			end

			function state:Set(path, value)
				table.insert(self.Sets, {
					Path = path,
					Value = value,
				})
			end

			function state:Delete(path)
				table.insert(self.Deletes, path)
			end

			function state:Destroy()
				self.Destroyed = true
			end

			table.insert(self.States, state)
			return state
		end

		return replicationService
	end

	local function makeService()
		local replicationService = makeReplicationService()
		local service = table.clone(CooldownManagerService)
		service:Init({
			GetService = function()
				return replicationService
			end,
		})
		service:SetClock({
			Now = function()
				return 100
			end,
		})
		return service, replicationService
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

		it("does not create replicated states for non-player owners", function()
			local service, replicationService = makeService()

			local success = service:TryStart("Global", "Abilities.Dash", 1, {
				Replicate = true,
			})

			expect(success).to.equal(true)
			expect(#replicationService.States).to.equal(0)

			service:Destroy()
		end)
	end)
end