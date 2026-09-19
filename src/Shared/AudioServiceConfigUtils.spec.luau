--!strict
--[=[
	@class AudioServiceConfigUtils.spec
]=]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local AudioServiceConfigUtils = require("AudioServiceConfigUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("AudioServiceConfigUtils", function()
	it("accepts valid category configs", function()
		expect(function()
			AudioServiceConfigUtils.validateCategoryConfig({
				Name = "SoundEffects",
				Volume = 0.8,
			})
		end).never.toThrow()
	end)

	it("clamps category volume", function()
		expect(AudioServiceConfigUtils.clampVolume(2)).toBe(1)
		expect(AudioServiceConfigUtils.clampVolume(-1)).toBe(0)
	end)

	it("rejects unknown category fields", function()
		expect(function()
			AudioServiceConfigUtils.validateCategoryConfig({
				Name = "Music",
				LegacySoundGroup = "Nope",
			})
		end).toThrow()
	end)

	it("rejects unsafe names", function()
		expect(function()
			AudioServiceConfigUtils.validateEffectPresetConfig({
				Name = "Bad/Preset",
				Effects = {},
			})
		end).toThrow()
	end)

	it("accepts supported modern audio effect classes", function()
		expect(function()
			AudioServiceConfigUtils.validateEffectConfig({
				Name = "Muffle",
				ClassName = "AudioEqualizer",
				Properties = {
					LowGain = -6,
				},
			})
		end).never.toThrow()
	end)

	it("rejects legacy sound effect classes", function()
		expect(function()
			AudioServiceConfigUtils.validateEffectConfig({
				Name = "Legacy",
				ClassName = "ReverbSoundEffect",
			})
		end).toThrow()
	end)

	it("requires playback source data", function()
		expect(function()
			AudioServiceConfigUtils.validatePlaybackConfig({
				Name = "MissingSource",
				Category = "Music",
			})
		end).toThrow()
	end)
end)
