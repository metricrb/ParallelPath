--!strict

type HumanoidSteering = {
	_humanoid: Humanoid,
	_rootPart: BasePart,
	moveTo: (self: HumanoidSteering, position: Vector3) -> (),
	jump: (self: HumanoidSteering) -> (),
	stop: (self: HumanoidSteering) -> (),
	destroy: (self: HumanoidSteering) -> (),
}

local HumanoidSteering = {}
HumanoidSteering.__index = HumanoidSteering

function HumanoidSteering.new(model: Model): HumanoidSteering
	local humanoid: Humanoid? = model:FindFirstChild("Humanoid") :: Humanoid?
	assert(humanoid and humanoid:IsA("Humanoid"), "Model must have a Humanoid")

	local rootPart = model.PrimaryPart
	assert(rootPart, "Model must have a PrimaryPart")

	return setmetatable({
		_humanoid = humanoid,
		_rootPart = rootPart,
	} :: any, HumanoidSteering) :: HumanoidSteering
end

function HumanoidSteering:moveTo(position: Vector3)
	self._humanoid:MoveTo(position)
end

function HumanoidSteering:jump()
	local ok = pcall(function()
		if self._humanoid:GetState() ~= Enum.HumanoidStateType.Jumping
			and self._humanoid:GetState() ~= Enum.HumanoidStateType.Freefall
		then
			self._humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end)
end

function HumanoidSteering:stop()
	self._humanoid:MoveTo(self._rootPart.Position)
end

function HumanoidSteering:destroy()
	-- No cleanup needed
end

return HumanoidSteering
