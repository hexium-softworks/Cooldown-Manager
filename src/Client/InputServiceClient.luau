--!strict
--[=[
	Client-side helpers for Roblox Input Action System contexts.

	Client mutations are local convenience only. They are non-authoritative and
	are not replicated to the server through this package.

	@class InputServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Maid = require("Maid")
local ServiceBag = require("ServiceBag")
local Signal = require("Signal")

local InputServiceConstants = require("InputServiceConstants")
local InputServiceInstanceUtils = require("InputServiceInstanceUtils")
local InputServiceTypes = require("InputServiceTypes")

type ServiceBag = ServiceBag.ServiceBag
type InputContextConfig = InputServiceTypes.InputContextConfig
type InputActionConfig = InputServiceTypes.InputActionConfig
type InputBindingConfig = InputServiceTypes.InputBindingConfig
type InputActionState = InputServiceTypes.InputActionState
type ActionSignalBundle = InputServiceTypes.ActionSignalBundle

local InputServiceClient = {}
InputServiceClient.ServiceName = "InputServiceClient"

export type InputServiceClient = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag,
		_maid: Maid.Maid,
		_rootFolder: Folder?,
		_actionSignals: { [InputAction]: ActionSignalBundle },
	},
	{} :: typeof({ __index = InputServiceClient })
))

local function findRootFolder(): Folder?
	local child = ReplicatedStorage:FindFirstChild(InputServiceConstants.ROOT_FOLDER_NAME)
	if child == nil then
		return nil
	end

	assert(
		child:IsA(InputServiceConstants.ROOT_FOLDER_CLASS_NAME),
		string.format("%s must be a %s", child:GetFullName(), InputServiceConstants.ROOT_FOLDER_CLASS_NAME)
	)

	return child :: Folder
end

local function createActionSignalBundle(action: InputAction): ActionSignalBundle
	local maid = Maid.new()

	local bundle = {
		Pressed = Signal.new(),
		Released = Signal.new(),
		StateChanged = Signal.new(),
		EnabledChanged = Signal.new(),
		PreferredBindingChanged = Signal.new(),
	} :: any

	maid:GiveTask(bundle.Pressed)
	maid:GiveTask(bundle.Released)
	maid:GiveTask(bundle.StateChanged)
	maid:GiveTask(bundle.EnabledChanged)
	maid:GiveTask(bundle.PreferredBindingChanged)

	maid:GiveTask(action.Pressed:Connect(function()
		bundle.Pressed:Fire()
	end))

	maid:GiveTask(action.Released:Connect(function()
		bundle.Released:Fire()
	end))

	maid:GiveTask(action.StateChanged:Connect(function(value: any)
		bundle.StateChanged:Fire(value)
	end))

	maid:GiveTask(action:GetPropertyChangedSignal("Enabled"):Connect(function()
		bundle.EnabledChanged:Fire(action.Enabled)
	end))

	maid:GiveTask(action:GetPropertyChangedSignal("PreferredBinding"):Connect(function()
		bundle.PreferredBindingChanged:Fire(action.PreferredBinding)
	end))

	function bundle:Destroy()
		maid:DoCleaning()
	end

	return bundle :: ActionSignalBundle
end

function InputServiceClient.Init(self: InputServiceClient, serviceBag: ServiceBag): ()
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()
	self._rootFolder = findRootFolder()
	self._actionSignals = {}
end

function InputServiceClient.Start(_self: InputServiceClient): () end

function InputServiceClient._getRootFolder(self: InputServiceClient, createIfMissing: boolean): Folder?
	local rootFolder = self._rootFolder
	if rootFolder and rootFolder.Parent then
		return rootFolder
	end

	rootFolder = findRootFolder()
	if rootFolder then
		self._rootFolder = rootFolder
		return rootFolder
	end

	if not createIfMissing then
		return nil
	end

	self._rootFolder = InputServiceInstanceUtils.getOrCreateRootFolder(ReplicatedStorage)
	return self._rootFolder
end

function InputServiceClient.GetRootFolder(self: InputServiceClient): Folder
	local rootFolder = self:_getRootFolder(true)
	assert(rootFolder, "Input root folder is not available")

	return rootFolder
end

function InputServiceClient.GetContext(self: InputServiceClient, contextName: string): InputContext?
	assert(typeof(contextName) == "string", "Context name must be a string")

	local rootFolder = self:_getRootFolder(false)
	if not rootFolder then
		return nil
	end

	return InputServiceInstanceUtils.getContext(rootFolder, contextName)
end

