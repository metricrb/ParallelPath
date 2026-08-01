# Migrating from SimplePath

This guide maps SimplePath concepts and patterns to parallel-path equivalents.

## API Comparison

| SimplePath | parallel-path | Notes |
|-----------|--------------|-------|
| `SimplePath.new()` | `Agent.new(model, config)` | Constructor signature changed |
| `path:Run(goal)` | `agent:MoveTo(goal)` | Returns cancellation function instead of void |
| `path.Reached` | `agent.Reached` | Same signal name, same callback args |
| `path.Waypoint` | `agent.WaypointReached` | Fired for each intermediate waypoint |
| `path.Blocked` | `agent.Blocked` | Fired when path is blocked |
| `path.Error` | `agent.Failed` | Renamed; includes reason codes |
| N/A | `agent.Stuck` | New signal for stuck detection |
| `path:Stop()` | `agent:Stop()` | Same |
| N/A | `agent:Pause()` / `agent:Resume()` | New pause/resume API |

## Code migration

### Basic movement

**SimplePath:**
```luau
local path = SimplePath.new(npc)
path:Run(target.Position)
path.Reached:Wait()
```

**parallel-path:**
```luau
local agent = Agent.new(npc, { steeringMode = "Humanoid" })
agent:MoveTo(target.Position)
agent.Reached:Wait()
```

### Error handling

**SimplePath:**
```luau
path.Error:Connect(function(error)
    if error == "NoPath" then
        print("No valid path")
    elseif error == "Compute" then
        print("Pathfinding error")
    end
end)
```

**parallel-path:**
```luau
agent.Failed:Connect(function(model, reason)
    if reason == "NoPath" then
        print("No valid path")
    elseif reason == "ComputationError" then
        print("Pathfinding error")
    elseif reason == "MaxRetriesExceeded" then
        print("Gave up after retries")
    end
end)
```

### Waypoint events

**SimplePath:**
```luau
path.Waypoint:Connect(function(waypoint)
    if waypoint.Action == Enum.PathWaypointAction.Jump then
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)
```

**parallel-path:**
```luau
agent.WaypointReached:Connect(function(model, from, to)
    if to.Action == Enum.PathWaypointAction.Jump then
        -- Jump is handled automatically by the steering controller
        print("About to jump at", to.Position)
    end
end)
```

Note: parallel-path handles jumps automatically via the steering controller. You don't need to manually call `ChangeState()`.

### Cancellation

**SimplePath:**
```luau
path:Stop()
```

**parallel-path:**
```luau
local cancel = agent:MoveTo(target)
cancel()  -- Same effect as agent:Stop()
```

Or use the agent directly:
```luau
agent:Stop()
```

## Behavior changes

### No more MoveToFinished stutter

**SimplePath**: Uses `Humanoid.MoveToFinished` event, which causes visible frame stutter as the server and client sync.

**parallel-path**: Uses Heartbeat distance-polling loop, eliminating stutter.

**Impact**: Your NPCs will move noticeably smoother.

### Stuck detection is now built-in

**SimplePath**: No built-in stuck detection; you had to implement it yourself.

**parallel-path**: Automatically detects if an agent hasn't moved in `stuckTimeout` seconds (default 3). Fires the `Stuck` signal and attempts recovery.

```luau
agent.Stuck:Connect(function(model)
    print("Agent detected as stuck")
end)
```

### Parallel computation

**SimplePath**: All path computations run on the main thread, blocking if many agents request paths at once.

**parallel-path**: Paths compute in parallel via Actors, dramatically improving performance with many agents.

**Required setup**:
```luau
local Scheduler = parallel_path.Scheduler
Scheduler.init(4)  -- Start the Actor pool once at game startup
```

### Multi-mode steering

**SimplePath**: Only supports humanoids.

**parallel-path**: Supports humanoids, vehicles (with PID control), and custom steering callbacks.

```luau
-- Vehicle mode
Agent.new(car, {
    steeringMode = "Vehicle",
    vehiclePID = { kp = 1.5, ki = 0, kd = 0.3 },
})

-- Custom mode
Agent.new(rig, {
    steeringMode = "Custom",
    steeringCallback = function(pos, lookAt)
        -- Your steering logic
    end,
})
```

## Configuration mapping

