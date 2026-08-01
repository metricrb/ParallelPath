--!strict
--[[
    7. ERROR HANDLING & FAILSAFES

    Demonstrating all error handling patterns and recovery strategies.
    Drop this in ServerScriptService.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local parallel_path = require(ReplicatedStorage.Packages.ParallelPath)
local Agent = parallel_path.Agent
local Scheduler = parallel_path.Scheduler

Scheduler.init(4)

-- Create NPC
local npc = Instance.new("Model")
npc.Name = "RobustNPC"

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

-- Create agent with all failsafes enabled
local agent = Agent.new(npc, {
	steeringMode = "Humanoid",
	recomputeOnBlock = true,      -- Auto-recompute if path blocked
	maxRetries = 3,                -- Try up to 3 times
	stuckTimeout = 3,              -- Mark stuck after 3 seconds no movement
	stuckRecoveryJump = true,      -- Jump to recover
	fallbackToDirectMove = false,  -- Don't mask path failures
	maxRetries = 3,
})

-- Statistics
local stats = {
	attemptedMoves = 0,
	successfulMoves = 0,
	failedMoves = 0,
	blockedCount = 0,
	stuckCount = 0,
	lastError = nil,
}

-- REACHED: Movement completed successfully
agent.Reached:Connect(function(model, waypoint)
	print("✓ SUCCESS: Reached target")
	stats.successfulMoves = stats.successfulMoves + 1
	stats.lastError = nil
end)

-- WAYPOINT REACHED: Intermediate waypoint passed
agent.WaypointReached:Connect(function(model, from, to)
	print("→ Waypoint passed at", to.Position)
end)

-- BLOCKED: Path was blocked, attempting recompute
agent.Blocked:Connect(function(model, blockedWaypoint)
	print("⚠ WARNING: Path blocked at", blockedWaypoint.Position)
	stats.blockedCount = stats.blockedCount + 1
	print("  Auto-recomputing path...")
end)

-- STUCK: Agent detected as stuck
agent.Stuck:Connect(function(model)
	print("⚠ WARNING: Agent stuck")
	stats.stuckCount = stats.stuckCount + 1
	print("  Attempting recovery jump...")
end)

-- FAILED: All recovery strategies exhausted
agent.Failed:Connect(function(model, reason)
	print("✗ FAILURE: Movement failed")
	stats.failedMoves = stats.failedMoves + 1
	stats.lastError = reason

	-- Detailed failure analysis
	if reason == "NoPath" then
		print("  Reason: No valid path exists from start to goal")
		print("  Action: Try a closer target or clear obstacles")
	elseif reason == "ComputationError" then
		print("  Reason: Pathfinding service timeout")
		print("  Action: Try again after a delay")
	elseif reason == "MaxRetriesExceeded" then
		print("  Reason: Too many path blocks/failures")
		print("  Action: Environment may be too dynamic")
	elseif reason == "AgentStuck" then
		print("  Reason: Agent could not recover from stuck state")
		print("  Action: Manually move NPC or clear area")
	elseif reason == "AgentDestroyed" then
		print("  Reason: Model was destroyed")
		print("  Action: Agent cleanup complete")
	end
end)

-- Utility function: Move with retry
local function moveWithRetry(target: Vector3, maxAttempts: number)
	print("\n[MOVE REQUEST] Target:", target, "| Max attempts:", maxAttempts)
	stats.attemptedMoves = stats.attemptedMoves + 1

	local attempt = 0
	local function tryMove()
		attempt = attempt + 1
		print("Attempt", attempt .. "/" .. maxAttempts)

		if attempt > maxAttempts then
			print("Failed after", maxAttempts, "attempts")
			return false
		end

		local done = false
		local success = false

		agent.Reached:Once(function()
			success = true
			done = true
		end)

		agent.Failed:Once(function()
			done = true
		end)

		agent:MoveTo(target)

		-- Wait for result
		while not done do
			task.wait(0.1)
		end

		if success then
			return true
		else
			task.wait(2)  -- Wait before retry
			return tryMove()
		end
	end

	return tryMove()
end

-- Test scenarios
print("=== PARALLEL-PATH ERROR HANDLING TEST ===\n")

-- Test 1: Simple move
print("TEST 1: Simple move")
moveWithRetry(Vector3.new(0, 5, 50), 1)
task.wait(3)

-- Test 2: Move with potential blocks
print("\nTEST 2: Move with auto-recompute on block")
moveWithRetry(Vector3.new(50, 5, 50), 2)
task.wait(3)

-- Test 3: Move with stuck recovery
print("\nTEST 3: Move with stuck detection")
moveWithRetry(Vector3.new(0, 5, 0), 1)
task.wait(3)

-- Print final statistics
print("\n=== STATISTICS ===")
print("Attempted moves:", stats.attemptedMoves)
print("Successful:", stats.successfulMoves)
print("Failed:", stats.failedMoves)
print("Path blocks:", stats.blockedCount)
print("Stuck detections:", stats.stuckCount)
if stats.lastError then
	print("Last error:", stats.lastError)
end
