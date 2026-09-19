--!strict
--[=[
	Shared public types for AudioService.

	@class AudioServiceTypes
]=]

local AudioServiceTypes = {}

export type CategoryConfig = {
	Name: string,
	Volume: number?,
}

export type EffectConfig = {
	Name: string,
	ClassName: string,
	Properties: { [string]: any }?,
	Bypass: boolean?,
}

export type EffectPresetConfig = {
	Name: string,
	Effects: { EffectConfig },
}

export type AssetConfig = {
	Name: string,
	Asset: any?,
	AudioContent: any?,
	Category: string?,
	Volume: number?,
	Looping: boolean?,
	PlaybackSpeed: number?,
	Effects: { EffectConfig }?,
	EffectPresets: { string }?,
}

export type EmitterConfig = {
	Name: string?,
	Properties: { [string]: any }?,
	DistanceAttenuation: { [number]: number }?,
	AngleAttenuation: { [number]: number }?,
}

export type ListenerConfig = {
	Name: string?,
	Parent: Instance?,
	Properties: { [string]: any }?,
	DistanceAttenuation: { [number]: number }?,
	AngleAttenuation: { [number]: number }?,
}

export type PlaybackConfig = {
	Name: string?,
	AssetName: string?,
	Asset: any?,
	AudioContent: any?,
	Category: string?,
	Volume: number?,
	Looping: boolean?,
	PlaybackSpeed: number?,
	AutoPlay: boolean?,
	Effects: { EffectConfig }?,
	EffectPresets: { string }?,
	Parent: Instance?,
	Emitter: AudioEmitter?,
}

export type VoiceInputConfig = {
	Name: string?,
	Player: Player?,
	Volume: number?,
	Muted: boolean?,
	AccessType: Enum.AccessModifierType?,
	UserIdAccessList: { number }?,
}

export type VoiceRouteConfig = {
	Name: string?,
	Input: AudioDeviceInput?,
	Output: AudioDeviceOutput?,
	Target: Instance?,
	Category: string?,
	Volume: number?,
	Effects: { EffectConfig }?,
	EffectPresets: { string }?,
}

export type AudioGraphHandle = {
	Play: (AudioGraphHandle) -> (),
	Stop: (AudioGraphHandle) -> (),
	SetVolume: (AudioGraphHandle, volume: number) -> (),
	SetCategory: (AudioGraphHandle, categoryName: string) -> (),
	SetEffectBypass: (AudioGraphHandle, effectName: string, bypass: boolean) -> (),
	GetInstance: (AudioGraphHandle, kind: string) -> Instance?,
	Destroy: (AudioGraphHandle) -> (),
}

return AudioServiceTypes
