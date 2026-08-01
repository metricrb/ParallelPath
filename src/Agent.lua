--!strict

local Types = require(script.Parent.Types)
local Signal = require(script.Parent.lib.Signal)
local Promise = require(script.Parent.lib.Promise)
local Scheduler = require(script.Parent.Scheduler)
local HumanoidSteering = require(script.Parent.Steering.Humanoid)
local VehicleSteering = require(script.Parent.Steering.Vehicle)
local CustomSteering = require(script.Parent.Steering.Custom)

type AgentConfig = Types.AgentConfig
type FailReason = Types.FailReason
type AgentStatus = Types.AgentStatus
type ComputeRequest = Types.ComputeRequest

type Steering = any

type Agent = {
	Model: Model,
	Status: AgentStatus,
	Reached: Signal.Signal,
	WaypointReached: Signal.Signal,
	Blocked: Signal.Signal,
	Stuck: Signal.Signal,
	Failed: Signal.Signal,

	_config: AgentConfig,
	_steering: Steering,
	_waypoints: { PathWaypoint },
	_currentWaypoint: number,
	_status: AgentStatus,
	_lastPosition: Vector3,
	_stuckTimer: number,
	_retryCount: number,
	_currentGoal: Vector3?,
	_heartbeatConnection: RBXScriptConnection?,
	_blockConnection: RBXScriptConnection?,
	_destroyConnection: RBXScriptConnection?,
	_cancelled: boolean,

	MoveTo: (self: Agent, target: Vector3 | BasePart) -> (() -> ()),
	Stop: (self: Agent) -> (),
	Pause: (self: Agent) -> (),
	Resume: (self: Agent) -> (),
	Destroy: (self: Agent) -> (),
	_setStatus: (self: Agent, status: AgentStatus) -> (),
	_onHeartbeat: (self: Agent) -> (),
	_onPathBlocked: (self: Agent, blockedWaypoint: PathWaypoint) -> (),
	_recompute: (self: Agent) -> Promise.Promise<{ PathWaypoint }>,
	_checkStuck: (self: Agent) -> boolean,
	_advanceWaypoint: (self: Agent) -> (),
}

local Agent = {}
Agent.__index = Agent

function Agent.new(model: Model, config: AgentConfig): Agent
	assert(model, "Agent requires a model")
	assert(config, "Agent requires a config")
	assert(config.steeringMode, "Agent config requires steeringMode")
	assert(model.PrimaryPart, "Model must have a PrimaryPart")

	local rootPart = model.PrimaryPart
	rootPart.CanCollide = true
	pcall(function()
		rootPart:SetNetworkOwner(nil)
	end)

	local steering: Steering
	if config.steeringMode == "Humanoid" then
		steering = HumanoidSteering.new(model)
	elseif config.steeringMode == "Vehicle" then
		steering = VehicleSteering.new(model, config.vehiclePID)
	elseif config.steeringMode == "Custom" then
		assert(config.steeringCallback, "Custom steering requires steeringCallback")
		steering = CustomSteering.new(model, config.steeringCallback)
	else
		error("Unknown steeringMode: " .. config.steeringMode)
	end

	local self = setmetatable({
		Model = model,
		Status = "Idle",

		Reached = Signal.new(),
		WaypointReached = Signal.new(),
		Blocked = Signal.new(),
		Stuck = Signal.new(),
		Failed = Signal.new(),

		_config = config,
		_steering = steering,
		_waypoints = {},
		_currentWaypoint = 1,
		_status = "Idle",
		_lastPosition = rootPart.Position,
		_stuckTimer = 0,
		_retryCount = 0,
		_currentGoal = nil,
		_cancelled = false,
	} :: any, Agent) :: Agent

	self:_setStatus("Idle")

	self._heartbeatConnection = game:GetService("RunService").Heartbeat:Connect(function()
		self:_onHeartbeat()
	end)

	local humanoid = rootPart.Parent:FindFirstChildOfClass("Humanoid")
	if humanoid then
		self._destroyConnection = humanoid.Died:Connect(function()
			self:Failed:Fire(self.Model, "AgentDestroyed")
			self:Destroy()
		end)
	end

	if config.recomputeOnBlock ~= false then
		local path = PathfindingService:CreatePath(config.agentParams or {})
		self._blockConnection = path.Blocked:Connect(function(blockedWaypoint: PathWaypoint)
			self:_onPathBlocked(blockedWaypoint)
		end)
	end

	return self
