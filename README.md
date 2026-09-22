# Cooldown Manager

A game-agnostic Nevermore package for server-authoritative runtime cooldowns.

Cooldown Manager tracks cooldowns by owner and string key, supports atomic
check-and-start operations, shared cooldown groups, cancellation and adjustment,
and read-only client timing snapshots for UI.

It does not execute abilities, process inputs, prevent network abuse, persist
daily rewards, or decide game-specific cooldown definitions.

## Installation

```sh
pnpm add @hexium-softworks/cooldown-manager
```

## Nevermore Usage

Use the conflict-free manager service names through `ServiceBag`.

Server:

```lua
local require = require(script.Parent.loader).load(script)

local CooldownManagerService = require("CooldownManagerService")

function AbilityService:Init(serviceBag)
	self._cooldowns = serviceBag:GetService(CooldownManagerService)
end

function AbilityService:TryDash(player)
	local success, cooldown = self._cooldowns:TryStart(player, "Abilities.Dash", 3, {
		Replicate = true,
	})

	if not success then
		return false, cooldown:GetRemaining()
	end

	return true
end
```

Client:

```lua
local require = require(script.Parent.loader).load(script)

local CooldownManagerServiceClient = require("CooldownManagerServiceClient")

function AbilityHud:Init(serviceBag)
	self._cooldowns = serviceBag:GetService(CooldownManagerServiceClient)
end

function AbilityHud:Start()
	self._maid:GiveTask(self._cooldowns:ObserveReady("Abilities.Dash", function(isReady)
		self._dashButton.Active = isReady
	end))
end
```

## Server API

`CooldownManagerService` is the authoritative registry.

| Method | Description |
| --- | --- |
| `GetTracker(owner)` | Returns or creates the tracker for an owner. |
| `FindTracker(owner)` | Returns an existing tracker, if one exists. |
| `DestroyTracker(owner)` | Destroys and removes one tracker. |
| `Clear(owner)` | Cancels all cooldowns for an owner. |
| `IsReady(owner, key)` | Returns whether the key is not cooling down. |
| `GetRemaining(owner, key)` | Returns remaining seconds, or `0`. |
| `GetCooldown(owner, key)` | Returns the cooldown object, if active. |
| `TryStart(owner, key, duration, options?)` | Atomically starts only if ready. |
| `Start(owner, key, duration, options?)` | Starts or raises if rejected. |
| `Cancel(owner, key)` | Cancels an active cooldown. |
| `Extend(owner, key, duration)` | Adds time to an active cooldown. |
| `Reduce(owner, key, duration)` | Removes time from an active cooldown. |
| `TryAcquire(owner, request)` | Atomically checks and starts multiple keys. |
| `SetReplicationAdapter(adapter?)` | Installs the optional replication adapter. |

Tracker objects mirror these methods without the `owner` argument.

## Policies

```lua
local Constants = require("CooldownManagerConstants")
local CooldownPolicy = Constants.CooldownPolicy

cooldowns:Start(player, "Abilities.Fireball", 8, {
	Policy = CooldownPolicy.Restart,
})
```

Policies:

- `Reject`: default; active cooldowns block the new start.
- `Restart`: replace the current start/end timestamps.
- `KeepLonger`: keep an active cooldown when it already has at least as much
  remaining time.
- `Extend`: add the supplied duration to an active cooldown.

## Shared Cooldowns

Use ordinary namespaced keys for group behavior.

```lua
local result = tracker:TryAcquire({
	Require = {
		"Abilities.Fireball",
		"Groups.GlobalAbility",
	},

	Start = {
		["Abilities.Fireball"] = 8,
		["Groups.GlobalAbility"] = 0.75,
	},
})

if not result.Success then
	return false, result.BlockedBy, result.Remaining
end
```

## Client API

`CooldownManagerServiceClient` is read-only. It exposes local timing helpers over
snapshots applied by a future replication adapter.

| Method | Description |
| --- | --- |
| `IsReady(key)` | Returns whether the key has no active client snapshot. |
| `GetCooldown(key)` | Returns a defensive snapshot copy, if active. |
| `GetRemaining(key)` | Calculates remaining time from timestamps. |
| `GetProgress(key)` | Calculates progress from `0` to `1`. |
| `ObserveCooldown(key, callback)` | Fires immediately and when the snapshot changes. |
| `ObserveRemaining(key, options?, callback)` | Samples remaining time while active. |
| `ObserveProgress(key, options?, callback)` | Samples progress while active. |
| `ObserveReady(key, callback)` | Fires ready state changes. |
| `ObserveAll(callback)` | Observes all snapshot changes. |

The client intentionally has no `Start`, `Cancel`, `Extend`, `Reduce`, or
`Clear` methods.

## Replication Adapter

Runtime cooldowns work without a replication adapter. When a cooldown is started
with `{ Replicate = true }`, the server calls the configured adapter:

```lua
cooldowns:SetReplicationAdapter({
	CooldownStarted = function(self, owner, key, snapshot) end,
	CooldownUpdated = function(self, owner, key, snapshot) end,
	CooldownRemoved = function(self, owner, key) end,
	TrackerCleared = function(self, owner) end,
})
```

This keeps v1 independent of any specific `ReplicationService` package while
leaving a small integration point for owner-visible replicated states later.

## Key Rules

Cooldown keys must be strings from 1 to 128 characters. They cannot start or end
with `.`, contain `..`, or start with the reserved `__` prefix.

Recommended names:

- `Abilities.Dash`
- `Abilities.Fireball`
- `Tools.Sword.Primary`
- `Interactions.Door`
- `Groups.GlobalAbility`

## Persistence Boundary

Cooldown Manager is for ephemeral runtime cooldowns such as abilities, weapons,
interactions, and UI affordances. Long-term timestamps like daily rewards,
multi-day crafting, timed bans, and event claim dates should be stored by their
own systems.
