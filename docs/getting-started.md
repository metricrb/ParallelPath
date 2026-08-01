# Getting Started

## Installation

1. Add to your `wally.toml`:
```toml
[dependencies]
ParallelPath = "metricsrb/parallel-path@0.1"
```

2. Run `wally install`

3. Roblox Studio will sync the `Packages` folder

## Initialize the Scheduler

Call `Scheduler.init()` once when your game starts, ideally in a game-startup script:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local parallel_path = require(ReplicatedStorage.Packages.ParallelPath)
local Scheduler = parallel_path.Scheduler

Scheduler.init(4)  -- Start 4 worker Actors for parallel path computation
```

The `4` is the worker count — a good default is your logical CPU core count, capped at 8.

## Create an Agent

An Agent wraps a humanoid-based model and handles movement logic:

```luau
local Agent = parallel_path.Agent

local npc = workspace.MyNPC
local agent = Agent.new(npc, {
    steeringMode = "Humanoid",
})
```

## Move to a target

Call `:MoveTo()` with a position or a Part:

```luau
agent:MoveTo(workspace.Target.Position)
-- or
agent:MoveTo(workspace.Target)
```

## Listen for events

Connect to signals to react to movement milestones:

```luau
agent.Reached:Connect(function(model, finalWaypoint)
    print(model.Name .. " reached the target!")
end)

agent.WaypointReached:Connect(function(model, from, to)
    print("Passed waypoint at", to.Position)
end)

agent.Stuck:Connect(function(model)
    print("Agent is stuck, retrying...")
end)

agent.Failed:Connect(function(model, reason)
    print("Movement failed:", reason)
    -- Reasons: "NoPath", "ComputationError", "MaxRetriesExceeded", "AgentStuck", "AgentDestroyed"
end)
```

## Handle blocks

By default, parallel-path recomputes the path if `PathfindingService` fires `Path.Blocked`:

```luau
agent.Blocked:Connect(function(model, blockedWaypoint)
    print("Path was blocked at", blockedWaypoint.Position, "— recomputing...")
end)
```

To disable automatic recomputation:

```luau
local agent = Agent.new(npc, {
    steeringMode = "Humanoid",
    recomputeOnBlock = false,
})
```

## Stuck detection and recovery

If an Agent hasn't moved more than 0.5 studs for 3 seconds (default), it fires `Stuck` and attempts a recovery jump:

```luau
local agent = Agent.new(npc, {
    steeringMode = "Humanoid",
    stuckTimeout = 3,           -- Adjust sensitivity (seconds)
    stuckRecoveryJump = true,   -- Attempt a jump to unstick
})
```

Listen to the `Stuck` signal to log or implement custom recovery:

```luau
agent.Stuck:Connect(function(model)
    print(model.Name .. " got stuck — manual recovery needed")
    model.Humanoid.Sit = false  -- Ensure not sitting
    -- Could also move to a nearby spawn point
end)
```

## Stop, Pause, Resume

```luau
agent:Stop()     -- Halt immediately, clear waypoints, return to Idle
agent:Pause()    -- Suspend movement, retain waypoints
agent:Resume()   -- Resume from the paused waypoint
```

## Example: Patrol loop

```luau
local waypoints = {
    workspace.Waypoint1.Position,
    workspace.Waypoint2.Position,
    workspace.Waypoint3.Position,
}

local function patrol()
    for _, target in ipairs(waypoints) do
        agent:MoveTo(target)
        agent.Reached:Wait()
        task.wait(1)  -- Pause at each waypoint
    end
    patrol()  -- Loop forever
end

patrol()
```

## Example: Chase player

```luau
local player = game.Players:FindFirstChild("PlayerName")
local character = player.Character or player.CharacterAdded:Wait()

task.spawn(function()
    while character.Parent do
        if agent.Status == "Idle" or agent.Status == "Stuck" then
            agent:MoveTo(character.PrimaryPart.Position)
        end
        task.wait(0.5)  -- Update target every half-second
    end
end)
```

## Cleanup

When you're done with an Agent, call `:Destroy()`:

```luau
agent:Destroy()
```

This disconnects all signals and Heartbeat connections.

## Next steps

- **[Vehicle steering](./guides/vehicle-steering.md)** — PID-controlled cars
- **[Parallel computation](./guides/parallel-computation.md)** — How the Actor pool works
- **[Failsafe hierarchy](./guides/failsafe-hierarchy.md)** — Recovery strategies
- **[Migrating from SimplePath](./guides/migrating-from-simplepath.md)** — API mapping