end

function Agent:_setStatus(status: AgentStatus)
	self._status = status
	self.Status = status
end

function Agent:MoveTo(target: Vector3 | BasePart): () -> ()
	if self._status == "Idle" or self._status == "Stuck" then
		self:_setStatus("Computing")
		self._retryCount = 0

		local targetPos: Vector3
		if typeof(target) == "Instance" then
			local part = target :: BasePart
			targetPos = part.Position
		else
			targetPos = target :: Vector3
		end

		self._currentGoal = targetPos

		local directDist = (targetPos - self.Model.PrimaryPart.Position).Magnitude
		if self._config.fallbackToDirectMove and directDist < (self._config.directMoveThreshold or 10) then
			self._waypoints = {
				{
					Action = Enum.PathWaypointAction.NoAction,
					Position = self.Model.PrimaryPart.Position,
				},
				{
					Action = Enum.PathWaypointAction.NoAction,
					Position = targetPos,
				},
			}
			self._currentWaypoint = 2
			self:_setStatus("Moving")
			self._steering:moveTo(targetPos)
			return function()
				self:Stop()
			end
		end

		local computePromise = self:_recompute()

		local cancelled = false
		local connection: Signal.Connection
		connection = computePromise
			:andThen(function(waypoints: { PathWaypoint })
				if cancelled or self._cancelled then
					return
				end

				self._waypoints = waypoints
				self._currentWaypoint = 2

				if #self._waypoints > 1 then
					self:_setStatus("Moving")
					self._lastPosition = self.Model.PrimaryPart.Position
					self._stuckTimer = 0
					self._steering:moveTo(self._waypoints[2].Position)
				else
					self:Failed:Fire(self.Model, "NoPath")
					self:_setStatus("Idle")
				end
			end)
			:catch(function(error: string)
				if cancelled or self._cancelled then
					return
				end

				self._retryCount = self._retryCount + 1
				if self._retryCount < (self._config.maxRetries or 3) then
					local newPromise = self:_recompute()
					connection = newPromise
						:andThen(function(waypoints: { PathWaypoint })
							if cancelled or self._cancelled then
								return
							end
							self._waypoints = waypoints
							self._currentWaypoint = 2
							if #self._waypoints > 1 then
								self:_setStatus("Moving")
								self._lastPosition = self.Model.PrimaryPart.Position
								self._stuckTimer = 0
								self._steering:moveTo(self._waypoints[2].Position)
							else
								self:Failed:Fire(self.Model, "NoPath")
								self:_setStatus("Idle")
							end
						end)
						:catch(function()
							if not cancelled and not self._cancelled then
								self:Failed:Fire(self.Model, "MaxRetriesExceeded")
								self:_setStatus("Idle")
							end
						end)
				else
					self:Failed:Fire(self.Model, "MaxRetriesExceeded")
					self:_setStatus("Idle")
				end
			end)

		return function()
			cancelled = true
			self:Stop()
		end
	else
		return function() end
	end
end

function Agent:_recompute(): Promise.Promise<{ PathWaypoint }>
	local goal = self._currentGoal or self.Model.PrimaryPart.Position
	local request: ComputeRequest = {
		id = "",
		start = self.Model.PrimaryPart.Position,
		goal = goal,
		agentParams = self._config.agentParams,
	}

	return Scheduler.compute(request)
end

