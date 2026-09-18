# Log

A small, game-agnostic Luau logging package for Nevermore-style Roblox projects.

Log keeps the default global logger simple while exposing sink-based output for runtime debug consoles, custom telemetry, or test capture.

## Installation

```sh
npm install @hexium-softworks/log
```

## Global Logger

```lua
local Log = require("Log")

Log.Info("Round started", {
	RoundId = 12,
})

Log.Warn("Optional asset missing", {
	AssetName = "VictoryFanfare",
})
```

By default, the Roblox adapter writes through `LogService`.

## Custom Loggers

```lua
local MatchLog = Log.new({
	name = "MatchService",
	defaultContext = {
		Service = "MatchService",
	},
	minLevel = "Debug",
})

local RoundLog = MatchLog:WithContext({
	RoundId = 12,
})

RoundLog.Debug("Assigned teams")
RoundLog.Info("Round started")
```

## Minimum Levels

```lua
Log.SetGlobalMinLevel("Warn")

local VerboseLog = Log.new({
	minLevel = "Verbose",
})
```

Logger-level minimums override the global minimum. Sink-level minimums are applied after the logger/global filter.

## Sinks

Sinks receive structured log entries and can choose their own minimum level.

```lua
local consoleEntries = {}

Log.AddSink({
	Name = "RuntimeDebugConsole",
	MinLevel = "Verbose",
	Write = function(entry)
		table.insert(consoleEntries, entry)
	end,
})

Log.Log("Debug", "Inventory changed", {
	Player = "HexedEthan",
})
```

Each entry includes:

```lua
{
	Level = "Info",
	Message = "Round started",
	Context = {},
	Timestamp = 123.456,
	Source = "MatchService",
	Function = "startRound",
	LoggerName = "MatchService",
}
```
