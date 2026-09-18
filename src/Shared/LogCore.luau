export type LogLevel = "Verbose" | "Debug" | "Info" | "Warn" | "Error" | "Fatal"
export type Context = { [string]: any }

export type LogEntry = {
	Level: LogLevel,
	Message: string,
	Context: Context,
	Timestamp: number,
	Source: string?,
	Function: string?,
	LoggerName: string?,
}

export type LogSink = {
	Name: string?,
	MinLevel: LogLevel?,
	Write: (entry: LogEntry) -> (),
}

export type LoggerConfig = {
	minLevel: LogLevel?,
	defaultContext: Context?,
	name: string?,
}

export type Logger = {
	-- Verbose: High-frequency or granular tracing (ticks, network packets).
	Verbose: (message: string, context: Context?) -> (),
	-- Debug: Diagnostic context for development (state changes, calculations).
	Debug: (message: string, context: Context?) -> (),
	-- Info: Normal lifecycle milestones in production (player joined, round started).
	Info: (message: string, context: Context?) -> (),
	-- Warn: Non-fatal anomalies (slow requests, missing optional assets).
	Warn: (message: string, context: Context?) -> (),
	-- Error: Recoverable operation failures; does not crash the calling thread.
	Error: (message: string, context: Context?) -> (),
	-- Fatal: Unrecoverable failures; terminates the thread via uncaught error.
	Fatal: (message: string, context: Context?) -> (),

	Log: (level: LogLevel, message: string, context: Context?) -> (),
	SetMinLevel: (self: Logger, level: LogLevel) -> (),
	WithContext: (self: Logger, extraContext: Context) -> Logger,
}

local LOG_LEVELS: { [LogLevel]: number } = {
	Verbose = 1,
	Debug = 2,
	Info = 3,
	Warn = 4,
	Error = 5,
	Fatal = 6,
}

local LEVEL_NAMES_BY_VALUE: { [number]: LogLevel } = {}
for levelName, levelValue in LOG_LEVELS do
	LEVEL_NAMES_BY_VALUE[levelValue] = levelName
end

local globalMinLevel: number = LOG_LEVELS.Info
local sinks: { LogSink } = {}

local function assertLogLevel(level: any): LogLevel
	assert(LOG_LEVELS[level :: LogLevel] ~= nil, `Invalid LogLevel: {tostring(level)}`)
	return level :: LogLevel
end

local function getLogLevelValue(level: LogLevel): number
	return LOG_LEVELS[level]
end

local function cleanSource(rawSource: string?): string?
	if not rawSource then
		return nil
	end

	local name = rawSource:match("([^%.=]+)$")
	return name or rawSource
end

local function normalizeMessageAndContext(firstArg: any, secondArg: any, thirdArg: any): (string, Context?)
	-- Supports both dot notation (logger.Info("msg")) and colon notation (logger:Info("msg")).
	if typeof(firstArg) == "table" and typeof(secondArg) == "string" then
		return secondArg, thirdArg
	end

	if secondArg ~= nil and typeof(secondArg) ~= "table" then
		return `{tostring(firstArg)} {tostring(secondArg)}{if thirdArg ~= nil then ` {tostring(thirdArg)}` else ""}`,
			nil
	end

	return tostring(firstArg), secondArg
end

local function mergeContexts(baseContext: Context, callContext: Context?): Context
	local mergedContext = table.clone(baseContext)

	if callContext then
		for key, value in callContext do
			mergedContext[key] = value
		end
	end

	return mergedContext
end

local function orderContext(context: Context, levelName: LogLevel, source: string?, functionName: string?): Context
	local orderedContext: Context = {
		Level = levelName,
	}

	if source then
		orderedContext.Source = source
	end

	if functionName and functionName ~= "" then
		orderedContext.Function = functionName
	end

	for key, value in context do
		if key ~= "Level" and key ~= "Source" and key ~= "Function" then
			orderedContext[key] = value
		end
	end

	return orderedContext
end

local function validateSink(sink: LogSink)
	assert(typeof(sink) == "table", "LogSink must be a table")
	assert(typeof(sink.Write) == "function", "LogSink.Write must be a function")

	if sink.MinLevel ~= nil then
		assertLogLevel(sink.MinLevel)
	end
end

local function shouldWriteToSink(sink: LogSink, levelName: LogLevel): boolean
	if sink.MinLevel == nil then
		return true
	end

	return getLogLevelValue(levelName) >= getLogLevelValue(sink.MinLevel)
end

local function writeToSinks(entry: LogEntry)
	for _, sink in sinks do
		if shouldWriteToSink(sink, entry.Level) then
			pcall(sink.Write, entry)
		end
	end
end

