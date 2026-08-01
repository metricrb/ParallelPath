--!strict
--[[
    2. PATROL BEHAVIOR

    NPC patrols between waypoints in a loop.
    Drop this in ServerScriptService.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local parallel_path = require(ReplicatedStorage.Packages.ParallelPath)
local Agent = parallel_path.Agent
local Scheduler = parallel_path.Scheduler

Scheduler.init(4)

-- Create a simple NPC
local npc = Instance.new("Model")
npc.Name = "PatrolNPC"

local humanoidRootPart = Instance.new("Part")
humanoidRootPart.Name = "HumanoidRootPart"
humanoidRootPart.Shape = Enum.PartType.Ball
humanoidRootPart.Size = Vector3.new(2, 2, 1)
humanoidRootPart.CanCollide = true
humanoidRootPart.Parent = npc
npc.PrimaryPart = humanoidRootPart

local humanoid = Instance.new("Humanoid")
humanoid.Parent = npc

npc:MoveTo(Vector3.new(0, 5, 0))
npc.Parent = workspace

-- Create the agent
local agent = Agent.new(npc, {
	steeringMode = "Humanoid",
	recomputeOnBlock = true,
	maxRetries = 3,
})

-- Define patrol waypoints
local patrolPoints = {
	Vector3.new(0, 5, 0),
	Vector3.new(50, 5, 0),
	Vector3.new(50, 5, 50),
	Vector3.new(0, 5, 50),
}

local currentWaypoint = 1
local paused = false

agent.Reached:Connect(function()
	print("Reached waypoint", currentWaypoint)
	task.wait(2)  -- Pause at each waypoint
	currentWaypoint = (currentWaypoint % #patrolPoints) + 1
	agent:MoveTo(patrolPoints[currentWaypoint])
end)

agent.Stuck:Connect(function()
	print("NPC got stuck, retrying...")
	agent:MoveTo(patrolPoints[currentWaypoint])
end)

agent.Failed:Connect(function(_, reason)
	print("Movement failed:", reason, "- retrying...")
	task.wait(1)
	agent:MoveTo(patrolPoints[currentWaypoint])
end)

-- Start patrol
print("Starting patrol...")
agent:MoveTo(patrolPoints[1])

-- Optional: Listen for player input to pause/resume
local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.Space then
		if paused then
			agent:Resume()
			paused = false
			print("Patrol resumed")
		else
			agent:Pause()
			paused = true
			print("Patrol paused")
		end
	end
end)
