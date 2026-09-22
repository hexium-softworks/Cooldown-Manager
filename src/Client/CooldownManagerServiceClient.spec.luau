return function()
	local require = require(script.Parent.loader).load(script)

	local CooldownManagerServiceClient = require("CooldownManagerServiceClient")
	local ReplicationUtils = require("CooldownManagerReplicationUtils")

	local function makeReplicationClient()
		local replicationClient = {
			Observers = {},
		}

		function replicationClient:ObserveState(stateId)
			return {
				Subscribe = function(_, callback)
					table.insert(self.Observers, {
						StateId = stateId,
						Callback = callback,
					})
					callback(nil)

					return {
						Disconnect = function() end,
						Destroy = function() end,
					}
				end,
			}
		end

		return replicationClient
	end

	local function makeClient(now)
		local replicationClient = makeReplicationClient()
		local client = table.clone(CooldownManagerServiceClient)
		client:Init({
			GetService = function()
				return replicationClient
			end,
		})
		local clock = {
			Value = now or 100,
		}

		function clock:Now()
			return self.Value
		end

		client:SetClock(clock)
		return client, clock, replicationClient
	end

	describe("CooldownManagerServiceClient", function()
		it("calculates ready, remaining, and progress from snapshots", function()
			local client, clock = makeClient(100)

			expect(client:IsReady("Abilities.Dash")).to.equal(true)

			client:_ApplyCooldown({
				Key = "Abilities.Dash",
				StartTime = 100,
				EndTime = 104,
				Duration = 4,
			})

			expect(client:IsReady("Abilities.Dash")).to.equal(false)
			expect(client:GetRemaining("Abilities.Dash")).to.equal(4)

			clock.Value = 102
			expect(client:GetRemaining("Abilities.Dash")).to.equal(2)
			expect(client:GetProgress("Abilities.Dash")).to.equal(0.5)

			clock.Value = 105
			expect(client:GetCooldown("Abilities.Dash")).to.equal(nil)
			expect(client:IsReady("Abilities.Dash")).to.equal(true)

			client:Destroy()
		end)

		it("applies ReplicationService cooldown maps with encoded keys", function()
			local client = makeClient()
			local encodedKey = ReplicationUtils.encodeKey("Abilities.Dash")

			client:_ApplyCooldownMap({
				[encodedKey] = {
					Key = "Abilities.Dash",
					StartTime = 100,
					EndTime = 103,
					Duration = 3,
				},
			})

			expect(client:IsReady("Abilities.Dash")).to.equal(false)

			client:_ApplyCooldownMap({})
			expect(client:IsReady("Abilities.Dash")).to.equal(true)

			client:Destroy()
		end)

		it("emits cooldown and ready observers", function()
			local client = makeClient()
			local cooldownValues = {}
			local readyValues = {}

			local cooldownConnection = client:ObserveCooldown("Abilities.Dash", function(snapshot)
				table.insert(cooldownValues, snapshot)
			end)

			local readyConnection = client:ObserveReady("Abilities.Dash", function(isReady)
				table.insert(readyValues, isReady)
			end)

			client:_ApplyCooldown({
				Key = "Abilities.Dash",
				StartTime = 100,
				EndTime = 103,
				Duration = 3,
			})

			client:_RemoveCooldown("Abilities.Dash")

			expect(#cooldownValues).to.equal(3)
			expect(cooldownValues[1]).to.equal(nil)
			expect(cooldownValues[2].Key).to.equal("Abilities.Dash")
			expect(cooldownValues[3]).to.equal(nil)

			expect(#readyValues).to.equal(3)
			expect(readyValues[1]).to.equal(true)
			expect(readyValues[2]).to.equal(false)
			expect(readyValues[3]).to.equal(true)

			cooldownConnection:Disconnect()
			readyConnection:Disconnect()
			client:Destroy()
		end)

		it("does not expose authoritative mutation methods", function()
			local client = makeClient()

			expect((client :: any).Start).to.equal(nil)
			expect((client :: any).Cancel).to.equal(nil)
			expect((client :: any).Extend).to.equal(nil)
			expect((client :: any).Reduce).to.equal(nil)
			expect((client :: any).Clear).to.equal(nil)

			client:Destroy()
		end)
	end)
end