# AudioService

A game-agnostic Nevermore package for Roblox's modern Audio API.

AudioService builds graphs from `AudioPlayer`, `AudioEmitter`,
`AudioListener`, `AudioDeviceInput`, `AudioDeviceOutput`, audio effects, and
`Wire`. It does not create or manage legacy `Sound`, `SoundGroup`, or
`SoundEffect` instances.

## Installation

```sh
pnpm add @hexium-softworks/audioservice
```

This package expects a Roblox runtime with the modern Audio API enabled.

## Model

AudioService treats every playback or voice path as a graph:

```txt
AudioPlayer -> GraphVolume -> MasterVolume -> CategoryVolume -> Effects -> Output
AudioPlayer -> GraphVolume -> MasterVolume -> CategoryVolume -> Effects -> Emitter
AudioDeviceInput -> GraphVolume -> MasterVolume -> CategoryVolume -> Effects -> Output/Emitter
AudioListener -> AudioDeviceOutput
```

`Master` is built in. Games can add categories such as `Music`,
`SoundEffects`, `Voice`, `Ambience`, or `Alarms`, then wire their own settings UI
to `SetCategoryVolume()`.

The package creates no remotes, owns no player permission policy, and persists
no settings. Game code decides what should play, who can speak on a channel, and
where user settings are stored.

## Server Usage

Server code can register shared defaults and keep a canonical registry:

```lua
local AudioService = require("AudioService")

local audioService = serviceBag:GetService(AudioService)

audioService:RegisterCategories({
	{ Name = "Music", Volume = 0.8 },
	{ Name = "SoundEffects", Volume = 1 },
	{ Name = "Voice", Volume = 1 },
	{ Name = "Alarms", Volume = 0.9 },
})

audioService:RegisterEffects({
	{
		Name = "Radio",
		Effects = {
			{
				Name = "RadioEQ",
				ClassName = "AudioEqualizer",
				Properties = {
					LowGain = -18,
					MidGain = 2,
					HighGain = -10,
					MidRange = NumberRange.new(300, 3400),
				},
			},
			{
				Name = "RadioCompressor",
				ClassName = "AudioCompressor",
				Properties = {
					Threshold = -18,
					Ratio = 4,
				},
			},
		},
	},
})

audioService:RegisterAssets({
	{
		Name = "AlarmLoop",
		Asset = "rbxassetid://123456789",
		Category = "Alarms",
		Looping = true,
		Volume = 0.7,
		EffectPresets = { "Radio" },
	},
})
```

## Client Usage

Clients own the actual local graph instances:

```lua
local AudioServiceClient = require("AudioServiceClient")

local audioClient = serviceBag:GetService(AudioServiceClient)

audioClient:RegisterCategories({
	{ Name = "Music", Volume = 0.8 },
	{ Name = "SoundEffects", Volume = 1 },
	{ Name = "Voice", Volume = 1 },
})

local handle = audioClient:Play2D({
	Name = "MenuMusic",
	Asset = "rbxassetid://123456789",
	Category = "Music",
	Looping = true,
	Volume = 0.5,
})

handle:SetVolume(0.25)
handle:Stop()
handle:Destroy()
```

Play positional audio from an existing world object:

```lua
audioClient:Play3D({
	Name = "GeneratorHum",
	Asset = "rbxassetid://987654321",
	Category = "Ambience",
	Looping = true,
	Parent = workspace.Generator,
})
```

Create local voice routes:

```lua
audioClient:SetCategoryVolume("Voice", 0.75)

local radioLikeVoice = audioClient:CreateVoiceRoute({
	Name = "FilteredVoice",
	Category = "Voice",
	Target = audioClient:EnsureDefaultOutput(),
	Effects = {
		{
			Name = "VoiceEQ",
			ClassName = "AudioEqualizer",
			Properties = {
				LowGain = -12,
				MidGain = 2,
				HighGain = -6,
				MidRange = NumberRange.new(300, 3400),
			},
		},
	},
})

radioLikeVoice:Destroy()
```

## 3D Audio And Distant Effects

