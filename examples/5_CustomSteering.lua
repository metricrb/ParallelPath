--!strict
--[[
    5. CUSTOM STEERING

    Floating orb using custom steering with BodyVelocity.
    Drop this in ServerScriptService.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local parallel_path = require(ReplicatedStorage.Packages.ParallelPath)
local Agent = parallel_path.Agent
local Scheduler = parallel_path.Scheduler

Scheduler.init(4)

-- Create a floating orb
local orb = Instance.new("Model")
orb.Name = "FloatingOrb"

local body = Instance.new("Part")
body.Name = "Body"
body.Shape = Enum.PartType.Ball
body.Size = Vector3.new(2, 2, 2)
body.Color = Color3.fromRGB(0, 255, 100)
body.CanCollide = false
body.Parent = orb
orb.PrimaryPart = body

-- Add BodyVelocity for smooth movement
local bodyVelocity = Instance.new("BodyVelocity")
bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
bodyVelocity.Velocity = Vector3.new(0, 0, 0)
bodyVelocity.Parent = body

orb:MoveTo(Vector3.new(0, 10, 0))
orb.Parent = workspace

-- Custom steering callback
local function orbSteering(targetPosition: Vector3, lookAtPosition: Vector3)
	local orbPos = body.Position
	local direction = (targetPosition - orbPos)

	if direction.Magnitude > 0.1 then
		-- Smooth acceleration toward target
		local speed = 25  -- Studs per second
		local desiredVelocity = direction.Unit * speed

		-- Lerp for smooth acceleration
		bodyVelocity.Velocity = bodyVelocity.Velocity:Lerp(desiredVelocity, 0.1)

		-- Rotate to face direction (optional)
		body.CFrame = body.CFrame:Lerp(
			CFrame.lookAt(orbPos, targetPosition),
			0.05
		)
	else
		-- Decelerate when near target
		bodyVelocity.Velocity = bodyVelocity.Velocity * 0.9
	end
end

-- Create the agent with custom steering
local agent = Agent.new(orb, {
	steeringMode = "Custom",
	steeringCallback = orbSteering,
	waypointReachedRadius = 3,
	recomputeOnBlock = true,
})

-- Define flight path
local waypoints = {
	Vector3.new(0, 10, 0),
	Vector3.new(50, 15, 0),
	Vector3.new(50, 15, 50),
	Vector3.new(0, 15, 50),
	Vector3.new(0, 20, 0),
}

local currentWaypoint = 1

agent.Reached:Connect(function()
	print("Orb reached waypoint", currentWaypoint)
	currentWaypoint = (currentWaypoint % #waypoints) + 1
	task.wait(1)
	agent:MoveTo(waypoints[currentWaypoint])
end)

agent.WaypointReached:Connect(function()
	print("Passed intermediate waypoint")
end)

agent.Stuck:Connect(function()
	print("Orb stuck, retrying...")
	agent:MoveTo(waypoints[currentWaypoint])
end)

agent.Failed:Connect(function(_, reason)
	print("Flight failed:", reason)
end)

-- Start flying
print("Orb initialized, starting flight path...")
agent:MoveTo(waypoints[1])

-- Display flight status
task.spawn(function()
	while orb.Parent do
		local speed = bodyVelocity.Velocity.Magnitude
		print(string.format("Orb | Height: %.1f | Speed: %.1f | Status: %s", body.Position.Y, speed, agent.Status))
		task.wait(2)
	end
end)
