--!strict
--[[
    1. BASIC SETUP

    Minimal example to get parallel-path working.
    Drop this in ServerScriptService.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import the package
local parallel_path = require(ReplicatedStorage.Packages.ParallelPath)
local Agent = parallel_path.Agent
local Scheduler = parallel_path.Scheduler

-- Initialize the Scheduler once at game startup
-- This starts the Actor pool for parallel pathfinding
Scheduler.init(4)

-- Get or create a test NPC
local npc = workspace:FindFirstChild("TestNPC")
if not npc then
	npc = Instance.new("Model")
	npc.Name = "TestNPC"

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
end

-- Create an Agent for the NPC
local agent = Agent.new(npc, {
	steeringMode = "Humanoid",
})

print("Agent created. Status:", agent.Status)

-- Connect to signals
agent.Reached:Connect(function(model, waypoint)
	print(model.Name .. " reached target!")
end)

agent.Failed:Connect(function(model, reason)
	print("Movement failed:", reason)
end)

agent.WaypointReached:Connect(function(model, from, to)
	print("Passed waypoint, distance traveled:", (to.Position - from.Position).Magnitude)
end)

-- Start moving
print("Moving agent to 0, 5, 50...")
agent:MoveTo(Vector3.new(0, 5, 50))