function Agent:_onHeartbeat()
	if self._status ~= "Moving" then
		return
	end

	local rootPart = self.Model.PrimaryPart
	local currentPos = rootPart.Position

	if self._currentWaypoint > #self._waypoints or #self._waypoints == 0 then
		if #self._waypoints > 0 then
			self:Reached:Fire(self.Model, self._waypoints[#self._waypoints])
		end
		self:_setStatus("Idle")
		self._steering:stop()
		return
	end

	local targetWaypoint = self._waypoints[self._currentWaypoint]
	local distToWaypoint = (currentPos - targetWaypoint.Position).Magnitude
	local reachedRadius = self._config.waypointReachedRadius or (self._config.steeringMode == "Vehicle" and 4 or 2)

	if distToWaypoint < reachedRadius then
		local prevWaypoint = self._currentWaypoint > 1 and self._waypoints[self._currentWaypoint - 1] or targetWaypoint
		self:WaypointReached:Fire(self.Model, prevWaypoint, targetWaypoint)

		if targetWaypoint.Action == Enum.PathWaypointAction.Jump then
			self._steering:jump()
		end

		self._currentWaypoint = self._currentWaypoint + 1

		if self._currentWaypoint > #self._waypoints then
			if #self._waypoints > 0 then
				self:Reached:Fire(self.Model, self._waypoints[#self._waypoints])
			end
			self:_setStatus("Idle")
			self._steering:stop()
		else
			self._lastPosition = currentPos
			self._stuckTimer = 0
			self._steering:moveTo(self._waypoints[self._currentWaypoint].Position)
		end

		return
	end

	if self:_checkStuck() then
		self:Stuck:Fire(self.Model)
		self:_setStatus("Stuck")
		self._steering:stop()

		if self._config.stuckRecoveryJump ~= false and self._config.steeringMode == "Humanoid" then
			task.defer(function()
				self._steering:jump()
				task.wait(0.2)
				if self._status == "Stuck" then
					self:MoveTo(self._waypoints[#self._waypoints].Position)
				end
			end)
		else
			self:Failed:Fire(self.Model, "AgentStuck")
			self:_setStatus("Idle")
		end
	end
end

function Agent:_checkStuck(): boolean
	local currentPos = self.Model.PrimaryPart.Position
	local movement = (currentPos - self._lastPosition).Magnitude
	local stuckTimeout = self._config.stuckTimeout or 3

	if movement < 0.5 then
		self._stuckTimer = self._stuckTimer + (1 / 60)
		if self._stuckTimer >= stuckTimeout then
			return true
		end
	else
		self._stuckTimer = 0
	end

	self._lastPosition = currentPos
	return false
end

function Agent:_onPathBlocked(blockedWaypoint: PathWaypoint)
	if self._status ~= "Moving" then
		return
	end

	self:Blocked:Fire(self.Model, blockedWaypoint)

	if self._config.recomputeOnBlock ~= false then
		self._retryCount = 0
		local _ = self:_recompute()
			:andThen(function(waypoints: { PathWaypoint })
				if self._status == "Moving" and #waypoints > 1 then
					self._waypoints = waypoints
					self._currentWaypoint = 2
					self._lastPosition = self.Model.PrimaryPart.Position
					self._stuckTimer = 0
					self._steering:moveTo(self._waypoints[2].Position)
				end
			end)
			:catch(function()
				-- Recompute failed; let stuck detection or manual retry handle it
			end)
	end
end

function Agent:_advanceWaypoint()
	if self._currentWaypoint < #self._waypoints then
		self._currentWaypoint = self._currentWaypoint + 1
		if self._currentWaypoint <= #self._waypoints then
			self._steering:moveTo(self._waypoints[self._currentWaypoint].Position)
		end
	end
end

function Agent:Stop()
	if self._status ~= "Idle" then
		self:_setStatus("Idle")
		self._waypoints = {}
		self._currentWaypoint = 1
		self._stuckTimer = 0
		self._steering:stop()
	end
end

function Agent:Pause()
	if self._status == "Moving" then
		self:_setStatus("Paused")
		self._steering:stop()
	end
end

function Agent:Resume()
	if self._status == "Paused" and #self._waypoints > 0 then
		self:_setStatus("Moving")
		if self._currentWaypoint <= #self._waypoints then
			self._steering:moveTo(self._waypoints[self._currentWaypoint].Position)
		end
	end
end

function Agent:Destroy()
	self._cancelled = true
	self:Stop()

	if self._heartbeatConnection then
		self._heartbeatConnection:Disconnect()
	end
	if self._blockConnection then
		self._blockConnection:Disconnect()
	end
	if self._destroyConnection then
		self._destroyConnection:Disconnect()
	end

	self._steering:destroy()

	self.Reached:Destroy()
	self.WaypointReached:Destroy()
	self.Blocked:Destroy()
	self.Stuck:Destroy()
	self.Failed:Destroy()
end

return Agent
