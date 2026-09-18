--!strict
--[=[
	Validation helpers for InputService configs.

	@class InputServiceConfigUtils
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

local InputServiceConfigUtils = {}

type FieldMap = { [string]: string }

local CONTEXT_FIELDS: FieldMap = Table.readonly({
	Name = "string",
	Enabled = "boolean",
	Priority = "number",
	Sink = "boolean",
	Actions = "table",
})

local ACTION_FIELDS: FieldMap = Table.readonly({
	Name = "string",
	DisplayName = "string",
	Enabled = "boolean",
	Type = "InputActionType",
	Bindings = "table",
})

local BINDING_FIELDS: FieldMap = Table.readonly({
	Name = "string",
	Type = "InputBindingType",
	KeyCode = "KeyCode",
	UIButton = "GuiButton",
	UIModifier = "GuiButton",
	PrimaryModifier = "KeyCode",
	SecondaryModifier = "KeyCode",
	DisplayName = "string",
	DisplayImage = "Content",
	PressedThreshold = "number",
	ReleasedThreshold = "number",
	ResponseCurve = "number",
	Scale = "number",
	Vector2Scale = "Vector2",
	Vector3Scale = "Vector3",
	PointerIndex = "number",
	ClampMagnitudeToOne = "boolean",
	Up = "KeyCode",
	Down = "KeyCode",
	Left = "KeyCode",
	Right = "KeyCode",
	Forward = "KeyCode",
	Backward = "KeyCode",
})

local function validateName(value: any, path: string): ()
	assert(typeof(value) == "string", string.format("%s.Name must be a string", path))
	assert(#value > 0, string.format("%s.Name must not be empty", path))
	assert(#value <= 100, string.format("%s.Name must be 100 characters or fewer", path))
	assert(not string.find(value, "[%c/]"), string.format("%s.Name contains unsupported characters", path))
end

local function validateEnumItem(value: any, enumType: any, fieldName: string): ()
	assert(typeof(value) == "EnumItem", string.format("%s must be an EnumItem", fieldName))
	assert(value.EnumType == enumType, string.format("%s must be a member of %s", fieldName, tostring(enumType)))
end

local function validateGuiButton(value: any, fieldName: string): ()
	assert(typeof(value) == "Instance", string.format("%s must be a GuiButton", fieldName))
	assert(value:IsA("GuiButton"), string.format("%s must be a GuiButton", fieldName))
end

local function validateField(value: any, expectedType: string, fieldName: string): ()
	if expectedType == "KeyCode" then
		validateEnumItem(value, Enum.KeyCode, fieldName)
	elseif expectedType == "InputActionType" then
		validateEnumItem(value, Enum.InputActionType, fieldName)
	elseif expectedType == "InputBindingType" then
		validateEnumItem(value, Enum.InputBindingType, fieldName)
	elseif expectedType == "GuiButton" then
		validateGuiButton(value, fieldName)
	elseif expectedType == "Content" then
		assert(typeof(value) == "string" or typeof(value) == "Content", string.format("%s must be Content", fieldName))
	else
		assert(typeof(value) == expectedType, string.format("%s must be %s", fieldName, expectedType))
	end
end

local function validateKnownFields(config: { [any]: any }, allowedFields: FieldMap, path: string): ()
	for key, value in config do
		assert(typeof(key) == "string", string.format("%s contains a non-string key", path))

		local expectedType = allowedFields[key]
		assert(expectedType ~= nil, string.format("%s.%s is not a supported config field", path, key))

		if value ~= nil then
			validateField(value, expectedType, string.format("%s.%s", path, key))
		end
	end
end

function InputServiceConfigUtils.validateBindingConfig(config: any, path: string?): ()
	local bindingPath = path or "Binding"
	assert(typeof(config) == "table", string.format("%s must be a table", bindingPath))
	validateKnownFields(config, BINDING_FIELDS, bindingPath)
	validateName(config.Name, bindingPath)

	if config.PressedThreshold ~= nil and config.ReleasedThreshold ~= nil then
		assert(
			config.PressedThreshold >= config.ReleasedThreshold,
			string.format("%s.PressedThreshold must be greater than or equal to ReleasedThreshold", bindingPath)
		)
	end
end

function InputServiceConfigUtils.validateActionConfig(config: any, path: string?): ()
	local actionPath = path or "Action"
	assert(typeof(config) == "table", string.format("%s must be a table", actionPath))
	validateKnownFields(config, ACTION_FIELDS, actionPath)
	validateName(config.Name, actionPath)

	if config.Bindings ~= nil then
		for index, bindingConfig in config.Bindings do
			assert(typeof(index) == "number", string.format("%s.Bindings must be an array", actionPath))
			InputServiceConfigUtils.validateBindingConfig(
				bindingConfig,
				string.format("%s.Bindings[%d]", actionPath, index)
			)
		end
	end
end

function InputServiceConfigUtils.validateContextConfig(config: any, path: string?): ()
	local contextPath = path or "Context"
	assert(typeof(config) == "table", string.format("%s must be a table", contextPath))
	validateKnownFields(config, CONTEXT_FIELDS, contextPath)
	validateName(config.Name, contextPath)

	if config.Actions ~= nil then
		for index, actionConfig in config.Actions do
			assert(typeof(index) == "number", string.format("%s.Actions must be an array", contextPath))
			InputServiceConfigUtils.validateActionConfig(
				actionConfig,
				string.format("%s.Actions[%d]", contextPath, index)
			)
		end
	end
end

function InputServiceConfigUtils.assertCanCreateInputClass(className: string): ()
	local ok, instance = pcall(Instance.new, className, nil)
	if ok and typeof(instance) == "Instance" then
		instance:Destroy()
		return
	end

	error(
		string.format(
			"%s is not available in this Roblox runtime. Enable the Input Action System beta or run in a newer engine.",
			className
		),
		2
	)
end

return InputServiceConfigUtils
