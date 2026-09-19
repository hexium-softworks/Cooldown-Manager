--!strict
--[=[
	Lifetime handle for a generated audio graph.

	@class AudioGraphHandle
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")

local AudioServiceConfigUtils = require("AudioServiceConfigUtils")
local AudioServiceConstants = require("AudioServiceConstants")

local AudioGraphHandle = {}
AudioGraphHandle.ClassName = "AudioGraphHandle"
AudioGraphHandle.__index = AudioGraphHandle

export type AudioGraphHandle = typeof(setmetatable(
	{} :: {
		_maid: Maid.Maid,
		_instances: { [string]: Instance },
		_effectsByName: { [string]: Instance },
		_categoryRegistry: any,
		_categoryName: string,
		_categoryFader: AudioFader?,
		_masterFader: AudioFader?,
		_perGraphFader: AudioFader?,
		_player: AudioPlayer?,
		_voiceInput: AudioDeviceInput?,
	},
	AudioGraphHandle
))

function AudioGraphHandle.new(args: {
	instances: { [string]: Instance }?,
	effectsByName: { [string]: Instance }?,
	categoryRegistry: any,
	categoryName: string?,
	categoryFader: AudioFader?,
	masterFader: AudioFader?,
	perGraphFader: AudioFader?,
	player: AudioPlayer?,
	voiceInput: AudioDeviceInput?,
	maid: Maid.Maid?,
}): AudioGraphHandle
	local maid = args.maid or Maid.new()

	local self: AudioGraphHandle = setmetatable({
		_maid = maid,
		_instances = args.instances or {},
		_effectsByName = args.effectsByName or {},
		_categoryRegistry = assert(args.categoryRegistry, "No categoryRegistry"),
		_categoryName = args.categoryName or AudioServiceConstants.MASTER_CATEGORY_NAME,
		_categoryFader = args.categoryFader,
		_masterFader = args.masterFader,
		_perGraphFader = args.perGraphFader,
		_player = args.player,
		_voiceInput = args.voiceInput,
	}, AudioGraphHandle)

	self:_bindCategoryFaders()
	return self
end

function AudioGraphHandle._bindCategoryFaders(self: AudioGraphHandle): ()
	if self._masterFader then
		self._masterFader.Volume = self._categoryRegistry:GetVolume(AudioServiceConstants.MASTER_CATEGORY_NAME)
		self._maid._masterVolume = self._categoryRegistry:ObserveVolume(
			AudioServiceConstants.MASTER_CATEGORY_NAME,
			function(volume: number)
				if self._masterFader then
					self._masterFader.Volume = volume
				end
			end
		)
	end

	if self._categoryFader then
		self._categoryFader.Volume = self._categoryRegistry:GetVolume(self._categoryName)
		self._maid._categoryVolume = self._categoryRegistry:ObserveVolume(self._categoryName, function(volume: number)
			if self._categoryFader then
				self._categoryFader.Volume = volume
			end
		end)
	end
end

function AudioGraphHandle.Play(self: AudioGraphHandle): ()
	if self._player then
		self._player:Play()
	end
end

function AudioGraphHandle.Stop(self: AudioGraphHandle): ()
	if self._player then
		self._player:Stop()
	end
end

function AudioGraphHandle.SetVolume(self: AudioGraphHandle, volume: number): ()
	local clampedVolume = AudioServiceConfigUtils.clampVolume(volume)

	if self._perGraphFader then
		self._perGraphFader.Volume = clampedVolume
	elseif self._player then
		self._player.Volume = clampedVolume
	elseif self._voiceInput then
		self._voiceInput.Volume = clampedVolume
	end
end

function AudioGraphHandle.SetCategory(self: AudioGraphHandle, categoryName: string): ()
	assert(typeof(categoryName) == "string", "Category name must be a string")

	self._categoryName = categoryName
	self._maid._categoryVolume = nil

	if self._categoryFader then
		self._categoryFader.Volume = self._categoryRegistry:GetVolume(categoryName)
		self._maid._categoryVolume = self._categoryRegistry:ObserveVolume(categoryName, function(volume: number)
			if self._categoryFader then
				self._categoryFader.Volume = volume
			end
		end)
	end
end

function AudioGraphHandle.SetEffectBypass(self: AudioGraphHandle, effectName: string, bypass: boolean): ()
	assert(typeof(effectName) == "string", "Effect name must be a string")
	assert(typeof(bypass) == "boolean", "Bypass must be a boolean")

	local effect = self._effectsByName[effectName]
	assert(effect, string.format("Audio effect %q does not exist on this graph", effectName))

	local writableEffect = effect :: any
	writableEffect.Bypass = bypass
end

function AudioGraphHandle.GetInstance(self: AudioGraphHandle, kind: string): Instance?
	assert(typeof(kind) == "string", "Kind must be a string")

	return self._instances[kind]
end

function AudioGraphHandle.Destroy(self: AudioGraphHandle): ()
	self._maid:DoCleaning()
	table.clear(self._instances)
	table.clear(self._effectsByName)
	self._categoryFader = nil
	self._masterFader = nil
	self._perGraphFader = nil
	self._player = nil
	self._voiceInput = nil
end

return AudioGraphHandle
