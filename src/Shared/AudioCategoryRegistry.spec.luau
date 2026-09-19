--!strict
--[=[
	@class AudioCategoryRegistry.spec
]=]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local AudioCategoryRegistry = require("AudioCategoryRegistry")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("AudioCategoryRegistry", function()
	it("defaults unknown categories to full volume", function()
		local registry = AudioCategoryRegistry.new()

		expect(registry:GetVolume("Music")).toBe(1)

		registry:Destroy()
	end)

	it("registers and updates category volumes", function()
		local registry = AudioCategoryRegistry.new()

		registry:RegisterCategories({
			{ Name = "Music", Volume = 0.25 },
			{ Name = "Alarms", Volume = 2 },
		})

		expect(registry:GetVolume("Music")).toBe(0.25)
		expect(registry:GetVolume("Alarms")).toBe(1)

		registry:SetVolume("Music", 0.5)
		expect(registry:GetVolume("Music")).toBe(0.5)

		registry:Destroy()
	end)

	it("observes current and changed volume", function()
		local registry = AudioCategoryRegistry.new()
		local observed = {}

		local connection = registry:ObserveVolume("Voice", function(volume)
			table.insert(observed, volume)
		end)

		registry:SetVolume("Voice", 0.6)

		expect(observed[1]).toBe(1)
		expect(observed[2]).toBe(0.6)

		connection:Disconnect()
		registry:Destroy()
	end)
end)
