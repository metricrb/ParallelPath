--!strict

type CustomSteering = {
	_callback: (position: Vector3, lookAt: Vector3) -> (),
	_rootPart: BasePart,
	moveTo: (self: CustomSteering, position: Vector3) -> (),
	jump: (self: CustomSteering) -> (),
	stop: (self: CustomSteering) -> (),
	destroy: (self: CustomSteering) -> (),
}

local CustomSteering = {}
CustomSteering.__index = CustomSteering

function CustomSteering.new(model: Model, callback: (position: Vector3, lookAt: Vector3) -> ()): CustomSteering
	local rootPart = model.PrimaryPart
	assert(rootPart, "Model must have a PrimaryPart")
	assert(callback, "CustomSteering requires a steering callback")

	return setmetatable({
		_callback = callback,
		_rootPart = rootPart,
	} :: any, CustomSteering) :: CustomSteering
end

function CustomSteering:moveTo(position: Vector3)
	local direction = (position - self._rootPart.Position).Unit
	self._callback(position, self._rootPart.Position + direction * 10)
end

function CustomSteering:jump()
	-- Handled by callback if needed
end

function CustomSteering:stop()
	self._callback(self._rootPart.Position, self._rootPart.Position + self._rootPart.CFrame.LookVector * 10)
end

function CustomSteering:destroy()
	-- No cleanup needed
end

return CustomSteering
