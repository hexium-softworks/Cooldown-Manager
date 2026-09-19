--!strict
--[=[
	Client-side modern Roblox audio graph helpers.

	Generated objects are local and parented under SoundService.AudioService.
	This package creates no remotes and owns no game-specific routing policy.

	@class AudioServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Maid = require("Maid")
local ServiceBag = require("ServiceBag")

local AudioCategoryRegistry = require("AudioCategoryRegistry")
local AudioGraphBuilder = require("AudioGraphBuilder")
local AudioServiceConfigUtils = require("AudioServiceConfigUtils")
local AudioServiceConstants = require("AudioServiceConstants")
local AudioServiceTypes = require("AudioServiceTypes")

type ServiceBag = ServiceBag.ServiceBag
type CategoryConfig = AudioServiceTypes.CategoryConfig
type EffectPresetConfig = AudioServiceTypes.EffectPresetConfig
type AssetConfig = AudioServiceTypes.AssetConfig
type PlaybackConfig = AudioServiceTypes.PlaybackConfig
type EmitterConfig = AudioServiceTypes.EmitterConfig
type ListenerConfig = AudioServiceTypes.ListenerConfig
type VoiceInputConfig = AudioServiceTypes.VoiceInputConfig
type VoiceRouteConfig = AudioServiceTypes.VoiceRouteConfig
type AudioGraphHandle = AudioServiceTypes.AudioGraphHandle

local AudioServiceClient = {}
AudioServiceClient.ServiceName = "AudioServiceClient"

export type AudioServiceClient = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag,
		_maid: Maid.Maid,
		_rootFolder: Folder,
		_playbackFolder: Folder,
		_voiceFolder: Folder,
		_listenersFolder: Folder,
		_temporaryFolder: Folder,
		_categoryRegistry: AudioCategoryRegistry.AudioCategoryRegistry,
		_effectPresets: { [string]: EffectPresetConfig },
		_assets: { [string]: AssetConfig },
		_graphBuilder: AudioGraphBuilder.AudioGraphBuilder,
		_defaultOutput: AudioDeviceOutput?,
		_defaultListener: AudioListener?,
	},
	{} :: typeof({ __index = AudioServiceClient })
))

