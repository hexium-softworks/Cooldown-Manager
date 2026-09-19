--!strict
--[=[
	Builds modern Roblox audio graphs from typed configs.

	@class AudioGraphBuilder
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")

local AudioGraphHandle = require("AudioGraphHandle")
local AudioServiceConfigUtils = require("AudioServiceConfigUtils")
local AudioServiceConstants = require("AudioServiceConstants")
local AudioServiceTypes = require("AudioServiceTypes")

type AssetConfig = AudioServiceTypes.AssetConfig
type EffectConfig = AudioServiceTypes.EffectConfig
type EffectPresetConfig = AudioServiceTypes.EffectPresetConfig
type PlaybackConfig = AudioServiceTypes.PlaybackConfig
type VoiceRouteConfig = AudioServiceTypes.VoiceRouteConfig

local AudioGraphBuilder = {}
AudioGraphBuilder.ClassName = "AudioGraphBuilder"
AudioGraphBuilder.__index = AudioGraphBuilder

export type AudioGraphBuilder = typeof(setmetatable(
	{} :: {
		_categoryRegistry: any,
		_effectPresets: { [string]: EffectPresetConfig },
		_assets: { [string]: AssetConfig },
	},
	AudioGraphBuilder
))

local function wire(source: Instance, target: Instance, parent: Instance, maid: Maid.Maid): Wire
	AudioServiceConfigUtils.assertCanCreateAudioClass("Wire")

	local wireInstance = Instance.new("Wire")
	wireInstance.Name = string.format("%s_to_%s", source.Name, target.Name)
	wireInstance.SourceInstance = source
	wireInstance.TargetInstance = target
	wireInstance.Parent = parent
	maid:GiveTask(wireInstance)

	return wireInstance
end

local function createAudioInstance(className: string, name: string, parent: Instance, maid: Maid.Maid): Instance
	AudioServiceConfigUtils.assertCanCreateAudioClass(className)

	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	maid:GiveTask(instance)
	return instance
end

local function applyProperties(instance: Instance, properties: { [string]: any }?): ()
	if not properties then
		return
	end

	local writableInstance = instance :: any
	for propertyName, value in properties do
		writableInstance[propertyName] = value
	end
end

local function createFader(name: string, volume: number, parent: Instance, maid: Maid.Maid): AudioFader
	local fader = createAudioInstance("AudioFader", name, parent, maid) :: AudioFader
	fader.Volume = AudioServiceConfigUtils.clampVolume(volume)
	return fader
end

function AudioGraphBuilder.new(args: {
	categoryRegistry: any,
	effectPresets: { [string]: EffectPresetConfig }?,
	assets: { [string]: AssetConfig }?,
}): AudioGraphBuilder
	local self: AudioGraphBuilder = setmetatable({
		_categoryRegistry = assert(args.categoryRegistry, "No categoryRegistry"),
		_effectPresets = args.effectPresets or {},
		_assets = args.assets or {},
	}, AudioGraphBuilder)

	return self
end

function AudioGraphBuilder.SetEffectPresets(
	self: AudioGraphBuilder,
	effectPresets: { [string]: EffectPresetConfig }
): ()
	self._effectPresets = effectPresets
end

function AudioGraphBuilder.SetAssets(self: AudioGraphBuilder, assets: { [string]: AssetConfig }): ()
	self._assets = assets
end

function AudioGraphBuilder._resolveEffectConfigs(
	self: AudioGraphBuilder,
	effects: { EffectConfig }?,
	effectPresetNames: { string }?
): { EffectConfig }
	local resolved = {}

	if effectPresetNames then
		for _, presetName in effectPresetNames do
			local preset = self._effectPresets[presetName]
			assert(preset, string.format("Audio effect preset %q is not registered", presetName))

			for _, effectConfig in preset.Effects do
				table.insert(resolved, effectConfig)
			end
		end
	end

	if effects then
		for _, effectConfig in effects do
			table.insert(resolved, effectConfig)
		end
	end

	return resolved
end

function AudioGraphBuilder._buildCommonChain(
	self: AudioGraphBuilder,
	args: {
		source: Instance,
		target: Instance,
		parent: Instance,
		categoryName: string,
		volume: number,
		effects: { EffectConfig }?,
		effectPresetNames: { string }?,
		maid: Maid.Maid,
		instances: { [string]: Instance },
		effectsByName: { [string]: Instance },
	}
): (AudioFader, AudioFader?, AudioFader?)
	local current = args.source

	local perGraphFader = createFader("GraphVolume", args.volume, args.parent, args.maid)
	args.instances.GraphVolume = perGraphFader
	wire(current, perGraphFader, args.parent, args.maid)
	current = perGraphFader

	local masterFader = createFader(
		"MasterVolume",
		self._categoryRegistry:GetVolume(AudioServiceConstants.MASTER_CATEGORY_NAME),
		args.parent,
		args.maid
	)
	args.instances.MasterVolume = masterFader
	wire(current, masterFader, args.parent, args.maid)
	current = masterFader

	local categoryFader: AudioFader? = nil
	if args.categoryName ~= AudioServiceConstants.MASTER_CATEGORY_NAME then
		categoryFader = createFader(
			string.format("%sVolume", args.categoryName),
			self._categoryRegistry:GetVolume(args.categoryName),
			args.parent,
			args.maid
		)
		args.instances.CategoryVolume = categoryFader
		wire(current, categoryFader, args.parent, args.maid)
		current = categoryFader
	end

	for _, effectConfig in self:_resolveEffectConfigs(args.effects, args.effectPresetNames) do
		local effect = createAudioInstance(effectConfig.ClassName, effectConfig.Name, args.parent, args.maid)
		applyProperties(effect, effectConfig.Properties)

		if effectConfig.Bypass ~= nil then
			(effect :: any).Bypass = effectConfig.Bypass
		end

		args.effectsByName[effectConfig.Name] = effect
		args.instances[effectConfig.Name] = effect
		wire(current, effect, args.parent, args.maid)
		current = effect
	end

	wire(current, args.target, args.parent, args.maid)
	return perGraphFader, masterFader, categoryFader
end

function AudioGraphBuilder.BuildPlayback2D(
	self: AudioGraphBuilder,
	config: PlaybackConfig,
	parent: Instance,
	output: AudioDeviceOutput
): AudioGraphHandle.AudioGraphHandle
	AudioServiceConfigUtils.validatePlaybackConfig(config)

	local assetConfig = config.AssetName and self._assets[config.AssetName] or nil
	assert(config.AssetName == nil or assetConfig ~= nil, string.format("Audio asset %q is not registered", config.AssetName))

	local mergedConfig: any = {}
	if assetConfig then
		for key, value in assetConfig :: any do
			mergedConfig[key] = value
		end
	end

	for key, value in config :: any do
		if value ~= nil then
			mergedConfig[key] = value
		end
	end

	local maid = Maid.new()
	maid:GiveTask(parent)
	local instances = {}
	local effectsByName = {}

	local player = createAudioInstance("AudioPlayer", mergedConfig.Name or "AudioPlayer", parent, maid) :: AudioPlayer
	player.Volume = 1

	if mergedConfig.Asset ~= nil then
		(player :: any).Asset = mergedConfig.Asset
	elseif mergedConfig.AudioContent ~= nil then
		(player :: any).AudioContent = mergedConfig.AudioContent
	end

	if mergedConfig.Looping ~= nil then
		player.Looping = mergedConfig.Looping
	end

	if mergedConfig.PlaybackSpeed ~= nil then
		player.PlaybackSpeed = mergedConfig.PlaybackSpeed
	end

	instances.Player = player
	instances.Output = output

	local categoryName = mergedConfig.Category or AudioServiceConstants.MASTER_CATEGORY_NAME
	local perGraphFader, masterFader, categoryFader = self:_buildCommonChain({
		source = player,
		target = output,
		parent = parent,
		categoryName = categoryName,
		volume = mergedConfig.Volume or AudioServiceConstants.DEFAULT_CATEGORY_VOLUME,
		effects = mergedConfig.Effects,
		effectPresetNames = mergedConfig.EffectPresets,
		maid = maid,
		instances = instances,
		effectsByName = effectsByName,
	})

	local handle = AudioGraphHandle.new({
		instances = instances,
		effectsByName = effectsByName,
		categoryRegistry = self._categoryRegistry,
		categoryName = categoryName,
		categoryFader = categoryFader,
		masterFader = masterFader,
		perGraphFader = perGraphFader,
		player = player,
		maid = maid,
	})

	if mergedConfig.AutoPlay ~= false then
		handle:Play()
	end

	return handle
end

function AudioGraphBuilder.BuildPlayback3D(
	self: AudioGraphBuilder,
	config: PlaybackConfig,
	parent: Instance,
	emitter: AudioEmitter,
	ownedEmitter: AudioEmitter?
): AudioGraphHandle.AudioGraphHandle
	local handle = self:BuildPlayback2D(config, parent, emitter :: any)
	handle._instances.Emitter = emitter

	if ownedEmitter then
		handle._maid:GiveTask(ownedEmitter)
	end

	return handle
end

function AudioGraphBuilder.BuildVoiceRoute(
	self: AudioGraphBuilder,
	config: VoiceRouteConfig,
	parent: Instance,
	input: AudioDeviceInput,
	target: Instance,
	ownedInput: AudioDeviceInput?
): AudioGraphHandle.AudioGraphHandle
	AudioServiceConfigUtils.validateVoiceRouteConfig(config)

	local maid = Maid.new()
	maid:GiveTask(parent)
	local instances = {
		Input = input,
		Target = target,
	}
	local effectsByName = {}
	local categoryName = config.Category or "Voice"

	local perGraphFader, masterFader, categoryFader = self:_buildCommonChain({
		source = input,
		target = target,
		parent = parent,
		categoryName = categoryName,
		volume = config.Volume or AudioServiceConstants.DEFAULT_CATEGORY_VOLUME,
		effects = config.Effects,
		effectPresetNames = config.EffectPresets,
		maid = maid,
		instances = instances,
		effectsByName = effectsByName,
	})

	local handle = AudioGraphHandle.new({
		instances = instances,
		effectsByName = effectsByName,
		categoryRegistry = self._categoryRegistry,
		categoryName = categoryName,
		categoryFader = categoryFader,
		masterFader = masterFader,
		perGraphFader = perGraphFader,
		voiceInput = input,
		maid = maid,
	})

	if ownedInput then
		handle._maid:GiveTask(ownedInput)
	end

	return handle
end

return AudioGraphBuilder
