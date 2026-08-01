--!strict
--[[
    Custom Rig Example

    Demonstrates Custom steering mode for non-standard rigs using BodyVelocity.
    Shows how to implement arbitrary movement logic via the steering callback.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local parallel_path = require(ReplicatedStorage.Packages.ParallelPath)
local Agent = parallel_path.Agent
local Scheduler = parallel_path.Scheduler

-- Initialize the scheduler
Scheduler.init(4)

local rig = workspace.MyCustomRig
assert(rig, "Must have a rig model named 'MyCustomRig' in workspace")

-- Ensure the rig has a BodyVelocity for movement
local bodyVelocity = rig.PrimaryPart:FindFirstChild("BodyVelocity") or Instance.new("BodyVelocity")
if not bodyVelocity.Parent then
	bodyVelocity.Parent = rig.PrimaryPart
	bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bodyVelocity.Velocity = Vector3.new(0, 0, 0)
end

-- Optional: Humanoid for health/death (can be removed if not needed)
local humanoid: Humanoid? = rig:FindFirstChild("Humanoid") :: Humanoid?

-- Custom steering callback
-- Called every Heartbeat while the agent is moving to a waypoint
local function customSteering(targetPosition: Vector3, lookAtPosition: Vector3)
	local rigPos = rig.PrimaryPart.Position
	local direction = (targetPosition - rigPos)

	if direction.Magnitude > 0.1 then
		-- Smooth steering toward target with damping
		local speed = 20  -- Studs per second
		local desiredVelocity = direction.Unit * speed

		-- Apply a bit of damping for smoother movement
		bodyVelocity.Velocity = bodyVelocity.Velocity:Lerp(desiredVelocity, 0.1)

		-- Face the direction of movement (optional)
		rig.PrimaryPart.CFrame = rig.PrimaryPart.CFrame:Lerp(
			CFrame.lookAt(rigPos, targetPosition),
			0.05  -- Rotation speed
		)
	else
		-- At target, slow down
		bodyVelocity.Velocity = bodyVelocity.Velocity * 0.95
	end
end

-- Create the agent with Custom steering
local agent = Agent.new(rig, {
	steeringMode = "Custom",
	steeringCallback = customSteering,
	waypointReachedRadius = 2,
	recomputeOnBlock = true,
	maxRetries = 3,
})

-- Track movement
agent.Reached:Connect(function(model, waypoint)
	print("Rig reached destination at", waypoint.Position)
	bodyVelocity.Velocity = Vector3.new(0, 0, 0)  -- Stop
end)

agent.WaypointReached:Connect(function(model, from, to)
	print("Passed waypoint at", to.Position)
end)

agent.Blocked:Connect(function(model, waypoint)
	print("Path blocked, recomputing...")
end)

agent.Stuck:Connect(function(model)
	print("Rig is stuck!")
	-- Reset velocity and try again
	bodyVelocity.Velocity = Vector3.new(0, 0, 0)
end)

agent.Failed:Connect(function(model, reason)
	print("Movement failed:", reason)
	bodyVelocity.Velocity = Vector3.new(0, 0, 0)
end)

-- Movement loop
local function moveAround()
	local waypoints = {
		workspace.Point1.Position,
		workspace.Point2.Position,
		workspace.Point3.Position,
	}

	while rig.Parent do
		for _, waypoint in ipairs(waypoints) do
			print("Moving to", waypoint)
			agent:MoveTo(waypoint)
			agent.Reached:Wait()
			task.wait(2)
		end
	end
end

-- Optional: Handle death (if humanoid exists)
if humanoid then
	humanoid.Died:Connect(function()
		print("Rig died, stopping...")
		bodyVelocity.Velocity = Vector3.new(0, 0, 0)
		agent:Destroy()
	end)
end

-- Start movement
task.spawn(moveAround)

print("Custom rig initialized!")