| SimplePath param | parallel-path param | Default | Notes |
|-----------------|-------------------|---------|-------|
| N/A | `steeringMode` | N/A | Required; choose "Humanoid", "Vehicle", or "Custom" |
| `Timeout` | `stuckTimeout` | 3 | Stuck detection timer (seconds) |
| `WaypointSpacing` | `agentParams.WaypointSpacing` | *(uses PathfindingService default)* | Configure via `agentParams` |
| N/A | `maxRetries` | 3 | Recomputation attempts |
| N/A | `recomputeOnBlock` | true | Automatic recomputation when blocked |
| N/A | `fallbackToDirectMove` | false | Steer directly if pathfinding fails |

## Feature parity

| Feature | SimplePath | parallel-path |
|---------|-----------|----------------|
| Humanoid pathfinding | ✓ | ✓ |
| Waypoint events | ✓ | ✓ |
| Jump waypoints | ✓ | ✓ (automatic) |
| Error signals | ✓ | ✓ (with more detail) |
| Stop/cancel | ✓ | ✓ |
| Pause/resume | ✗ | ✓ |
| Vehicle steering | ✗ | ✓ |
| Custom steering | ✗ | ✓ |
| Stuck detection | ✗ | ✓ |
| Parallel computation | ✗ | ✓ |

## Common patterns

### Patrol route

**SimplePath:**
```luau
while true do
    for _, waypoint in ipairs(patrolPoints) do
        path:Run(waypoint)
        path.Reached:Wait()
    end
end
```

**parallel-path:**
```luau
while true do
    for _, waypoint in ipairs(patrolPoints) do
        agent:MoveTo(waypoint)
        agent.Reached:Wait()
    end
end
```

### Chase player with timeout

**SimplePath:**
```luau
spawn(function()
    while character.Parent do
        path:Run(character.PrimaryPart.Position)
        task.wait(0.5)
    end
end)
```

**parallel-path:**
```luau
task.spawn(function()
    while character.Parent do
        if agent.Status == "Idle" or agent.Status == "Stuck" then
            agent:MoveTo(character.PrimaryPart.Position)
        end
        task.wait(0.5)
    end
end)
```

### Error recovery

**SimplePath:**
```luau
local function moveWithRetry(goal, maxRetries)
    local attempts = 0
    while attempts < maxRetries do
        path:Run(goal)
        local reached = false
        local errorOccurred = false

        path.Reached:Once(function() reached = true end)
        path.Error:Once(function() errorOccurred = true end)

        while not reached and not errorOccurred do
            task.wait()
        end

        if reached then
            return true
        end
        attempts = attempts + 1
        task.wait(1)
    end
    return false
end
```

**parallel-path:**
```luau
local function moveWithRetry(goal, maxRetries)
    local attempts = 0
    while attempts < maxRetries do
        local success = false
        agent:MoveTo(goal)

        agent.Reached:Once(function()
            success = true
        end)

        agent.Failed:Once(function()
            success = false
        end)

        while agent.Status == "Computing" or agent.Status == "Moving" do
            task.wait(0.1)
        end

        if success then
            return true
        end
        attempts = attempts + 1
        task.wait(1)
    end
    return false
end
```

Note: parallel-path's `maxRetries` config handles this automatically, so you may not need custom retry logic.

## Setup checklist

- [ ] Replace `SimplePath = require(...)` with `parallel_path = require(...)`
- [ ] Call `Scheduler.init()` once at game startup
- [ ] Change `SimplePath.new()` to `Agent.new(model, config)`
- [ ] Set `steeringMode = "Humanoid"` in config
- [ ] Update error handling from `.Error` to `.Failed(model, reason)`
- [ ] Test movement in your game
- [ ] Celebrate the smoother pathfinding! 🎉

## Performance expectations

- **Humanoid NPCs**: 2–3x smoother due to Heartbeat polling (no MoveToFinished stutter)
- **Many agents (10+)**: 5–10x faster with parallel computation
- **Vehicles**: New capability, much faster than humanoid pathfinding
- **Memory**: Slightly higher (Actors have overhead), but negligible for most games

## Troubleshooting

**Agent doesn't move:**
- Ensure `Scheduler.init()` was called before creating agents
- Check that the model has a `PrimaryPart` set
- Verify `steeringMode` is valid

**Agents stutter:**
- This shouldn't happen! If it does, check that you're using `steeringMode = "Humanoid"` and not some external MoveToFinished listener

**Stuck detection fires too often:**
- Increase `stuckTimeout` (e.g., 5 instead of 3)
- Adjust `waypointReachedRadius` to give more tolerance

**Vehicle doesn't steer correctly:**
- Tune `vehiclePID` values
- Ensure the VehicleSeat is properly configured and not occupied

---

See [Getting Started](../getting-started.md) and [API Reference](../api-reference.md) for more details.
