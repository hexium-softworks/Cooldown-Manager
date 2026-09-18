--!strict
--[=[
	Instance creation and upsert utilities for InputService.

	@class InputServiceInstanceUtils
]=]

local require = require(script.Parent.loader).load(script)

local InputServiceConfigUtils = require("InputServiceConfigUtils")
local InputServiceConstants = require("InputServiceConstants")
local InputServiceTypes = require("InputServiceTypes")

type InputContextConfig = InputServiceTypes.InputContextConfig
type InputActionConfig = InputServiceTypes.InputActionConfig
type InputBindingConfig = InputServiceTypes.InputBindingConfig

local InputServiceInstanceUtils = {}

local CONTEXT_PROPERTIES = { "Enabled", "Priority", "Sink" }
local ACTION_PROPERTIES = { "DisplayName", "Enabled", "Type" }
local BINDING_PROPERTIES = {
	"Type",
	"KeyCode",
	"UIButton",
	"UIModifier",
	"PrimaryModifier",
	"SecondaryModifier",
	"DisplayName",
	"DisplayImage",
	"PressedThreshold",
	"ReleasedThreshold",
	"ResponseCurve",
	"Scale",
	"Vector2Scale",
	"Vector3Scale",
	"PointerIndex",
	"ClampMagnitudeToOne",
	"Up",
	"Down",
	"Left",
	"Right",
	"Forward",
	"Backward",
}

local function findTypedChild(parent: Instance, name: string, className: string): Instance?
	local child = parent:FindFirstChild(name)
	if child == nil then
		return nil
	end

	assert(
		child:IsA(className),
		string.format("%s exists but is a %s, not %s", child:GetFullName(), child.ClassName, className)
	)
	return child
end

local function upsertChild(parent: Instance, name: string, className: string): Instance
	local child = findTypedChild(parent, name, className)
	if child then
		return child
	end

	InputServiceConfigUtils.assertCanCreateInputClass(className)

	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

local function applyProperties(instance: Instance, config: { [string]: any }, propertyNames: { string }): ()
	local writableInstance = instance :: any
	for _, propertyName in propertyNames do
		local value = config[propertyName]
		if value ~= nil then
			writableInstance[propertyName] = value
		end
	end
end

function InputServiceInstanceUtils.getOrCreateRootFolder(parent: Instance): Folder
	local child = parent:FindFirstChild(InputServiceConstants.ROOT_FOLDER_NAME)
	if child then
		assert(
			child:IsA(InputServiceConstants.ROOT_FOLDER_CLASS_NAME),
			string.format(
				"%s must be a %s",
				child:GetFullName(),
				InputServiceConstants.ROOT_FOLDER_CLASS_NAME
			)
		)
		return child :: Folder
	end

	local folder = Instance.new(InputServiceConstants.ROOT_FOLDER_CLASS_NAME)
	folder.Name = InputServiceConstants.ROOT_FOLDER_NAME
	folder.Parent = parent
	return folder :: Folder
end

function InputServiceInstanceUtils.getContext(rootFolder: Instance, contextName: string): InputContext?
	local context = findTypedChild(rootFolder, contextName, InputServiceConstants.CONTEXT_CLASS_NAME)
	return context :: InputContext?
end

function InputServiceInstanceUtils.getAction(context: Instance, actionName: string): InputAction?
	assert(context:IsA(InputServiceConstants.CONTEXT_CLASS_NAME), "Context must be an InputContext")

	local action = findTypedChild(context, actionName, InputServiceConstants.ACTION_CLASS_NAME)
	return action :: InputAction?
end

function InputServiceInstanceUtils.getBinding(action: Instance, bindingName: string): InputBinding?
	assert(action:IsA(InputServiceConstants.ACTION_CLASS_NAME), "Action must be an InputAction")

	local binding = findTypedChild(action, bindingName, InputServiceConstants.BINDING_CLASS_NAME)
	return binding :: InputBinding?
end

function InputServiceInstanceUtils.upsertBinding(action: Instance, config: InputBindingConfig): InputBinding
	assert(action:IsA(InputServiceConstants.ACTION_CLASS_NAME), "Binding parent must be an InputAction")
	InputServiceConfigUtils.validateBindingConfig(config)

	local binding = upsertChild(action, config.Name, InputServiceConstants.BINDING_CLASS_NAME) :: InputBinding
	applyProperties(binding, config :: any, BINDING_PROPERTIES)
	return binding
end

function InputServiceInstanceUtils.upsertAction(context: Instance, config: InputActionConfig): InputAction
	assert(context:IsA(InputServiceConstants.CONTEXT_CLASS_NAME), "Action parent must be an InputContext")
	InputServiceConfigUtils.validateActionConfig(config)

	local action = upsertChild(context, config.Name, InputServiceConstants.ACTION_CLASS_NAME) :: InputAction
	applyProperties(action, config :: any, ACTION_PROPERTIES)

	if config.Bindings then
		for _, bindingConfig in config.Bindings do
			InputServiceInstanceUtils.upsertBinding(action, bindingConfig)
		end
	end

	return action
end

function InputServiceInstanceUtils.upsertContext(rootFolder: Instance, config: InputContextConfig): InputContext
	assert(rootFolder:IsA(InputServiceConstants.ROOT_FOLDER_CLASS_NAME), "Context parent must be the input root Folder")
	InputServiceConfigUtils.validateContextConfig(config)

	local context = upsertChild(rootFolder, config.Name, InputServiceConstants.CONTEXT_CLASS_NAME) :: InputContext
	applyProperties(context, config :: any, CONTEXT_PROPERTIES)

	if config.Actions then
		for _, actionConfig in config.Actions do
			InputServiceInstanceUtils.upsertAction(context, actionConfig)
		end
	end

	return context
end

function InputServiceInstanceUtils.removeContext(rootFolder: Instance, contextName: string): boolean
	local context = InputServiceInstanceUtils.getContext(rootFolder, contextName)
	if not context then
		return false
	end

	context:Destroy()
	return true
end

function InputServiceInstanceUtils.removeAction(context: Instance, actionName: string): boolean
	local action = InputServiceInstanceUtils.getAction(context, actionName)
	if not action then
		return false
	end

	action:Destroy()
	return true
end

function InputServiceInstanceUtils.removeBinding(action: Instance, bindingName: string): boolean
	local binding = InputServiceInstanceUtils.getBinding(action, bindingName)
	if not binding then
		return false
	end

	binding:Destroy()
	return true
end

return InputServiceInstanceUtils
