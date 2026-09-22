--!strict
--[=[
	Shared public types for CooldownManager.

	@class CooldownManagerTypes
]=]

local CooldownManagerTypes = {}

export type CooldownPolicy = "Reject" | "Restart" | "KeepLonger" | "Extend"

export type CooldownSnapshot = {
	Key: string,
	StartTime: number,
	EndTime: number,
	Duration: number,
	Revision: number?,
	Metadata: { [string]: any }?,
}

export type CooldownStartOptions = {
	Policy: CooldownPolicy?,
	Replicate: boolean?,
	Metadata: { [string]: any }?,
}

export type TryAcquireRequest = {
	Require: { string }?,
	Start: { [string]: number },
	Options: { [string]: CooldownStartOptions }?,
}

export type TryAcquireResult = {
	Success: boolean,
	BlockedBy: string?,
	Remaining: number?,
	Started: { [string]: any }?,
}

export type Clock = {
	Now: (self: Clock) -> number,
}

export type Subscription = {
	Disconnect: (self: Subscription) -> (),
	Destroy: (self: Subscription) -> (),
}

return CooldownManagerTypes