The package does not hard-code gameplay concepts like guns, explosions, alarms,
or radios. Instead, define reusable effect presets and apply them to any 3D
playback graph that needs that sound profile.

```lua
audioClient:RegisterCategories({
	{ Name = "Weapons", Volume = 1 },
	{ Name = "Explosions", Volume = 1 },
})

audioClient:RegisterEffects({
	{
		Name = "DistantMuffle",
		Effects = {
			{
				Name = "DistantEQ",
				ClassName = "AudioEqualizer",
				Properties = {
					LowGain = 1,
					MidGain = -4,
					HighGain = -18,
					MidRange = NumberRange.new(400, 3000),
				},
			},
			{
				Name = "DistantCompressor",
				ClassName = "AudioCompressor",
				Properties = {
					Threshold = -14,
					Ratio = 3,
					Attack = 0.02,
					Release = 0.25,
				},
			},
		},
	},
})

local shot = audioClient:Play3D({
	Name = "FarRifleShot",
	Asset = "rbxassetid://123456789",
	Category = "Weapons",
	Volume = 0.8,
	Parent = workspace.DistantFightOrigin,
	EffectPresets = { "DistantMuffle" },
})

shot:SetEffectBypass("DistantEQ", false)
```

For tighter control over distance falloff, create the emitter yourself and pass
it into `Play3D()`:

```lua
local emitter = audioClient:CreateEmitter(workspace.ExplosionOrigin, {
	Name = "ExplosionEmitter",
	DistanceAttenuation = {
		[0] = 1,
		[200] = 0.65,
		[600] = 0.2,
		[1200] = 0,
	},
})

audioClient:Play3D({
	Name = "FarExplosion",
	Asset = "rbxassetid://987654321",
	Category = "Explosions",
	Volume = 1,
	Emitter = emitter,
	EffectPresets = { "DistantMuffle" },
})
```

## API Reference

Server `AudioService`:

| Method | Description |
| --- | --- |
| `RegisterCategories(categories)` | Registers category defaults. |
| `RegisterEffects(effectPresets)` | Registers reusable ordered effect chains. |
| `RegisterAssets(assets)` | Registers named asset defaults. |
| `GetCategoryVolume(categoryName)` | Returns a category volume, defaulting to `1`. |
| `SetCategoryVolume(categoryName, volume)` | Sets a clamped `0..1` category volume. |
| `GetCategoryVolumeChangedSignal(categoryName)` | Returns the volume changed signal. |

Client `AudioServiceClient`:

| Method | Description |
| --- | --- |
| `RegisterCategories(categories)` | Registers local category defaults. |
| `RegisterEffects(effectPresets)` | Registers local reusable effect chains. |
| `RegisterAssets(assets)` | Registers local named assets. |
| `SetCategoryVolume(categoryName, volume)` | Sets local category volume. |
| `ObserveCategoryVolume(categoryName, callback)` | Calls immediately and whenever the volume changes. |
| `Play2D(config)` | Builds and starts a 2D `AudioPlayer` graph. |
| `Play3D(config)` | Builds and starts a 3D `AudioPlayer` to `AudioEmitter` graph. |
| `CreateEmitter(parent, config?)` | Creates an `AudioEmitter` on a world instance. |
| `CreateListener(config?)` | Creates an `AudioListener` and wires it to output. |
| `EnsureDefaultOutput()` | Returns the local default `AudioDeviceOutput`. |
| `CreateVoiceInput(config?)` | Creates an `AudioDeviceInput` for the local player by default. |
| `CreateVoiceRoute(config)` | Wires voice input through category/effects to an output or emitter. |

## Supported Effects

`AudioFader`, `AudioEqualizer`, `AudioCompressor`, `AudioReverb`,
`AudioChorus`, `AudioDistortion`, `AudioEcho`, `AudioFlanger`,
`AudioPitchShifter`, `AudioTremolo`, `AudioFilter`, `AudioLimiter`, and
`AudioGate`.

Effects are applied in the order they appear. Unknown top-level config fields
are rejected, while effect `Properties` are passed to the Roblox instance so the
engine remains the source of truth for property support.
