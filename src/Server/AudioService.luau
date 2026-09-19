--!strict
--[=[
	Server-owned registry for modern Roblox audio defaults.

	This service intentionally exposes no remotes. Games can use it to register
	shared defaults, but clients own local playback graphs and settings.

	@class AudioService
]=]

local require = require(script.Parent.loader).load(script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Maid = require("Maid")
local ServiceBag = require("ServiceBag")

local AudioCategoryRegistry = require("AudioCategoryRegistry")
local AudioServiceConfigUtils = require("AudioServiceConfigUtils")
local AudioServiceConstants = require("AudioServiceConstants")
local AudioServiceTypes = require("AudioServiceTypes")

type ServiceBag = ServiceBag.ServiceBag
type CategoryConfig = AudioServiceTypes.CategoryConfig
type EffectPresetConfig = AudioServiceTypes.EffectPresetConfig
type AssetConfig = AudioServiceTypes.AssetConfig

local AudioService = {}
AudioService.ServiceName = "AudioService"

export type AudioService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag,
		_maid: Maid.Maid,
		_rootFolder: Folder,
		_categoryRegistry: AudioCategoryRegistry.AudioCategoryRegistry,
		_effectPresets: { [string]: EffectPresetConfig },
		_assets: { [string]: AssetConfig },
	},
	{} :: typeof({ __index = AudioService })
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

function AudioService.Init(self: AudioService, serviceBag: ServiceBag): ()
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()
	self._rootFolder = getOrCreateFolder(ReplicatedStorage, AudioServiceConstants.ROOT_FOLDER_NAME)
	self._categoryRegistry = self._maid:Add(AudioCategoryRegistry.new())
	self._effectPresets = {}
	self._assets = {}

	getOrCreateFolder(self._rootFolder, AudioServiceConstants.CATEGORIES_FOLDER_NAME)
	getOrCreateFolder(self._rootFolder, AudioServiceConstants.ASSETS_FOLDER_NAME)
	getOrCreateFolder(self._rootFolder, AudioServiceConstants.EFFECTS_FOLDER_NAME)
end

function AudioService.Start(_self: AudioService): () end

function AudioService.GetRootFolder(self: AudioService): Folder
	return self._rootFolder
end

function AudioService.RegisterCategories(self: AudioService, categories: { CategoryConfig }): ()
	self._categoryRegistry:RegisterCategories(categories)

	local categoriesFolder = getOrCreateFolder(self._rootFolder, AudioServiceConstants.CATEGORIES_FOLDER_NAME)
	for _, categoryConfig in categories do
		local folder = getOrCreateFolder(categoriesFolder, categoryConfig.Name)
		folder:SetAttribute("Volume", self._categoryRegistry:GetVolume(categoryConfig.Name))
	end
end

function AudioService.RegisterEffects(self: AudioService, effectPresets: { EffectPresetConfig }): ()
	assert(typeof(effectPresets) == "table", "Effect presets must be a table")

	local effectsFolder = getOrCreateFolder(self._rootFolder, AudioServiceConstants.EFFECTS_FOLDER_NAME)
	for _, presetConfig in effectPresets do
		AudioServiceConfigUtils.validateEffectPresetConfig(presetConfig)
		self._effectPresets[presetConfig.Name] = presetConfig

		getOrCreateFolder(effectsFolder, presetConfig.Name)
	end
end

function AudioService.RegisterAssets(self: AudioService, assets: { AssetConfig }): ()
	assert(typeof(assets) == "table", "Assets must be a table")

	local assetsFolder = getOrCreateFolder(self._rootFolder, AudioServiceConstants.ASSETS_FOLDER_NAME)
	for _, assetConfig in assets do
		AudioServiceConfigUtils.validateAssetConfig(assetConfig)
		self._assets[assetConfig.Name] = assetConfig

		local folder = getOrCreateFolder(assetsFolder, assetConfig.Name)
		folder:SetAttribute("Category", assetConfig.Category)
		folder:SetAttribute("Volume", assetConfig.Volume)
	end
end

function AudioService.GetCategoryVolume(self: AudioService, categoryName: string): number
	return self._categoryRegistry:GetVolume(categoryName)
end

function AudioService.SetCategoryVolume(self: AudioService, categoryName: string, volume: number): ()
	self._categoryRegistry:SetVolume(categoryName, volume)

	local categoriesFolder = getOrCreateFolder(self._rootFolder, AudioServiceConstants.CATEGORIES_FOLDER_NAME)
	local categoryFolder = getOrCreateFolder(categoriesFolder, categoryName)
	categoryFolder:SetAttribute("Volume", self._categoryRegistry:GetVolume(categoryName))
end

function AudioService.GetCategoryVolumeChangedSignal(self: AudioService, categoryName: string): any
	return self._categoryRegistry:GetVolumeChangedSignal(categoryName)
end

function AudioService.GetAssetConfig(self: AudioService, assetName: string): AssetConfig?
	assert(typeof(assetName) == "string", "Asset name must be a string")

	return self._assets[assetName]
end

function AudioService.GetEffectPresetConfig(self: AudioService, presetName: string): EffectPresetConfig?
	assert(typeof(presetName) == "string", "Preset name must be a string")

	return self._effectPresets[presetName]
end

function AudioService.Destroy(self: AudioService): ()
	self._maid:DoCleaning()
	table.clear(self._assets)
	table.clear(self._effectPresets)
end

return AudioService
