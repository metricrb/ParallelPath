# Parallel Path Computation

This guide explains how parallel-path uses Actors and Parallel Luau to compute paths without blocking gameplay.

## How it works

1. **Scheduler**: A singleton that manages a pool of Actor-isolated workers
2. **Agent**: Sends a compute request to the Scheduler, gets back a Promise
3. **Worker**: Runs `PathfindingService:ComputeAsync()` inside `task.desynchronize()` block
4. **Result**: Promise resolves with waypoints or rejects with an error

Since each worker is an Actor, they run in **parallel** (not concurrent on a single thread). Multiple agents can request paths simultaneously without blocking each other.

## Initialization

Call `Scheduler.init()` once at game startup:

```luau
local parallel_path = require(game:GetService("ReplicatedStorage").Packages.ParallelPath)
local Scheduler = parallel_path.Scheduler

Scheduler.init(4)  -- Start 4 worker Actors
```

### Choosing worker count

- **Default**: 4
- **Recommended**: Match your machine's logical CPU core count
- **Maximum**: 8 (diminishing returns beyond this)
- **Minimum**: 1 (works, but limits parallelism)

For a 4-core CPU: `Scheduler.init(4)`  
For an 8-core CPU: `Scheduler.init(8)`

**Roblox servers typically have 4–8 cores.**

## How requests are queued

1. `Agent:MoveTo()` calls `Scheduler.compute(request)`
2. Scheduler round-robins the request to an available worker
3. Worker receives the message and calls `PathfindingService:CreatePath()` inside `task.desynchronize()`
4. Worker sends back the result via BindableEvent
5. Scheduler resolves the Promise, Agent starts moving

### Desynchronization

The key to parallel computation is `task.desynchronize()`:

```luau
-- WorkerScript.server.luau (runs inside each Actor)
task.desynchronize()  -- Enter parallel execution
local path = PathfindingService:CreatePath(agentParams)
local ok = pcall(path.ComputeAsync, path, start, goal)
task.synchronize()    -- Re-enter serial execution before firing result
```

This allows multiple workers to compute paths simultaneously. Without it, all workers would serialize and block.

## Request queuing and timeouts

- **Requests queue across workers** — if all workers are busy, the new request waits for one to free up
- **Timeout**: 5 seconds per request. If no response, the Promise rejects with "ComputationError"

## Promise-based flow

```luau
Scheduler.compute(request)
    :andThen(function(waypoints)
        print("Path computed:", #waypoints, "waypoints")
        agent._waypoints = waypoints
        agent:_setStatus("Moving")
    end)
    :catch(function(error)
        print("Computation failed:", error)
        if error == "NoPath" then
            -- No valid path exists
        elseif error == "ComputationError" then
            -- Timeout or internal error
        end
    end)
```

## Performance impact

**Without parallel-path:**
- Main thread blocks for ~50–200ms during each `ComputeAsync()`
- If 5 agents request paths simultaneously, the game stalls for ~250–1000ms total

**With parallel-path:**
- Requests run in parallel; 5 agents finish in roughly the time of 1 (assuming 5+ workers)
- Main thread never blocks; Heartbeat continues uninterrupted

## GridBuilder (optional pre-baking)

For very large or complex maps, you can pre-bake a walkability grid to speed up pathfinding:

```luau
local GridBuilder = require(game:GetService("ReplicatedStorage").Packages.ParallelPath.GridBuilder)

local gridBuilder = GridBuilder.new(cellSize, scanHeight)
gridBuilder:build()  -- Scans the entire workspace once

-- Later, check if a position is walkable:
if gridBuilder:isWalkable(position) then
    -- Safe to navigate
end

-- Or find the nearest walkable cell:
local nearestWalkable = gridBuilder:getNearestWalkable(unreachablePosition)
```

This is **optional** and mainly useful if:
- Your map rarely changes
- You want to avoid expensive pathfinding queries
- You're doing a lot of waypoint validation

In most cases, raw `PathfindingService` is sufficient.

## Debugging parallel requests

Enable logging in Scheduler to see request round-robin:

```luau
-- (internal, not part of public API, but useful for investigation)
print("Worker " .. worker_index .. " got request " .. request.id)
print("Request computed:", #waypoints, "waypoints")
```

Check actor CPU usage with Roblox's built-in profiler (View → Profiler).

## Failover and error handling

If a worker crashes or becomes unresponsive:
1. The request times out after 5 seconds
2. Promise rejects with "ComputationError"
3. Agent retries the path (up to `maxRetries` times)

**Prevent infinite retry loops:**
```luau
local agent = Agent.new(model, {
    steeringMode = "Humanoid",
    maxRetries = 2,  -- Only 2 retries instead of 3
})
```

## Performance tips

1. **Limit concurrent agents**: If you have 100+ agents, consider batching their move requests over time instead of all at once
2. **Reuse paths when possible**: If multiple agents have the same start/goal, cache the result
3. **Tune agent parameters**: Smaller agent radius = finer, slower paths; larger = broader, faster paths
4. **Disable recomputeOnBlock in very dynamic environments**: Constant recomputation can queue many requests

**Example: Throttled NPC spawning**
```luau
local queue = {}
for i = 1, 100 do
    table.insert(queue, { model = models[i], target = target })
end

while #queue > 0 do
    for i = 1, math.min(4, #queue) do  -- Only 4 agents at a time
        local npc = queue[i]
        Agent.new(npc.model, { steeringMode = "Humanoid" }):MoveTo(npc.target)
    end
    task.wait(1)
    for i = 1, math.min(4, #queue) do
        table.remove(queue, 1)
    end
end
```

---

See also: [Failsafe Hierarchy](./failsafe-hierarchy.md)