local function createLogEntry(
	levelName: LogLevel,
	message: string,
	baseContext: Context,
	callContext: Context?,
	loggerName: string?,
	rawSource: string?,
	functionName: string?
): LogEntry
	local mergedContext = mergeContexts(baseContext, callContext)
	local source = mergedContext.Source or cleanSource(rawSource)
	local resolvedFunctionName = mergedContext.Function or functionName
	local orderedContext = orderContext(mergedContext, levelName, source, resolvedFunctionName)

	return {
		Level = levelName,
		Message = message,
		Context = orderedContext,
		Timestamp = os.clock(),
		Source = source,
		Function = resolvedFunctionName,
		LoggerName = loggerName,
	}
end

local function createLogger(config: LoggerConfig?): Logger
	local logger = {} :: Logger
	local configuredMinLevel: number? = if config and config.minLevel
		then getLogLevelValue(assertLogLevel(config.minLevel))
		else nil
	local baseContext: Context = if config and config.defaultContext then table.clone(config.defaultContext) else {}
	local loggerName = if config then config.name else nil

	local function emit(
		levelName: LogLevel,
		message: string,
		callContext: Context?,
		rawSource: string?,
		functionName: string?
	)
		local threshold = configuredMinLevel or globalMinLevel
		if getLogLevelValue(levelName) < threshold then
			return
		end

		local entry = createLogEntry(levelName, message, baseContext, callContext, loggerName, rawSource, functionName)
		writeToSinks(entry)

		if levelName == "Fatal" then
			error(message, 3)
		end
	end

	local function makeLogMethod(levelName: LogLevel)
		return function(firstArg: any, secondArg: any, thirdArg: any)
			local message, callContext = normalizeMessageAndContext(firstArg, secondArg, thirdArg)
			local rawSource, functionName = debug.info(2, "sn")
			emit(levelName, message, callContext, rawSource, functionName)
		end
	end

	logger.Verbose = makeLogMethod("Verbose")
	logger.Debug = makeLogMethod("Debug")
	logger.Info = makeLogMethod("Info")
	logger.Warn = makeLogMethod("Warn")
	logger.Error = makeLogMethod("Error")
	logger.Fatal = makeLogMethod("Fatal")

	function logger.Log(selfOrLevel: any, maybeLevelOrMessage: any, maybeMessageOrContext: any, maybeContext: any)
		local levelName: LogLevel
		local message: string
		local callContext: Context?

		if typeof(selfOrLevel) == "table" then
			levelName = assertLogLevel(maybeLevelOrMessage)
			message = tostring(maybeMessageOrContext)
			callContext = maybeContext
		else
			levelName = assertLogLevel(selfOrLevel)
			message = tostring(maybeLevelOrMessage)
			callContext = maybeMessageOrContext
		end

		local rawSource, functionName = debug.info(2, "sn")
		emit(levelName, message, callContext, rawSource, functionName)
	end

	function logger.SetMinLevel(selfOrLevel: any, maybeLevel: any)
		local level: LogLevel = if typeof(selfOrLevel) == "table" then maybeLevel else selfOrLevel
		configuredMinLevel = getLogLevelValue(assertLogLevel(level))
	end

	function logger.WithContext(selfOrContext: any, maybeContext: any): Logger
		local extraContext: Context = if typeof(selfOrContext) == "table" and maybeContext ~= nil
			then maybeContext
			else selfOrContext
		local mergedContext = table.clone(baseContext)

		if extraContext then
			for key, value in extraContext do
				mergedContext[key] = value
			end
		end

		return createLogger({
			minLevel = if configuredMinLevel then LEVEL_NAMES_BY_VALUE[configuredMinLevel] else nil,
			defaultContext = mergedContext,
			name = loggerName,
		})
	end

	return logger
end

local RootLog = createLogger()

local LogCore = RootLog :: typeof(RootLog) & {
	new: (config: LoggerConfig?) -> Logger,
	AddSink: (sink: LogSink) -> (),
	RemoveSink: (sinkOrName: LogSink | string) -> boolean,
	ClearSinks: () -> (),
	GetSinks: () -> { LogSink },
	SetGlobalMinLevel: (level: LogLevel) -> (),
}

LogCore.new = createLogger

function LogCore.AddSink(sink: LogSink)
	validateSink(sink)
	table.insert(sinks, sink)
end

function LogCore.RemoveSink(sinkOrName: LogSink | string): boolean
	for index, sink in sinks do
		if sink == sinkOrName or (typeof(sinkOrName) == "string" and sink.Name == sinkOrName) then
			table.remove(sinks, index)
			return true
		end
	end

	return false
end

function LogCore.ClearSinks()
	table.clear(sinks)
end

function LogCore.GetSinks(): { LogSink }
	return table.clone(sinks)
end

function LogCore.SetGlobalMinLevel(level: LogLevel)
	globalMinLevel = getLogLevelValue(assertLogLevel(level))
end

return LogCore
