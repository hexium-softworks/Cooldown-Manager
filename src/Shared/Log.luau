local LogService = game:GetService("LogService")

local require = require(script.Parent.loader).load(script)

local LogCore = require("LogCore")

export type LogLevel = LogCore.LogLevel
export type Context = LogCore.Context
export type LogEntry = LogCore.LogEntry
export type LogSink = LogCore.LogSink
export type LoggerConfig = LogCore.LoggerConfig
export type Logger = LogCore.Logger

local LOG_SERVICE_SINK: LogSink = {
	Name = "LogService",
	Write = function(entry: LogEntry)
		if entry.Level == "Warn" then
			LogService:Warn(entry.Message, entry.Context)
		elseif entry.Level == "Error" or entry.Level == "Fatal" then
			LogService:Error(entry.Message, entry.Context)
		elseif entry.Level == "Info" then
			LogService:Info(entry.Message, entry.Context)
		else
			LogService:Output(entry.Message, entry.Context)
		end
	end,
}

LogCore.AddSink(LOG_SERVICE_SINK)

return LogCore
