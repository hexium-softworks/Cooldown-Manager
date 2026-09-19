--!strict
--[=[
	@class AudioGraphBuilder.spec
]=]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local AudioCategoryRegistry = require("AudioCategoryRegistry")
local AudioGraphBuilder = require("AudioGraphBuilder")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function canCreateAudioApi(): boolean
	local ok, instance = pcall(Instance.new, "AudioPlayer")
	if ok and typeof(instance) == "Instance" then
		instance:Destroy()
		return true
	end

	return false
end

local function countClass(root: Instance, className: string): number
	local count = 0
	for _, descendant in root:GetDescendants() do
		if descendant:IsA(className) then
			count += 1
		end
	end
	return count
end

local function expectNoLegacyAudio(root: Instance): ()
	for _, descendant in root:GetDescendants() do
		expect(descendant:IsA("Sound")).toBe(false)
		expect(descendant:IsA("SoundGroup")).toBe(false)
		expect(descendant:IsA("SoundEffect")).toBe(false)
	end
end

local function expectInstance(handle: any, kind: string): Instance
	local instance = handle:GetInstance(kind)
	expect(instance).never.toBeNil()
	return instance :: Instance
end

if canCreateAudioApi() then
	describe("AudioGraphBuilder", function()
		it("builds a 2D playback graph with modern audio instances and wires", function()
			local parent = Instance.new("Folder")
			local registry = AudioCategoryRegistry.new()
			registry:RegisterCategory({
				Name = "Music",
				Volume = 0.5,
			})

			local output = Instance.new("AudioDeviceOutput")
			output.Parent = parent

			local builder = AudioGraphBuilder.new({
				categoryRegistry = registry,
			})

			local handle = builder:BuildPlayback2D({
				Name = "MusicCue",
				Asset = "rbxassetid://123456789",
				Category = "Music",
				AutoPlay = false,
				Effects = {
					{
						Name = "Muffle",
						ClassName = "AudioEqualizer",
					},
				},
			}, parent, output)

			expect(expectInstance(handle, "Player"):IsA("AudioPlayer")).toBe(true)
			expect(expectInstance(handle, "GraphVolume"):IsA("AudioFader")).toBe(true)
			expect(expectInstance(handle, "MasterVolume"):IsA("AudioFader")).toBe(true)
			expect(expectInstance(handle, "CategoryVolume"):IsA("AudioFader")).toBe(true)
			expect(expectInstance(handle, "Muffle"):IsA("AudioEqualizer")).toBe(true)
			expect(countClass(parent, "Wire")).toBe(5)
			expectNoLegacyAudio(parent)

			handle:Destroy()
			registry:Destroy()
		end)

		it("builds a 3D playback graph targeting an AudioEmitter", function()
			local parent = Instance.new("Folder")
			local registry = AudioCategoryRegistry.new()
			local emitter = Instance.new("AudioEmitter")
			emitter.Parent = parent

			local builder = AudioGraphBuilder.new({
				categoryRegistry = registry,
			})

			local handle = builder:BuildPlayback3D({
				Name = "WorldCue",
				Asset = "rbxassetid://123456789",
				AutoPlay = false,
			}, parent, emitter)

			expect(expectInstance(handle, "Player"):IsA("AudioPlayer")).toBe(true)
			expect(expectInstance(handle, "Emitter")).toBe(emitter)
			expect(countClass(parent, "Wire")).toBe(3)
			expectNoLegacyAudio(parent)

			handle:Destroy()
			registry:Destroy()
		end)

		it("builds a voice route from AudioDeviceInput to output", function()
			local parent = Instance.new("Folder")
			local registry = AudioCategoryRegistry.new()
			registry:RegisterCategory({
				Name = "Voice",
				Volume = 0.75,
			})

			local input = Instance.new("AudioDeviceInput")
			input.Parent = parent

			local output = Instance.new("AudioDeviceOutput")
			output.Parent = parent

			local builder = AudioGraphBuilder.new({
				categoryRegistry = registry,
			})

			local handle = builder:BuildVoiceRoute({
				Name = "VoiceRoute",
				Category = "Voice",
			}, parent, input, output)

			expect(expectInstance(handle, "Input")).toBe(input)
			expect(expectInstance(handle, "Target")).toBe(output)
			expect(expectInstance(handle, "CategoryVolume"):IsA("AudioFader")).toBe(true)
			expect(countClass(parent, "Wire")).toBe(4)
			expectNoLegacyAudio(parent)

			handle:Destroy()
			registry:Destroy()
		end)
	end)
end
