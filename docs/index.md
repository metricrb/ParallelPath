# parallel-path

> Parallel Luau pathfinding for humanoids, vehicles, and custom rigs. 

## Why parallel-path?

Other packages are great, but has a critical flaw: **MoveToFinished event causes visible stuttering** when the humanoid reaches waypoints. The event fires on the server after the client has already moved past the waypoint, creating a noticeable jitter.

**parallel-path solves this** by replacing MoveToFinished with a Heartbeat distance-polling loop, borrowed from Roblox's ClickToMove controller logic. This eliminates stutter entirely.

Beyond that, parallel-path offers:

- **Parallel path computation** via Actors + Parallel Luau. Compute multiple paths at once without blocking gameplay.
- **Multi-mode steering**: Humanoid rigs, vehicles with PID steering, or completely custom controllers.
- **Robust failsafes**: Automatic recomputation on block, stuck detection with recovery, fallback to direct movement.
- **No external dependencies**: Signal and Promise are bundled.

## Installation

Add to your `wally.toml`:

```toml
[dependencies]
ParallelPath = "valysia/parallel-path@0.1"
```

Then run `wally install`.

## Quick start

Create an NPC and move it to a target:

```luau
local parallel_path = require(game:GetService("ReplicatedStorage").parallel_path)
local Agent = parallel_path.Agent
local Scheduler = parallel_path.Scheduler

Scheduler.init(4)  -- Start with 4 worker Actors

local npc = workspace.MyNPC
local agent = Agent.new(npc, {
    steeringMode = "Humanoid",
    recomputeOnBlock = true,
    maxRetries = 3,
})

agent:MoveTo(workspace.Target.Position)

agent.Reached:Connect(function(model, waypoint)
    print("Reached target!")
end)

agent.Failed:Connect(function(model, reason)
    print("Failed to reach target:", reason)
end)
```

## Key features

### Heartbeat polling loop

Instead of listening to `MoveToFinished`, the Agent reads the humanoid's position every frame and compares it to the target waypoint. When distance < `waypointReachedRadius` (default 2 studs), the waypoint is marked reached and the next one is queued.

This eliminates the server-client sync delay that causes SimplePath to stutter.

### Parallel computation

Path computation now runs in Actor-isolated Parallel Luau, not blocking the main thread. Request multiple paths at once and get results as Promises resolve.

### Steering modes

- **Humanoid**: Direct `Humanoid:MoveTo()` calls
- **Vehicle**: PID-controlled lateral steering + throttle for VehicleSeats
- **Custom**: User-supplied callback for AnimationControllers, TweenService, BodyVelocity, etc.

### Failsafe hierarchy

If a path gets blocked or the agent gets stuck:

1. **Recompute** from current position (up to `maxRetries`)
2. If recompute fails, attempt **partial path** to nearest reachable node
3. If partial fails and `fallbackToDirectMove`, **steer directly** to target
4. If all fail, fire **Failed** signal with reason code

## API overview

### Scheduler

```luau
Scheduler.init(workerCount, parent)  -- Start the Actor pool once
Scheduler.compute(request) -> Promise<{PathWaypoint}>  -- Queue a path computation
Scheduler.destroy()  -- Clean up (tests only)
```

### Agent

```luau
local agent = Agent.new(model, config)

agent:MoveTo(target: Vector3 | BasePart) -> () -> ()  -- Return a cancel function
agent:Stop()    -- Halt and clear waypoints
agent:Pause()   -- Suspend, retain waypoints
agent:Resume()  -- Resume from current waypoint
agent:Destroy() -- Clean up

agent.Status  -- "Idle" | "Computing" | "Moving" | "Stuck" | "Paused"

agent.Reached:Connect(fn)        -- (model, waypoint)
agent.WaypointReached:Connect(fn)  -- (model, from, to)
agent.Blocked:Connect(fn)        -- (model, blockedWaypoint)
agent.Stuck:Connect(fn)          -- (model)
agent.Failed:Connect(fn)         -- (model, reason: FailReason)
```

### AgentConfig

```luau
{
    steeringMode = "Humanoid" | "Vehicle" | "Custom",  -- required
    steeringCallback = fn,  -- required if Custom mode

    agentParams = {...},                    -- PassPathfindingService.CreatePath() directly
    waypointReachedRadius = 2,              -- Default: 2 (Humanoid), 4 (Vehicle)
    recomputeOnBlock = true,                -- Recompute if path is blocked
    maxRetries = 3,                         -- Recomputation attempts
    vehiclePID = {kp=1.5, ki=0, kd=0.3},  -- Vehicle steering tuning
    stuckTimeout = 3,                       -- Seconds before marking stuck
    stuckRecoveryJump = true,               -- Jump when humanoid gets stuck
    fallbackToDirectMove = false,           -- Direct steer if path fails
    directMoveThreshold = 10,               -- Distance to use direct movement (studs)
    visualise = false,                      -- Debug viz (not yet implemented)
}
```

## Next steps

- [Getting Started](./getting-started.md) — Detailed walkthrough
- [API Reference](./api-reference.md) — All methods and types
- [Guides](./guides/) — Vehicle steering, parallel computation, failsafes, migration from SimplePath
- [Examples](./examples/) — Humanoid NPC, AI car, custom rig with BodyVelocity
