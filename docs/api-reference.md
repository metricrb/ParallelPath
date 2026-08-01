# API Reference

## Scheduler

Manages a pool of Actor-based workers for parallel pathfinding.

### Scheduler.init(workerCount?, parent?)

Initialize the global Scheduler with a worker pool.

**Parameters:**
- `workerCount: number?` — Count of Actor workers (default: 4). Recommended: match logical CPU cores, capped at 8.
- `parent: Instance?` — Parent folder for worker Actors (default: creates a folder in Workspace named "PathfindingWorkers")

**Returns:** nothing

**Example:**
```luau
Scheduler.init(4)  -- 4 workers under workspace.PathfindingWorkers

-- or custom parent:
local customFolder = Instance.new("Folder")
customFolder.Name = "MyPathfinding"
customFolder.Parent = ServerStorage
Scheduler.init(4, customFolder)
```

### Scheduler.compute(request: ComputeRequest) -> Promise

Submit a pathfinding request to be computed in parallel.

**Parameters:**
- `request: ComputeRequest` — A table with:
  - `id: string` — Auto-populated, ignore
  - `start: Vector3` — Starting position
  - `goal: Vector3` — Target position
  - `agentParams: AgentParameters?` — PathfindingService.CreatePath() parameters

**Returns:** `Promise<{PathWaypoint}>` that resolves with the waypoint list or rejects with an error string.

**Timeout:** 5 seconds (rejects "ComputationError" if no response)

**Example:**
```luau
local request = {
    start = npc.PrimaryPart.Position,
    goal = target.Position,
    agentParams = {
        AgentRadius = 2,
        AgentHeight = 5,
        WaypointSpacing = 8,
    },
}

Scheduler.compute(request)
    :andThen(function(waypoints)
        print("Path computed:", #waypoints, "waypoints")
    end)
    :catch(function(error)
        print("Path failed:", error)
    end)
```

### Scheduler.destroy()

Clean up all worker Actors and internal state. **For tests only** — do not call during gameplay.

---

## Agent

The main pathfinding controller. Wraps a model and drives movement via one of three steering modes.

### Agent.new(model: Model, config: AgentConfig) -> Agent

Create a new Agent for a model.

**Parameters:**
- `model: Model` — Must have a `PrimaryPart` set. Ownership is claimed (network owner set to nil).
- `config: AgentConfig` — Configuration table (see below)

**Returns:** `Agent` instance

**Example:**
```luau
local npc = workspace.MyNPC
local agent = Agent.new(npc, {
    steeringMode = "Humanoid",
    waypointReachedRadius = 2,
    maxRetries = 3,
})
```

### agent:MoveTo(target: Vector3 | BasePart) -> () -> ()

Begin moving to a target position or Part.

**Parameters:**
- `target: Vector3 | BasePart` — Destination (or Part whose Position is the destination)

**Returns:** A cancel function. Call it to stop the movement immediately.

**State changes:**
1. Sets Status to "Computing"
2. Queues a path computation via Scheduler
3. On success: sets Status to "Moving", queues waypoints, starts Heartbeat loop
4. On failure: fires Failed signal, retries up to maxRetries

**Example:**
```luau
local cancel = agent:MoveTo(workspace.Target)

-- Later, if you need to cancel:
cancel()  -- Stops immediately
```

### agent:Stop()

Halt movement and clear waypoints. Sets Status to "Idle".

**Example:**
```luau
agent:Stop()
```

### agent:Pause()

Suspend movement while retaining waypoints. Sets Status to "Paused".

**Example:**
```luau
agent:Pause()
task.wait(3)
agent:Resume()
```

### agent:Resume()

Resume movement from the paused waypoint. Only works if Status is "Paused".

**Example:**
```luau
agent:Resume()
```

### agent:Destroy()

Clean up all connections and signals. Call when you're done with the Agent.

**Example:**
```luau
agent:Destroy()
```

### agent.Status: AgentStatus