function InputServiceClient.WaitForContext(
	self: InputServiceClient,
	contextName: string,
	timeoutSeconds: number?
): InputContext?
	assert(typeof(contextName) == "string", "Context name must be a string")
	if timeoutSeconds ~= nil then
		assert(typeof(timeoutSeconds) == "number", "Timeout must be a number")
	end

	local context = self:GetContext(contextName)
	if context then
		return context
	end

	local rootFolder = self:_getRootFolder(false)
	if not rootFolder then
		local child = ReplicatedStorage:WaitForChild(InputServiceConstants.ROOT_FOLDER_NAME, timeoutSeconds)
		if child == nil then
			return nil
		end

		assert(
			child:IsA(InputServiceConstants.ROOT_FOLDER_CLASS_NAME),
			string.format("%s must be a %s", child:GetFullName(), InputServiceConstants.ROOT_FOLDER_CLASS_NAME)
		)

		rootFolder = child :: Folder
		self._rootFolder = rootFolder
	end

	local child = rootFolder:WaitForChild(contextName, timeoutSeconds)
	if child == nil then
		return nil
	end

	assert(child:IsA("InputContext"), string.format("%s must be an InputContext", child:GetFullName()))
	return child :: InputContext
end

function InputServiceClient.DefineLocalContext(self: InputServiceClient, config: InputContextConfig): InputContext
	return InputServiceInstanceUtils.upsertContext(self:GetRootFolder(), config)
end

function InputServiceClient.ConfigureAction(
	self: InputServiceClient,
	contextName: string,
	actionConfig: InputActionConfig
): InputAction
	local context = self:GetContext(contextName)
	assert(context, string.format("InputContext %q does not exist", contextName))

	return InputServiceInstanceUtils.upsertAction(context, actionConfig)
end

function InputServiceClient.ConfigureBinding(
	self: InputServiceClient,
	contextName: string,
	actionName: string,
	bindingConfig: InputBindingConfig
): InputBinding
	local action = self:GetAction(contextName, actionName)
	assert(action, string.format("InputAction %q.%q does not exist", contextName, actionName))

	return InputServiceInstanceUtils.upsertBinding(action, bindingConfig)
end

function InputServiceClient.GetAction(self: InputServiceClient, contextName: string, actionName: string): InputAction?
	assert(typeof(actionName) == "string", "Action name must be a string")

	local context = self:GetContext(contextName)
	if not context then
		return nil
	end

	return InputServiceInstanceUtils.getAction(context, actionName)
end

function InputServiceClient.GetBinding(
	self: InputServiceClient,
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

function InputServiceClient.GetActionSignals(
	self: InputServiceClient,
	contextName: string,
	actionName: string
): ActionSignalBundle
	local action = self:GetAction(contextName, actionName)
	assert(action, string.format("InputAction %q.%q does not exist", contextName, actionName))

	local existing = self._actionSignals[action]
	if existing then
		return existing
	end

	local bundle = createActionSignalBundle(action)
	self._actionSignals[action] = bundle
	self._maid:GiveTask(bundle)
	self._maid:GiveTask(action.Destroying:Connect(function()
		self._actionSignals[action] = nil
		bundle:Destroy()
	end))

	return bundle
end

function InputServiceClient.BindPressed(
	self: InputServiceClient,
	contextName: string,
	actionName: string,
	callback: () -> ()
): any
	assert(typeof(callback) == "function", "Callback must be a function")

	return self:GetActionSignals(contextName, actionName).Pressed:Connect(callback)
end

function InputServiceClient.BindReleased(
	self: InputServiceClient,
	contextName: string,
	actionName: string,
	callback: () -> ()
): any
	assert(typeof(callback) == "function", "Callback must be a function")

	return self:GetActionSignals(contextName, actionName).Released:Connect(callback)
end

function InputServiceClient.BindStateChanged(
	self: InputServiceClient,
	contextName: string,
	actionName: string,
	callback: (InputActionState) -> ()
): any
	assert(typeof(callback) == "function", "Callback must be a function")

	return self:GetActionSignals(contextName, actionName).StateChanged:Connect(callback)
end

function InputServiceClient.SetContextEnabled(self: InputServiceClient, contextName: string, enabled: boolean): ()
	assert(typeof(enabled) == "boolean", "Enabled must be a boolean")

	local context = self:GetContext(contextName)
	assert(context, string.format("InputContext %q does not exist", contextName))

	context.Enabled = enabled
end

function InputServiceClient.SetActionEnabled(
	self: InputServiceClient,
	contextName: string,
	actionName: string,
	enabled: boolean
): ()
	assert(typeof(enabled) == "boolean", "Enabled must be a boolean")

	local action = self:GetAction(contextName, actionName)
	assert(action, string.format("InputAction %q.%q does not exist", contextName, actionName))

	action.Enabled = enabled
end

function InputServiceClient.FireBinding(
	self: InputServiceClient,
	contextName: string,
	actionName: string,
	bindingName: string,
	state: InputActionState
): ()
	local binding = self:GetBinding(contextName, actionName, bindingName)
	assert(binding, string.format("InputBinding %q.%q.%q does not exist", contextName, actionName, bindingName))

	local ok, err = pcall(function()
		binding:Fire(state)
	end)

	assert(
		ok,
		string.format(
			"Failed to fire scriptable InputBinding %q.%q.%q: %s",
			contextName,
			actionName,
			bindingName,
			tostring(err)
		)
	)
end

function InputServiceClient.Destroy(self: InputServiceClient): ()
	self._maid:DoCleaning()
	table.clear(self._actionSignals)
end

return InputServiceClient
