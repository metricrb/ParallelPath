--!strict
--[[
    6. MULTI-AGENT COORDINATION

    Multiple NPCs moving in parallel without blocking each other.
    Demonstrates the power of parallel pathfinding.
    Drop this in ServerScriptService.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local parallel_path = require(ReplicatedStorage.Packages.ParallelPath)
local Agent = parallel_path.Agent
local Scheduler = parallel_path.Scheduler

Scheduler.init(8)  -- More workers for more agents

-- Create multiple NPCs
local agents: { [number]: any } = {}
local npcCount = 5

for i = 1, npcCount do
	local npc = Instance.new("Model")
	npc.Name = "NPC_" .. i

	local humanoidRootPart = Instance.new("Part")
	humanoidRootPart.Name = "HumanoidRootPart"
	humanoidRootPart.Shape = Enum.PartType.Ball
	humanoidRootPart.Size = Vector3.new(2, 2, 1)
	humanoidRootPart.Color = Color3.fromHSV((i - 1) / npcCount, 0.7, 0.9)
	humanoidRootPart.CanCollide = true
	humanoidRootPart.Parent = npc
	npc.PrimaryPart = humanoidRootPart

	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = npc

	-- Spread them out
	npc:MoveTo(Vector3.new((i - 1) * 15, 5, 0))
	npc.Parent = workspace

	-- Create agent
	local agent = Agent.new(npc, {
		steeringMode = "Humanoid",
		maxRetries = 2,
	})

	table.insert(agents, {
		model = npc,
		agent = agent,
		waypoints = {
			Vector3.new((i - 1) * 15, 5, 0),
			Vector3.new((i - 1) * 15 + 30, 5, 50),
			Vector3.new((i - 1) * 15, 5, 100),
		},
		currentWaypoint = 1,
	})
end

-- Set up event handlers for each agent
for _, data in ipairs(agents) do
	local agent = data.agent
	local npcName = data.model.Name

	agent.Reached:Connect(function()
		data.currentWaypoint = (data.currentWaypoint % #data.waypoints) + 1
		print(npcName .. " reached destination, moving to next waypoint")
		task.wait(1)
		agent:MoveTo(data.waypoints[data.currentWaypoint])
	end)

	agent.WaypointReached:Connect(function()
		-- Silent
	end)

	agent.Stuck:Connect(function()
		print(npcName .. " is stuck!")
	end)

	agent.Failed:Connect(function(_, reason)
		print(npcName .. " failed:", reason)
	end)
end

-- Start all agents
print("Starting", npcCount, "agents in parallel...")
for _, data in ipairs(agents) do
	data.agent:MoveTo(data.waypoints[1])
end

-- Monitor overall progress
task.spawn(function()
	while true do
		task.wait(3)

		local statuses: { [string]: number } = {}
		for _, data in ipairs(agents) do
			local status = data.agent.Status
			statuses[status] = (statuses[status] or 0) + 1
		end

		local statusStr = ""
		for status, count in pairs(statuses) do
			statusStr = statusStr .. status .. ":" .. count .. " | "
		end

		print("Multi-Agent Status | " .. statusStr)
	end
end)

-- Cleanup on script unload
script.AncestryChanged:Connect(function()
	if script.Parent == nil then
		print("Cleaning up agents...")
		for _, data in ipairs(agents) do
			data.agent:Destroy()
		end
	end
end)
