--!strict

type PIDConfig = {
	kp: number,
	ki: number,
	kd: number,
}

type VehicleSteering = {
	_seat: VehicleSeat,
	_rootPart: BasePart,
	_pidConfig: PIDConfig,
	_integral: number,
	_lastError: number,
	moveTo: (self: VehicleSteering, position: Vector3) -> (),
	jump: (self: VehicleSteering) -> (),
	stop: (self: VehicleSteering) -> (),
	destroy: (self: VehicleSteering) -> (),
	_updateSteering: (self: VehicleSteering, targetPos: Vector3) -> (),
}

local VehicleSteering = {}
VehicleSteering.__index = VehicleSteering

function VehicleSteering.new(model: Model, pidConfig: PIDConfig?): VehicleSteering
	local seat: VehicleSeat? = model:FindFirstChildOfClass("VehicleSeat") :: VehicleSeat?
	assert(seat, "Model must have a VehicleSeat")

	local rootPart = model.PrimaryPart
	assert(rootPart, "Model must have a PrimaryPart")

	local config = pidConfig or { kp = 1.5, ki = 0.0, kd = 0.3 }

	return setmetatable({
		_seat = seat,
		_rootPart = rootPart,
		_pidConfig = config,
		_integral = 0,
		_lastError = 0,
	} :: any, VehicleSteering) :: VehicleSteering
end

function VehicleSteering:_updateSteering(targetPos: Vector3)
	local rootCFrame = self._rootPart.CFrame
	local localTarget = rootCFrame:PointToObjectSpace(targetPos)

	if localTarget.Magnitude > 0 then
		local lateralError = math.clamp(localTarget.X / localTarget.Magnitude, -1, 1)

		self._integral = self._integral + lateralError
		local derivative = lateralError - self._lastError
		self._lastError = lateralError

		local steer = self._pidConfig.kp * lateralError
			+ self._pidConfig.ki * self._integral
			+ self._pidConfig.kd * derivative

		self._seat.Steer = math.clamp(steer, -1, 1)
		self._seat.Throttle = 1
	else
		self._seat.Throttle = 0
		self._seat.Steer = 0
	end
end

function VehicleSteering:moveTo(position: Vector3)
	self:_updateSteering(position)
end

function VehicleSteering:jump()
	-- Vehicles don't jump
end

function VehicleSteering:stop()
	self._seat.Throttle = -0.5
	self._seat.Steer = 0
end

function VehicleSteering:destroy()
	self._seat.Throttle = 0
	self._seat.Steer = 0
end

return VehicleSteering
