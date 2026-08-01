# Failsafe Hierarchy

This guide explains what happens when pathfinding fails or the path is blocked, and how parallel-path recovers.

## The decision tree

```
Agent:MoveTo() called
  ↓
[Computing phase]
  → Path succeeds? → Move to "Moving" phase ✓
  → Path fails (NoPath, timeout, etc.)?
      ↓
      [Recompute] (up to maxRetries times)
        → Success? → Move to "Moving" ✓
        → Still failing? 
            ↓
            [Fallback strategies]
              → fallbackToDirectMove enabled?
                  → Yes: Ignore waypoints, steer directly to target ✓
                  → No: Fire Failed signal ✗

[Moving phase]
  → Path.Blocked fires?
      ↓
      [Recompute] (if recomputeOnBlock = true)
        → Success? → Continue with new waypoints ✓
        → Still failing? → Check stuck detection
  → Stuck detected?
      ↓
      [Stuck recovery]
        → stuckRecoveryJump enabled?
            → Yes: Attempt jump, retry from stuck point
            → No: Fire Stuck signal, then Failed ✗
  → Waypoint reached? → Advance to next waypoint ✓
  → Final waypoint reached? → Fire Reached, set Idle ✓
```

## Configuration

### recomputeOnBlock

**Default**: `true`

If `true`, automatically recompute the path when `Path.Blocked` fires (e.g., dynamic obstacles in the way).

```luau
Agent.new(model, {
    steeringMode = "Humanoid",
    recomputeOnBlock = true,  -- Recompute on block
})
```

**When to disable** (`recomputeOnBlock = false`):
- Your environment is extremely dynamic (paths constantly blocked)
- Recomputation is expensive and you'd rather accept the block than retry
- You want to handle blocks manually:

```luau
agent.Blocked:Connect(function(model, waypoint)
    print("Path blocked, doing custom recovery...")
    -- Teleport, wait, or take alternate route
end)
```

### maxRetries

**Default**: `3`

Maximum number of recomputation attempts before giving up. Each failed attempt fires the `Blocked` signal (or is handled internally if recomputeOnBlock = true).

```luau
Agent.new(model, {
    steeringMode = "Humanoid",
    maxRetries = 3,  -- Try up to 3 times
})
```

After maxRetries, the `Failed` signal fires with reason `"MaxRetriesExceeded"`.

### fallbackToDirectMove

**Default**: `false`

If `true`, and pathfinding fails, the Agent will steer directly toward the target, ignoring waypoints. This bypasses pathfinding entirely — useful for short distances or if you prefer a "best effort" approach over precise navigation.

```luau
Agent.new(model, {
    steeringMode = "Humanoid",
    fallbackToDirectMove = true,
    directMoveThreshold = 10,  -- Only use direct move if distance < 10 studs
})
```

**Trade-offs:**
- **Pro**: Guarantees movement, never fully fails
- **Con**: May walk through obstacles or off cliffs

Use sparingly. Better for indoor, simple environments.

### stuckTimeout and stuckRecoveryJump

**stuckTimeout default**: `3` seconds

**stuckRecoveryJump default**: `true` (Humanoid mode only)

If the Agent doesn't move more than 0.5 studs in `stuckTimeout` seconds, it's considered stuck:

```luau
Agent.new(model, {
    steeringMode = "Humanoid",
    stuckTimeout = 3,           -- 3 seconds with no movement
    stuckRecoveryJump = true,   -- Attempt a jump
})
```

If `stuckRecoveryJump = true`:
1. The `Stuck` signal fires
2. The Agent attempts a jump
3. Waits 0.2 seconds, then retries the path

If `stuckRecoveryJump = false`:
1. The `Stuck` signal fires
2. The `Failed` signal immediately fires with reason `"AgentStuck"`

**Humanoid specific**: Vehicles and Custom steering ignore `stuckRecoveryJump`.

## Handling failures in your code

### Listen to all signals

```luau
agent.Failed:Connect(function(model, reason)
    print("Movement failed:", reason)
end)

agent.Blocked:Connect(function(model, waypoint)
    print("Path blocked at", waypoint.Position)
end)

agent.Stuck:Connect(function(model)
    print("Agent is stuck")
end)
```

