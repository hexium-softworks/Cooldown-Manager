# AudioService

A game-agnostic Nevermore package for Roblox's modern Audio API.

AudioService builds local audio graphs from `AudioPlayer`, `AudioEmitter`,
`AudioListener`, `AudioDeviceInput`, `AudioDeviceOutput`, audio effects, and
`Wire`. It does not create or manage legacy `Sound`, `SoundGroup`, or
`SoundEffect` instances.

## Installation

```sh
pnpm add @hexium-softworks/audioservice
```

This package expects a Roblox runtime with the modern Audio API enabled.

## Nevermore Usage

`AudioService` and `AudioServiceClient` are Nevermore services. Require them
through `ServiceBag`, not by calling methods directly on the module table.

Server:

```lua
local require = require(script.Parent.loader).load(script)

local AudioService = require("AudioService")

function GameAudioService:Init(serviceBag)
	self._audioService = serviceBag:GetService(AudioService)
end

function GameAudioService:Start()
	self._audioService:RegisterCategories({
		{ Name = "Music", Volume = 0.8 },
		{ Name = "SoundEffects", Volume = 1 },
		{ Name = "Voice", Volume = 1 },
		{ Name = "Ambience", Volume = 1 },
	})
end
```

Client:

```lua
local require = require(script.Parent.loader).load(script)

local AudioServiceClient = require("AudioServiceClient")

function GameAudioClient:Init(serviceBag)
	self._audioClient = serviceBag:GetService(AudioServiceClient)
end

function GameAudioClient:Start()
	self._audioClient:RegisterCategories({
		{ Name = "Music", Volume = 0.8 },
		{ Name = "SoundEffects", Volume = 1 },
		{ Name = "Voice", Volume = 1 },
		{ Name = "Ambience", Volume = 1 },
	})
end
```

Keep `Init` lightweight and non-yielding. Register static definitions in
`Start`, or from another game service after the `ServiceBag` has initialized.

## Model

AudioService treats every playback or voice path as a graph:

```txt
AudioPlayer -> GraphVolume -> MasterVolume -> CategoryVolume -> Effects -> Output
AudioPlayer -> GraphVolume -> MasterVolume -> CategoryVolume -> Effects -> Emitter
AudioDeviceInput -> GraphVolume -> MasterVolume -> CategoryVolume -> Effects -> Output/Emitter
AudioListener -> AudioDeviceOutput
```

`Master` is built in. Games can add categories such as `Music`,
`SoundEffects`, `Voice`, `Ambience`, `Weapons`, `Explosions`, or `Alarms`, then
wire their settings UI to `SetCategoryVolume()`.

The package creates no remotes, owns no player permission policy, and persists
no settings. Game code decides what should play, who can speak on a channel, and
where user settings are stored.

## Shared Definitions

Most games will define categories, assets, and effect presets in one game-owned
module, then register the relevant definitions on the server and client. This
keeps the package pure while giving every game a single audio vocabulary.

```lua
return {
	Categories = {
		{ Name = "Music", Volume = 0.8 },
		{ Name = "SoundEffects", Volume = 1 },
		{ Name = "Voice", Volume = 1 },
		{ Name = "Weapons", Volume = 1 },
		{ Name = "Alarms", Volume = 1 },
	},

	Effects = {
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
	},

	Assets = {
		{
			Name = "AlarmLoop",
			Asset = "rbxassetid://123456789",
			Category = "Alarms",
			Looping = true,
			Volume = 0.7,
			EffectPresets = { "Radio" },
		},
	},
}
```

Register definitions where they are needed:

```lua
audioService:RegisterCategories(AudioDefinitions.Categories)
audioService:RegisterEffects(AudioDefinitions.Effects)
audioService:RegisterAssets(AudioDefinitions.Assets)

audioClient:RegisterCategories(AudioDefinitions.Categories)
audioClient:RegisterEffects(AudioDefinitions.Effects)
audioClient:RegisterAssets(AudioDefinitions.Assets)
```

## Basic Examples

Play one local UI or gameplay sound:

```lua
local click = audioClient:Play2D({
	Name = "ButtonClick",
	Asset = "rbxassetid://123456789",
	Category = "SoundEffects",
	Volume = 0.6,
})

click:Destroy()
```

Play looping music with a Maid-compatible handle:

```lua
local Maid = require("Maid")

local maid = Maid.new()

local music = maid:Add(audioClient:Play2D({
	Name = "RoundMusic",
	Asset = "rbxassetid://234567891",
	Category = "Music",
	Looping = true,
	Volume = 0.4,
}))

music:SetVolume(0.25)
music:Stop()
music:Play()
```

Play positional ambience from an existing world object:

```lua
maid:GiveTask(audioClient:Play3D({
	Name = "GeneratorHum",
	Asset = "rbxassetid://987654321",
	Category = "Ambience",
	Looping = true,
	Parent = workspace.Generator,
}))
```

## Lifetime Management

Playback and voice APIs return audio handles, not Maids. This keeps the useful
controls available while still fitting Nevermore cleanup patterns. Every handle
implements `Destroy()`, so it can be passed directly to `Maid:Add()` or
`Maid:GiveTask()`.

Use `Maid:Add()` when you still need to control the sound:

```lua
local music = maid:Add(audioClient:Play2D({
	Name = "RoundMusic",
	Asset = "rbxassetid://234567891",
	Category = "Music",
	Looping = true,
}))

music:SetVolume(0.5)
```

Use `Maid:GiveTask()` when ownership is all you need:

```lua
maid:GiveTask(audioClient:Play3D({
	Name = "WindLoop",
	Asset = "rbxassetid://345678912",
	Category = "Ambience",
	Looping = true,
	Parent = workspace.Cliff,
}))
```

