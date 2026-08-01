--!strict
--[[
    Humanoid NPC Example

    A simple AI-controlled NPC that patrols waypoints and chases nearby players.
    Demonstrates basic Agent setup, signal handling, and error recovery.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local parallel_path = require(ReplicatedStorage.Packages.ParallelPath)
local Agent = parallel_path.Agent
local Scheduler = parallel_path.Scheduler

-- Initialize the scheduler once at game startup
Scheduler.init(4)

local npc = workspace.MyNPC
assert(npc, "Must have an NPC named 'MyNPC' in workspace")
assert(npc:FindFirstChild("Humanoid"), "NPC must have a Humanoid")

-- Create the agent
local agent = Agent.new(npc, {
	steeringMode = "Humanoid",
	waypointReachedRadius = 2,
	recomputeOnBlock = true,
	maxRetries = 3,
	stuckTimeout = 3,
	stuckRecoveryJump = true,
})

-- Patrol waypoints
local patrolPoints = {
	workspace.Waypoint1.Position,
	workspace.Waypoint2.Position,
	workspace.Waypoint3.Position,
}

local currentPatrolIndex = 1
local chaseTarget: Model? = nil
local chaseDistance = 30

-- Track movement milestones
agent.Reached:Connect(function(model, waypoint)
	print(model.Name .. " reached waypoint at", waypoint.Position)
end)

agent.WaypointReached:Connect(function(model, from, to)
	if to.Action == Enum.PathWaypointAction.Jump then
		print("Jumping over obstacle at", to.Position)
	end
end)

agent.Blocked:Connect(function(model, blockedWaypoint)
	print("Path blocked at", blockedWaypoint.Position, "— recomputing...")
end)

agent.Stuck:Connect(function(model)
	print("Agent is stuck — attempting jump recovery")
end)

agent.Failed:Connect(function(model, reason)
	print("Movement failed:", reason)
	if reason == "NoPath" then
		print("Target is unreachable")
	elseif reason == "MaxRetriesExceeded" then
		print("Gave up after multiple recomputation attempts")
	end
end)

-- Patrol loop
local function patrol()
	while npc.Parent do
		if not chaseTarget then
			local waypoint = patrolPoints[currentPatrolIndex]
			print("Patrolling to waypoint", currentPatrolIndex)
			agent:MoveTo(waypoint)
			agent.Reached:Wait()

			currentPatrolIndex = (currentPatrolIndex % #patrolPoints) + 1
			task.wait(1)  -- Pause at waypoint
		else
			task.wait(0.1)
		end
	end
end

-- Chase nearby players
local function updateChaseTarget()
	while npc.Parent do
		local nearestPlayer: Model? = nil
		local shortestDistance = chaseDistance

		for _, player in ipairs(game.Players:GetPlayers()) do
			if player.Character and player.Character:FindFirstChild("Humanoid") then
				local character = player.Character
				local distance = (npc.PrimaryPart.Position - character.PrimaryPart.Position).Magnitude
				if distance < shortestDistance then
					nearestPlayer = character
					shortestDistance = distance
				end
			end
		end

		chaseTarget = nearestPlayer
		task.wait(0.5)  -- Update every half second
	end
end

-- Chase loop
local function chase()
	while npc.Parent do
		if chaseTarget and chaseTarget.Parent then
			if agent.Status == "Idle" or agent.Status == "Stuck" then
				agent:MoveTo(chaseTarget.PrimaryPart.Position)
			end
			task.wait(0.3)
		else
			task.wait(0.1)
		end
	end
end

-- Start all loops
task.spawn(patrol)
task.spawn(updateChaseTarget)
task.spawn(chase)

-- Cleanup on NPC death
npc.Humanoid.Died:Connect(function()
	print("NPC died, cleaning up...")
	agent:Destroy()
end)