Read-only property. One of:
- `"Idle"` — Not moving, no waypoints
- `"Computing"` — Waiting for path computation
- `"Moving"` — Actively following waypoints (Heartbeat loop running)
- `"Paused"` — Suspended mid-path
- `"Stuck"` — Detected no movement for stuckTimeout seconds

### Signals

All signals use the bundled Signal class (no BindableEvents).

#### agent.Reached: Signal

Fired when the Agent reaches the final waypoint.

**Callback signature:** `(model: Model, finalWaypoint: PathWaypoint) -> ()`

```luau
agent.Reached:Connect(function(model, waypoint)
    print(model.Name .. " reached", waypoint.Position)
end)
```

#### agent.WaypointReached: Signal

Fired when the Agent reaches each intermediate waypoint.

**Callback signature:** `(model: Model, from: PathWaypoint, to: PathWaypoint) -> ()`

```luau
agent.WaypointReached:Connect(function(model, from, to)
    if to.Action == Enum.PathWaypointAction.Jump then
        print("About to jump!")
    end
end)
```

#### agent.Blocked: Signal

Fired when PathfindingService reports the path is blocked.

**Callback signature:** `(model: Model, blockedWaypoint: PathWaypoint) -> ()`

**Note:** If `recomputeOnBlock = true` (default), the path will automatically be recomputed.

```luau
agent.Blocked:Connect(function(model, waypoint)
    print("Path blocked at", waypoint.Position)
end)
```

#### agent.Stuck: Signal

Fired when the Agent hasn't moved significantly for `stuckTimeout` seconds (default 3).

**Callback signature:** `(model: Model) -> ()`

**Note:** If `stuckRecoveryJump = true` (Humanoid mode), a jump attempt is automatically queued.

```luau
agent.Stuck:Connect(function(model)
    print(model.Name .. " is stuck")
end)
```

#### agent.Failed: Signal

Fired when movement cannot be completed.

**Callback signature:** `(model: Model, reason: FailReason) -> ()`

**Reason codes:**
- `"NoPath"` — No valid path exists from start to goal
- `"ComputationError"` — Pathfinding service error or timeout
- `"MaxRetriesExceeded"` — Recomputation failed more than maxRetries times
- `"AgentStuck"` — Stuck detection triggered with no recovery
- `"AgentDestroyed"` — The model's Humanoid died

```luau
agent.Failed:Connect(function(model, reason)
    print("Movement failed:", reason)
    if reason == "NoPath" then
        print("Try a closer target")
    end
end)
```

---

## Types

### AgentStatus

```luau
type AgentStatus = "Idle" | "Computing" | "Moving" | "Stuck" | "Paused"
```

### FailReason

```luau
type FailReason = "NoPath" | "ComputationError" | "MaxRetriesExceeded" | "AgentStuck" | "AgentDestroyed"
```

### SteeringMode

```luau
type SteeringMode = "Humanoid" | "Vehicle" | "Custom"
```

### AgentConfig

Complete configuration table for Agent.new():

```luau
type AgentConfig = {
    -- Steering (required)
    steeringMode: SteeringMode,
    steeringCallback: ((position: Vector3, lookAt: Vector3) -> ())?,

    -- Pathfinding
    agentParams: AgentParameters?,                      -- Passed to PathfindingService.CreatePath()
    waypointReachedRadius: number?,                     -- Default: 2 (Humanoid), 4 (Vehicle)
    recomputeOnBlock: boolean?,                         -- Default: true
    maxRetries: number?,                                -- Default: 3
    fallbackToDirectMove: boolean?,                     -- Default: false
    directMoveThreshold: number?,                       -- Default: 10 studs

    -- Stuck detection
    stuckTimeout: number?,                              -- Default: 3 seconds
    stuckRecoveryJump: boolean?,                        -- Default: true (Humanoid only)

    -- Vehicle steering (Vehicle mode only)
    vehiclePID: { kp: number, ki: number, kd: number }?,  -- Default: {kp=1.5, ki=0, kd=0.3}

    -- Debug
    visualise: boolean?,                                -- Default: false
}
```