For short one-shot sounds, store the handle only if you need to stop, fade, or
destroy it manually. For looping music, ambience, emitters, and voice routes,
own the handle with a Maid. Destroying a handle cleans up the generated audio
instances, wires, category observers, and temporary graph folders.

## Intermediate Examples

Connect a settings menu to category volumes:

```lua
local connection = audioClient:ObserveCategoryVolume("Music", function(volume)
	musicSlider.Value = volume
end)

maid:GiveTask(connection)

musicSlider.Changed:Connect(function(volume)
	audioClient:SetCategoryVolume("Music", volume)
end)
```

Use a named asset with defaults:

```lua
audioClient:RegisterAssets({
	{
		Name = "RoundAlarm",
		Asset = "rbxassetid://345678912",
		Category = "Alarms",
		Looping = true,
		Volume = 0.75,
		EffectPresets = { "Radio" },
	},
})

local alarm = audioClient:Play2D({
	AssetName = "RoundAlarm",
})

alarm:SetVolume(0.5)
```

Create a custom 3D emitter with explicit distance falloff:

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
})
```

## Advanced Examples

Build reusable distant-combat effects without hard-coding combat into the
package:

```lua
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

Route local voice through a generic effect chain:

```lua
audioClient:SetCategoryVolume("Voice", 0.75)

local filteredVoice = audioClient:CreateVoiceRoute({
	Name = "FilteredVoice",
	Category = "Voice",
	Target = audioClient:EnsureDefaultOutput(),
	EffectPresets = { "Radio" },
})

maid:GiveTask(filteredVoice)
```

Apply per-playback effects when a full preset is not worth registering:

```lua
local underwaterAmbience = audioClient:Play2D({
	Name = "UnderwaterAmbience",
	Asset = "rbxassetid://456789123",
	Category = "Ambience",
	Looping = true,
	Effects = {
		{
			Name = "UnderwaterEQ",
			ClassName = "AudioEqualizer",
			Properties = {
				LowGain = 4,
				MidGain = -8,
				HighGain = -24,
			},
		},
		{
			Name = "UnderwaterReverb",
			ClassName = "AudioReverb",
			Properties = {
				WetLevel = -8,
				DryLevel = -2,
			},
		},
	},
})

underwaterAmbience:SetEffectBypass("UnderwaterReverb", true)
```

## Common Use Cases

- Settings menus: store player preferences in your game, then call
  `SetCategoryVolume()` on the client.
- Music: use `Play2D()` with the `Music` category and own the Maid-compatible
  handle for as long as the music should live.
- UI and SFX: use `Play2D()` with short-lived handles, or named assets for common
  cues.
- World ambience: use `Play3D()` with a world parent and optional custom emitter
  attenuation.
- Weapons and explosions: use `Play3D()` plus reusable effect presets for distant
  or muffled variants.
- Voice chat processing: create local `AudioDeviceInput` routes with
  `CreateVoiceRoute()`. The game owns permissions, channels, and policy.

## API Reference

Server `AudioService`:

| Method | Description |
| --- | --- |
| `GetRootFolder()` | Returns the replicated audio registry folder. |
| `RegisterCategories(categories)` | Registers category defaults. |
| `RegisterEffects(effectPresets)` | Registers reusable ordered effect chains. |
| `RegisterAssets(assets)` | Registers named asset defaults. |
| `GetCategoryVolume(categoryName)` | Returns a category volume, defaulting to `1`. |
| `SetCategoryVolume(categoryName, volume)` | Sets a clamped `0..1` category volume. |
| `GetCategoryVolumeChangedSignal(categoryName)` | Returns the volume changed signal. |
| `GetAssetConfig(assetName)` | Returns a registered asset config. |
| `GetEffectPresetConfig(presetName)` | Returns a registered effect preset config. |

Client `AudioServiceClient`:

| Method | Description |
| --- | --- |
| `GetRootFolder()` | Returns the local `SoundService.AudioService` folder. |
| `RegisterCategories(categories)` | Registers local category defaults. |
| `RegisterEffects(effectPresets)` | Registers local reusable effect chains. |
| `RegisterAssets(assets)` | Registers local named assets. |
| `GetCategoryVolume(categoryName)` | Returns the local category volume. |
| `SetCategoryVolume(categoryName, volume)` | Sets local category volume. |
| `GetCategoryVolumeChangedSignal(categoryName)` | Returns the local volume changed signal. |
| `ObserveCategoryVolume(categoryName, callback)` | Calls immediately and whenever the volume changes. |
| `EnsureDefaultOutput()` | Returns the local default `AudioDeviceOutput`. |
| `CreateListener(config?)` | Creates an `AudioListener` and wires it to output. |
| `CreateEmitter(parent, config?)` | Creates an `AudioEmitter` on a world instance. |
| `Play2D(config)` | Builds and starts a 2D `AudioPlayer` graph. |
| `Play3D(config)` | Builds and starts a 3D `AudioPlayer` to `AudioEmitter` graph. |
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

## Architecture Notes

- Use `ServiceBag:GetService()` for `AudioService` and `AudioServiceClient`.
- This package is a Nevermore service pair plus small shared utilities, not a
  full game audio framework.
- `Init` creates registries and folders only; runtime playback happens through
  explicit API calls.
- All generated graph handles implement `Destroy()`, so they fit naturally into
  Nevermore `Maid` cleanup.
- The services use `@hexium-softworks/log` for structured lifecycle and
  registration logs; configure Log levels or sinks in your game if you want to
  surface or suppress them.
- No remotes are created. Server registration is a registry/default layer;
  clients own local playback graphs and local user settings.
