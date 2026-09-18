--!strict
--[=[
	Server-owned registry for Roblox Input Action System contexts.

	This service intentionally exposes no remotes. Client-side input state is
	only intent and must never be treated as gameplay authority by the server.

	@class InputService
]=]

local require = require(script.Parent.loader).load(script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Maid = require("Maid")
local ServiceBag = require("ServiceBag")

local InputServiceInstanceUtils = require("InputServiceInstanceUtils")
local InputServiceTypes = require("InputServiceTypes")

type ServiceBag = ServiceBag.ServiceBag
type InputContextConfig = InputServiceTypes.InputContextConfig
type InputActionConfig = InputServiceTypes.InputActionConfig
type InputBindingConfig = InputServiceTypes.InputBindingConfig

local InputService = {}
InputService.ServiceName = "InputService"

export type InputService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag,
		_maid: Maid.Maid,
		_rootFolder: Folder,
	},
	{} :: typeof({ __index = InputService })
))

function InputService.Init(self: InputService, serviceBag: ServiceBag): ()
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()
	self._rootFolder = InputServiceInstanceUtils.getOrCreateRootFolder(ReplicatedStorage)
end

function InputService.Start(_self: InputService): () end

--[=[
	Returns the shared input root folder in ReplicatedStorage.

	@return Folder
]=]
function InputService.GetRootFolder(self: InputService): Folder
	return self._rootFolder
end

--[=[
	Registers or updates a server-owned shared input context.

	@param config InputContextConfig
	@return InputContext
]=]
function InputService.RegisterContext(self: InputService, config: InputContextConfig): InputContext
	return InputServiceInstanceUtils.upsertContext(self._rootFolder, config)
end

--[=[
	Registers or updates multiple server-owned shared input contexts.

	@param configs { InputContextConfig }
]=]
function InputService.RegisterContexts(self: InputService, configs: { InputContextConfig }): ()
	assert(typeof(configs) == "table", "Configs must be a table")

	for _, config in configs do
		self:RegisterContext(config)
	end
end

function InputService.GetContext(self: InputService, contextName: string): InputContext?
	assert(typeof(contextName) == "string", "Context name must be a string")

	return InputServiceInstanceUtils.getContext(self._rootFolder, contextName)
end

function InputService.GetAction(self: InputService, contextName: string, actionName: string): InputAction?
	assert(typeof(actionName) == "string", "Action name must be a string")

	local context = self:GetContext(contextName)
	if not context then
		return nil
	end

	return InputServiceInstanceUtils.getAction(context, actionName)
end

function InputService.GetBinding(
	self: InputService,
	contextName: string,
	actionName: string,
	bindingName: string
): InputBinding?
	assert(typeof(bindingName) == "string", "Binding name must be a string")

	local action = self:GetAction(contextName, actionName)
	if not action then
		return nil
	end

	return InputServiceInstanceUtils.getBinding(action, bindingName)
end

function InputService.ConfigureAction(
	self: InputService,
	contextName: string,
	actionConfig: InputActionConfig
): InputAction
	local context = self:GetContext(contextName)
	assert(context, string.format("InputContext %q does not exist", contextName))

	return InputServiceInstanceUtils.upsertAction(context, actionConfig)
end

function InputService.ConfigureBinding(
	self: InputService,
	contextName: string,
	actionName: string,
	bindingConfig: InputBindingConfig
): InputBinding
	local action = self:GetAction(contextName, actionName)
	assert(action, string.format("InputAction %q.%q does not exist", contextName, actionName))

	return InputServiceInstanceUtils.upsertBinding(action, bindingConfig)
end

function InputService.SetContextEnabled(self: InputService, contextName: string, enabled: boolean): ()
	assert(typeof(enabled) == "boolean", "Enabled must be a boolean")

	local context = self:GetContext(contextName)
	assert(context, string.format("InputContext %q does not exist", contextName))

	context.Enabled = enabled
end

function InputService.SetActionEnabled(self: InputService, contextName: string, actionName: string, enabled: boolean): ()
	assert(typeof(enabled) == "boolean", "Enabled must be a boolean")

	local action = self:GetAction(contextName, actionName)
	assert(action, string.format("InputAction %q.%q does not exist", contextName, actionName))

	action.Enabled = enabled
end

function InputService.RemoveContext(self: InputService, contextName: string): boolean
	assert(typeof(contextName) == "string", "Context name must be a string")

	return InputServiceInstanceUtils.removeContext(self._rootFolder, contextName)
end

function InputService.RemoveAction(self: InputService, contextName: string, actionName: string): boolean
	local context = self:GetContext(contextName)
	if not context then
		return false
	end

	return InputServiceInstanceUtils.removeAction(context, actionName)
end

function InputService.RemoveBinding(
	self: InputService,
	contextName: string,
	actionName: string,
	bindingName: string
): boolean
	local action = self:GetAction(contextName, actionName)
	if not action then
		return false
	end

	return InputServiceInstanceUtils.removeBinding(action, bindingName)
end

function InputService.Destroy(self: InputService): ()
	self._maid:DoCleaning()
end

return InputService
