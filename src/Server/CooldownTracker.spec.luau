return function()
	local require = require(script.Parent.loader).load(script)

	local Constants = require("CooldownManagerConstants")
	local CooldownTracker = require("CooldownTracker")

	local function makeClock(now)
		local clock = {
			Value = now or 100,
		}

		function clock:Now()
			return self.Value
		end

		return clock
	end

	local function makeScheduler()
		local scheduler = {
			Jobs = {},
		}

		function scheduler:Delay(delaySeconds, callback)
			local job = {
				Delay = delaySeconds,
				Callback = callback,
				Cancelled = false,
			}

			table.insert(self.Jobs, job)
			return job
		end

		function scheduler:Cancel(job)
			if job then
				job.Cancelled = true
			end
		end

		function scheduler:Run(index)
			local job = self.Jobs[index or #self.Jobs]
			if job and not job.Cancelled then
				job.Callback()
			end
		end

		return scheduler
	end

	local function makeTracker()
		local clock = makeClock()
		local scheduler = makeScheduler()
		local tracker = CooldownTracker.new("Owner", nil, clock :: any, scheduler :: any)
		return tracker, clock, scheduler
	end

	describe("CooldownTracker", function()
		it("starts and rejects an active cooldown by default", function()
			local tracker = makeTracker()

			local success, cooldown = tracker:TryStart("Abilities.Dash", 3)
			expect(success).to.equal(true)
			expect(cooldown:GetRemaining()).to.equal(3)

			local secondSuccess, secondCooldown = tracker:TryStart("Abilities.Dash", 3)
			expect(secondSuccess).to.equal(false)
			expect(secondCooldown).to.equal(cooldown)

			tracker:Destroy()
		end)

		it("supports restart, keep-longer, extend, and reduce policies", function()
			local tracker, clock = makeTracker()

			local _, cooldown = tracker:TryStart("Abilities.Fireball", 5)
			expect(cooldown:GetEndTime()).to.equal(105)

			clock.Value = 101
			local restartSuccess, restarted = tracker:TryStart("Abilities.Fireball", 10, {
				Policy = Constants.CooldownPolicy.Restart,
			})
			expect(restartSuccess).to.equal(true)
			expect(restarted:GetEndTime()).to.equal(111)

			clock.Value = 102
			local keepSuccess, kept = tracker:TryStart("Abilities.Fireball", 2, {
				Policy = Constants.CooldownPolicy.KeepLonger,
			})
			expect(keepSuccess).to.equal(true)
			expect(kept:GetEndTime()).to.equal(111)

			local extendedSuccess = tracker:Extend("Abilities.Fireball", 3)
			expect(extendedSuccess).to.equal(true)
			expect(tracker:GetCooldown("Abilities.Fireball"):GetEndTime()).to.equal(114)

			local reducedSuccess = tracker:Reduce("Abilities.Fireball", 4)
			expect(reducedSuccess).to.equal(true)
			expect(tracker:GetCooldown("Abilities.Fireball"):GetEndTime()).to.equal(110)

			tracker:Destroy()
		end)

		it("completes zero-duration and reduce-below-zero cooldowns safely", function()
			local tracker = makeTracker()

			local completedCount = 0
			local success, cooldown = tracker:TryStart("UI.Toast", 0)
			cooldown.Completed:Connect(function()
				completedCount += 1
			end)

			expect(success).to.equal(true)
			expect(tracker:GetCooldown("UI.Toast")).to.equal(nil)
			expect(cooldown:IsComplete()).to.equal(true)

			local _, active = tracker:TryStart("Abilities.Blink", 5)
			active.Completed:Connect(function()
				completedCount += 1
			end)

			expect(tracker:Reduce("Abilities.Blink", 100)).to.equal(true)
			expect(tracker:GetCooldown("Abilities.Blink")).to.equal(nil)
			expect(completedCount).to.equal(1)

			tracker:Destroy()
		end)

		it("cancels without firing normal completion", function()
			local tracker = makeTracker()
			local completedCount = 0
			local cancelledCount = 0

			local _, cooldown = tracker:TryStart("Tools.Sword.Primary", 1)
			cooldown.Completed:Connect(function()
				completedCount += 1
			end)
			cooldown.Cancelled:Connect(function()
				cancelledCount += 1
			end)

			expect(tracker:Cancel("Tools.Sword.Primary")).to.equal(true)
			expect(completedCount).to.equal(0)
			expect(cancelledCount).to.equal(1)
			expect(tracker:Cancel("Tools.Sword.Primary")).to.equal(false)

			tracker:Destroy()
		end)

		it("ignores stale scheduled completion entries", function()
			local tracker, clock, scheduler = makeTracker()
			local completedCount = 0

			local _, cooldown = tracker:TryStart("Abilities.Dash", 2)
			cooldown.Completed:Connect(function()
				completedCount += 1
			end)

			clock.Value = 101
			tracker:TryStart("Abilities.Dash", 5, {
				Policy = Constants.CooldownPolicy.Restart,
			})

			scheduler:Run(1)
			expect(completedCount).to.equal(0)
			expect(tracker:GetCooldown("Abilities.Dash") ~= nil).to.equal(true)

			clock.Value = 106
			scheduler:Run(2)
			expect(completedCount).to.equal(1)
			expect(tracker:GetCooldown("Abilities.Dash")).to.equal(nil)

			tracker:Destroy()
		end)

		it("validates durations and keys", function()
			local tracker = makeTracker()

			expect(function()
				tracker:TryStart("", 1)
			end).to.throw()

			expect(function()
				tracker:TryStart("__Internal", 1)
			end).to.throw()

			expect(function()
				tracker:TryStart("Bad..Key", 1)
			end).to.throw()

			expect(function()
				tracker:TryStart("Abilities.Dash", -1)
			end).to.throw()

			expect(function()
				tracker:TryStart("Abilities.Dash", 0 / 0)
			end).to.throw()

			expect(function()
				tracker:TryStart("Abilities.Dash", 1, {
					Policy = "Invalid",
				})
			end).to.throw()

			tracker:Destroy()
		end)

		it("acquires multiple cooldowns atomically", function()
			local tracker = makeTracker()

			local result = tracker:TryAcquire({
				Require = {
					"Abilities.Fireball",
					"Groups.GlobalAbility",
				},

				Start = {
					["Abilities.Fireball"] = 8,
					["Groups.GlobalAbility"] = 0.75,
				},
			})

			expect(result.Success).to.equal(true)
			expect(tracker:IsReady("Abilities.Fireball")).to.equal(false)
			expect(tracker:IsReady("Groups.GlobalAbility")).to.equal(false)

			local blocked = tracker:TryAcquire({
				Require = {
					"Abilities.Ice",
					"Groups.GlobalAbility",
				},

				Start = {
					["Abilities.Ice"] = 4,
				},
			})

			expect(blocked.Success).to.equal(false)
			expect(blocked.BlockedBy).to.equal("Groups.GlobalAbility")
			expect(tracker:IsReady("Abilities.Ice")).to.equal(true)

			tracker:Destroy()
		end)

		it("destroys repeatedly without error", function()
			local tracker = makeTracker()
			tracker:TryStart("Abilities.Dash", 1)

			tracker:Destroy()
			tracker:Destroy()

			expect(tracker:IsDestroyed()).to.equal(true)
		end)
	end)
end