#### Field descriptions

- **steeringMode** *(required)*: Determines how the Agent moves
  - `"Humanoid"`: Uses `Humanoid:MoveTo()` directly
  - `"Vehicle"`: Uses VehicleSeat steering with PID control
  - `"Custom"`: Calls user-supplied callback

- **steeringCallback** *(required if steeringMode="Custom")*: Function called each Heartbeat to move the rig. Receives `(position: Vector3, lookAt: Vector3)`.

- **agentParams**: Passed directly to `PathfindingService:CreatePath(agentParams)`. Lets you customize agent radius, height, cost modifiers, etc.

- **waypointReachedRadius**: How close (in studs) the Agent must be to a waypoint to consider it reached and advance to the next. Default 2 for Humanoid, 4 for Vehicle.

- **recomputeOnBlock**: If true, automatically recompute the path when `Path.Blocked` fires. Default true.

- **maxRetries**: Maximum number of recomputation attempts before firing `Failed`. Default 3.

- **fallbackToDirectMove**: If true and pathfinding fails, steer directly to the target instead of giving up. Default false.

- **directMoveThreshold**: If distance to target < this value, skip pathfinding and steer direct (studs). Default 10.

- **stuckTimeout**: Seconds without > 0.5 stud movement before marking stuck. Default 3.

- **stuckRecoveryJump** *(Humanoid only)*: If true, attempt a jump when stuck. Default true.

- **vehiclePID** *(Vehicle only)*: PID tuning for lateral steering control:
  - `kp`: Proportional gain (how much to steer based on current error). Default 1.5.
  - `ki`: Integral gain (how much to steer based on accumulated error). Default 0.
  - `kd`: Derivative gain (how much to damp steering change). Default 0.3.

- **visualise**: Enable debug visualization (not yet implemented). Default false.

### ComputeRequest

Internal type. Do not construct directly; Scheduler handles this.

```luau
type ComputeRequest = {
    id: string,
    start: Vector3,
    goal: Vector3,
    agentParams: AgentParameters?,
}
```

---

## Steering Modes

### Humanoid

Uses `Humanoid:MoveTo()` for movement. Automatically handles jump waypoints.

```luau
Agent.new(model, {
    steeringMode = "Humanoid",
    stuckRecoveryJump = true,  -- Jump to recover if stuck
})
```

### Vehicle

Uses `VehicleSeat` steering. Applies PID control to the `Steer` and `Throttle` properties.

```luau
Agent.new(model, {
    steeringMode = "Vehicle",
    vehiclePID = { kp = 1.5, ki = 0, kd = 0.3 },
})
```

See [vehicle-steering.md](./guides/vehicle-steering.md) for tuning guidance.

### Custom

Calls a user-supplied function each Heartbeat. Full control over movement.

```luau
Agent.new(model, {
    steeringMode = "Custom",
    steeringCallback = function(position, lookAt)
        -- Move rig however you want (TweenService, BodyVelocity, AnimationController, etc.)
        local direction = (position - model.PrimaryPart.Position).Unit
        model.PrimaryPart.BodyVelocity.Velocity = direction * 20
    end,
})
```

---

## Promise

Minimal Promise implementation (bundled; no external dependency).

```luau
local Promise = require(ReplicatedStorage.Packages.ParallelPath.Promise)

Promise.new(function(resolve, reject)
    -- async work
    if success then
        resolve(value)
    else
        reject("error message")
    end
end)
    :andThen(function(value)
        -- handle success
    end)
    :catch(function(error)
        -- handle error
    end)
```

---

## Signal

Lightweight signal implementation (bundled; no BindableEvents).

```luau
local Signal = require(ReplicatedStorage.Packages.ParallelPath.Signal)

local signal = Signal.new()
signal:Connect(function(...) end)
signal:Once(function(...) end)
signal:Fire(...)
signal:DisconnectAll()
signal:Destroy()
```
