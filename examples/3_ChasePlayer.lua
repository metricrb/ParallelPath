--!strict
--[[
    3. CHASE PLAYER

    NPC chases the nearest player within detection range.
    Drop this in ServerScriptService.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local parallel_path = require(ReplicatedStorage.Packages.ParallelPath)
local Agent = parallel_path.Agent
local Scheduler = parallel_path.Scheduler

Scheduler.init(4)

-- Create enemy NPC
local enemy = Instance.new("Model")
enemy.Name = "Enemy"

local humanoidRootPart = Instance.new("Part")
humanoidRootPart.Name = "HumanoidRootPart"
humanoidRootPart.Shape = Enum.PartType.Ball
humanoidRootPart.Size = Vector3.new(2, 2, 1)
humanoidRootPart.Color = Color3.fromRGB(255, 0, 0)
humanoidRootPart.CanCollide = true
humanoidRootPart.Parent = enemy
enemy.PrimaryPart = humanoidRootPart

local humanoid = Instance.new("Humanoid")
humanoid.Parent = enemy

enemy:MoveTo(Vector3.new(0, 5, 0))
enemy.Parent = workspace

-- Create the agent
local agent = Agent.new(enemy, {
	steeringMode = "Humanoid",
	maxRetries = 2,
})

local chaseTarget: Model? = nil
local chaseDistance = 60  -- Detection radius
local lastUpdate = tick()

-- Update chase target
task.spawn(function()
	while enemy.Parent do
		local nearestPlayer: Model? = nil
		local shortestDistance = chaseDistance

		for _, player in ipairs(Players:GetPlayers()) do
			if player.Character and player.Character:FindFirstChild("Humanoid") then
				local character = player.Character
				local distance = (enemy.PrimaryPart.Position - character.PrimaryPart.Position).Magnitude
				if distance < shortestDistance then
					nearestPlayer = character
					shortestDistance = distance
				end
			end
		end

		chaseTarget = nearestPlayer
		task.wait(0.5)  -- Update target every half second
	end
end)

-- Chase loop
task.spawn(function()
	while enemy.Parent do
		if chaseTarget and chaseTarget.Parent then
			if agent.Status == "Idle" or agent.Status == "Stuck" then
				agent:MoveTo(chaseTarget.PrimaryPart.Position)
			end
			task.wait(0.3)
		else
			if agent.Status == "Moving" then
				agent:Stop()
			end
			task.wait(0.5)
		end
	end
end)

-- Handle events
agent.Reached:Connect(function()
	if chaseTarget then
		print("Reached target, continuing chase...")
		agent:MoveTo(chaseTarget.PrimaryPart.Position)
	end
end)

agent.Stuck:Connect(function()
	print("Enemy stuck, retrying...")
	if chaseTarget then
		agent:MoveTo(chaseTarget.PrimaryPart.Position)
	end
end)

agent.Failed:Connect(function(_, reason)
	print("Chase failed:", reason)
end)

print("Enemy spawned and ready to chase!")