### Retry with custom logic

```luau
local function moveWithRetry(agent, target, maxAttempts)
    for attempt = 1, maxAttempts do
        local cancel = agent:MoveTo(target)

        local reached = false
        local failed = false

        agent.Reached:Once(function()
            reached = true
        end)

        agent.Failed:Once(function(model, reason)
            failed = true
            print("Attempt " .. attempt .. " failed:", reason)
        end)

        -- Wait for outcome
        while not reached and not failed do
            task.wait(0.1)
        end

        if reached then
            return true
        elseif attempt < maxAttempts then
            task.wait(2)  -- Wait before retry
        end
    end

    return false
end

local success = moveWithRetry(agent, target, 5)
if not success then
    print("Failed after 5 attempts")
end
```

### Fallback strategies

```luau
local function moveWithFallback(agent, target)
    local cancel = agent:MoveTo(target)

    local result = nil

    agent.Reached:Once(function()
        result = "success"
    end)

    agent.Failed:Once(function(model, reason)
        if reason == "NoPath" then
            result = "nopath"
        else
            result = "error"
        end
    end)

    while not result do
        task.wait(0.1)
    end

    if result == "success" then
        return true
    elseif result == "nopath" then
        -- No valid path; try a closer intermediate waypoint
        print("No direct path; trying waypoint")
        agent:MoveTo(findNearestWaypoint(agent.Model, target))
        agent.Reached:Wait()
        return true
    else
        -- Unknown error; log and abort
        print("Movement failed with error")
        return false
    end
end
```

## Decision matrix

| Scenario | recomputeOnBlock | maxRetries | fallbackToDirectMove | Result |
|----------|-----------------|-----------|----------------------|--------|
| Normal path | N/A | N/A | N/A | Success, Reached fires |
| Temporary obstacle | true | 3 | false | Recomputes, continues |
| Persistent obstacle | true | 3 | false | Fails after 3 retries |
| Persistent obstacle | true | 3 | true | Falls back to direct move |
| Dynamic environment | false | 3 | false | Blocks once, Blocked signal fires |
| No path exists | any | any | true | Falls back to direct move |
| No path + far away | any | any | false | Fails immediately |
| Stuck humanoid | any | any | any | Attempts jump, retries |

## Performance considerations

1. **Frequent recomputation**: If your environment is very dynamic and blocks happen often, `recomputeOnBlock = true` can cause many path requests. Consider disabling it and handling blocks manually.

2. **Stuck detection tuning**: If agents frequently get stuck in normal terrain, increase `stuckTimeout` or disable `stuckRecoveryJump` to let them recover naturally.

3. **Direct move fallback**: Enabling `fallbackToDirectMove` means pathfinding failures become invisible but may cause collision issues. Test thoroughly.

## Example: Robust AI with all fallbacks

```luau
local Agent = parallel_path.Agent

local npc = workspace.MyNPC
local agent = Agent.new(npc, {
    steeringMode = "Humanoid",
    recomputeOnBlock = true,        -- Retry on obstacles
    maxRetries = 3,                 -- Up to 3 retries
    fallbackToDirectMove = false,   -- Don't mask path failures
    stuckTimeout = 4,               -- Generous stuck timeout
    stuckRecoveryJump = true,       -- Try to jump out
})

agent.Reached:Connect(function()
    print("Destination reached!")
end)

agent.Blocked:Connect(function(model, waypoint)
    print("Path blocked, attempting recomputation...")
end)

agent.Stuck:Connect(function(model)
    print("Agent stuck, attempting jump...")
end)

agent.Failed:Connect(function(model, reason)
    print("Movement failed:", reason)
    if reason == "NoPath" then
        print("Target is unreachable")
    elseif reason == "MaxRetriesExceeded" then
        print("Gave up after 3 recomputation attempts")
    elseif reason == "AgentStuck" then
        print("Could not recover from stuck state")
    end
end)

agent:MoveTo(workspace.Target)
```

---

See also: [Parallel Computation](./parallel-computation.md), [Vehicle Steering](./vehicle-steering.md)