local function getOrCreateFolder(parent: Instance, name: string): Folder
	local child = parent:FindFirstChild(name)
	if child then
		assert(child:IsA("Folder"), string.format("%s must be a Folder", child:GetFullName()))
		return child :: Folder
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function createGraphFolder(parent: Instance, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
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

local function createWire(source: Instance, target: Instance, parent: Instance): Wire
	AudioServiceConfigUtils.assertCanCreateAudioClass("Wire")

	local wire = Instance.new("Wire")
	wire.Name = string.format("%s_to_%s", source.Name, target.Name)
	wire.SourceInstance = source
	wire.TargetInstance = target
	wire.Parent = parent
	return wire
end

local function applyAttenuation(instance: Instance, config: any): ()
	if config.DistanceAttenuation then
		(instance :: any):SetDistanceAttenuation(config.DistanceAttenuation)
	end

	if config.AngleAttenuation then
		(instance :: any):SetAngleAttenuation(config.AngleAttenuation)
	end
end

function AudioServiceClient.Init(self: AudioServiceClient, serviceBag: ServiceBag): ()
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._rootFolder = getOrCreateFolder(SoundService, AudioServiceConstants.SOUND_SERVICE_FOLDER_NAME)
	self._playbackFolder = getOrCreateFolder(self._rootFolder, AudioServiceConstants.PLAYBACK_FOLDER_NAME)
	self._voiceFolder = getOrCreateFolder(self._rootFolder, AudioServiceConstants.VOICE_FOLDER_NAME)
	self._listenersFolder = getOrCreateFolder(self._rootFolder, AudioServiceConstants.LISTENERS_FOLDER_NAME)
	self._temporaryFolder = getOrCreateFolder(self._rootFolder, AudioServiceConstants.TEMPORARY_FOLDER_NAME)

	self._categoryRegistry = self._maid:Add(AudioCategoryRegistry.new())
	self._effectPresets = {}
	self._assets = {}
	self._graphBuilder = AudioGraphBuilder.new({
		categoryRegistry = self._categoryRegistry,
		effectPresets = self._effectPresets,
		assets = self._assets,
	})
end

function AudioServiceClient.Start(_self: AudioServiceClient): () end

function AudioServiceClient.GetRootFolder(self: AudioServiceClient): Folder
	return self._rootFolder
end

function AudioServiceClient.RegisterCategories(self: AudioServiceClient, categories: { CategoryConfig }): ()
	self._categoryRegistry:RegisterCategories(categories)
end

function AudioServiceClient.RegisterEffects(self: AudioServiceClient, effectPresets: { EffectPresetConfig }): ()
	assert(typeof(effectPresets) == "table", "Effect presets must be a table")

	for _, presetConfig in effectPresets do
		AudioServiceConfigUtils.validateEffectPresetConfig(presetConfig)
		self._effectPresets[presetConfig.Name] = presetConfig
	end

	self._graphBuilder:SetEffectPresets(self._effectPresets)
end

function AudioServiceClient.RegisterAssets(self: AudioServiceClient, assets: { AssetConfig }): ()
	assert(typeof(assets) == "table", "Assets must be a table")

	for _, assetConfig in assets do
		AudioServiceConfigUtils.validateAssetConfig(assetConfig)
		self._assets[assetConfig.Name] = assetConfig
	end

	self._graphBuilder:SetAssets(self._assets)
end

function AudioServiceClient.GetCategoryVolume(self: AudioServiceClient, categoryName: string): number
	return self._categoryRegistry:GetVolume(categoryName)
end

function AudioServiceClient.SetCategoryVolume(self: AudioServiceClient, categoryName: string, volume: number): ()
	self._categoryRegistry:SetVolume(categoryName, volume)
end

function AudioServiceClient.GetCategoryVolumeChangedSignal(self: AudioServiceClient, categoryName: string): any
	return self._categoryRegistry:GetVolumeChangedSignal(categoryName)
end

function AudioServiceClient.ObserveCategoryVolume(
	self: AudioServiceClient,
	categoryName: string,
	callback: (number) -> ()
): any
	return self._categoryRegistry:ObserveVolume(categoryName, callback)
end

function AudioServiceClient.EnsureDefaultOutput(self: AudioServiceClient): AudioDeviceOutput
	if self._defaultOutput and self._defaultOutput.Parent then
		return self._defaultOutput
	end

	AudioServiceConfigUtils.assertCanCreateAudioClass("AudioDeviceOutput")

	local output = Instance.new("AudioDeviceOutput")
	output.Name = "DefaultOutput"
	output.Parent = self._listenersFolder
	self._maid._defaultOutput = output
	self._defaultOutput = output

	return output
end

function AudioServiceClient.CreateEmitter(
	self: AudioServiceClient,
	parentOrAttachment: Instance,
	config: EmitterConfig?
): AudioEmitter
	assert(typeof(parentOrAttachment) == "Instance", "Emitter parent must be an Instance")

	local emitterConfig: EmitterConfig = config or {}
	AudioServiceConfigUtils.validateEmitterConfig(emitterConfig)
	AudioServiceConfigUtils.assertCanCreateAudioClass("AudioEmitter")

	local emitter = Instance.new("AudioEmitter")
	emitter.Name = emitterConfig.Name or "AudioEmitter"
	emitter.Parent = parentOrAttachment
	applyProperties(emitter, emitterConfig.Properties)
	applyAttenuation(emitter, emitterConfig)

	return emitter
end

function AudioServiceClient.CreateListener(self: AudioServiceClient, config: ListenerConfig?): AudioListener
	local listenerConfig: ListenerConfig = config or {}
	AudioServiceConfigUtils.validateListenerConfig(listenerConfig)
	AudioServiceConfigUtils.assertCanCreateAudioClass("AudioListener")

	local parent = listenerConfig.Parent or Workspace.CurrentCamera or self._listenersFolder
	local listener = Instance.new("AudioListener")
	listener.Name = listenerConfig.Name or "DefaultListener"
	listener.Parent = parent
	applyProperties(listener, listenerConfig.Properties)
	applyAttenuation(listener, listenerConfig)

	local output = self:EnsureDefaultOutput()
	local listenerWire = createWire(listener, output, self._listenersFolder)

	self._maid._defaultListener = listener
	self._maid._defaultListenerWire = listenerWire
	self._defaultListener = listener

	return listener
end

function AudioServiceClient.EnsureDefaultListener(self: AudioServiceClient): AudioListener
	if self._defaultListener and self._defaultListener.Parent then
		return self._defaultListener
	end

	return self:CreateListener()
end

function AudioServiceClient.Play2D(self: AudioServiceClient, config: PlaybackConfig): AudioGraphHandle
	local output = self:EnsureDefaultOutput()
	local graphFolder = createGraphFolder(self._playbackFolder, config.Name or config.AssetName or "Playback")

	return self._graphBuilder:BuildPlayback2D(config, graphFolder, output)
end

function AudioServiceClient.Play3D(self: AudioServiceClient, config: PlaybackConfig): AudioGraphHandle
	self:EnsureDefaultListener()

	local graphFolder = createGraphFolder(self._playbackFolder, config.Name or config.AssetName or "Playback3D")
	local emitter = config.Emitter
	local ownedEmitter: AudioEmitter? = nil
	if not emitter then
		assert(config.Parent, "Play3D config requires Parent or Emitter")
		emitter = self:CreateEmitter(config.Parent, {
			Name = "AudioEmitter",
		})
		ownedEmitter = emitter
	end

	return self._graphBuilder:BuildPlayback3D(config, graphFolder, emitter :: AudioEmitter, ownedEmitter)
end

function AudioServiceClient.CreateVoiceInput(self: AudioServiceClient, config: VoiceInputConfig?): AudioDeviceInput
	local voiceConfig: VoiceInputConfig = config or {}
	AudioServiceConfigUtils.validateVoiceInputConfig(voiceConfig)
	AudioServiceConfigUtils.assertCanCreateAudioClass("AudioDeviceInput")

	local input = Instance.new("AudioDeviceInput")
	input.Name = voiceConfig.Name or "LocalVoiceInput"
	input.Player = voiceConfig.Player or Players.LocalPlayer
	input.Volume = AudioServiceConfigUtils.clampVolume(voiceConfig.Volume)

	if voiceConfig.Muted ~= nil then
		input.Muted = voiceConfig.Muted
	end

	if voiceConfig.AccessType ~= nil then
		input.AccessType = voiceConfig.AccessType
	end

	if voiceConfig.UserIdAccessList ~= nil then
		input:SetUserIdAccessList(voiceConfig.UserIdAccessList)
	end

	input.Parent = self._voiceFolder
	return input
end

function AudioServiceClient.CreateVoiceRoute(self: AudioServiceClient, config: VoiceRouteConfig): AudioGraphHandle
	AudioServiceConfigUtils.validateVoiceRouteConfig(config)

	local input = config.Input
	local ownedInput: AudioDeviceInput? = nil
	if not input then
		input = self:CreateVoiceInput({
			Name = config.Name and string.format("%sInput", config.Name) or "VoiceInput",
			Volume = 1,
		})
		ownedInput = input
	end

	local target = config.Target or config.Output or self:EnsureDefaultOutput()
	local graphFolder = createGraphFolder(self._voiceFolder, config.Name or "VoiceRoute")

	return self._graphBuilder:BuildVoiceRoute(config, graphFolder, input :: AudioDeviceInput, target, ownedInput)
end

function AudioServiceClient.Destroy(self: AudioServiceClient): ()
	self._maid:DoCleaning()
	table.clear(self._effectPresets)
	table.clear(self._assets)
	self._defaultOutput = nil
	self._defaultListener = nil
end

return AudioServiceClient
