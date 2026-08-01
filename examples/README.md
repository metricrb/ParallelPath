# parallel-path Examples

Practical, copy-paste-ready examples for using parallel-path in your Roblox game.

## Quick Start

1. **Install parallel-path** via Wally to `ReplicatedStorage.Packages.ParallelPath`
2. **Copy any example** into ServerScriptService
3. **Run the game** — watch it work!

All examples are complete and standalone (no setup needed beyond installing the package).

---

## Examples

### 1. **BasicSetup.lua** — Minimal Working Example
Start here. Shows:
- Initializing the Scheduler
- Creating an Agent
- Moving to a target
- Connecting to signals

**Good for:** Understanding the core API

**Time to run:** 5 seconds

---

### 2. **PatrolBehavior.lua** — Looping Patrol Route
NPC patrols between 4 waypoints in a loop. Shows:
- Multi-waypoint routes
- Pausing/resuming with spacebar
- Handling the `Reached` signal
- Recovery on stuck

**Good for:** Guard NPCs, delivery routes, security patrols

**Time to run:** Infinite loop (press Space to pause)

---

### 3. **ChasePlayer.lua** — Dynamic Target Following
NPC chases the nearest player within 60 studs. Shows:
- Dynamic target updates (player position changes)
- Chase detection with distance radius
- Handling moving targets
- Adaptive retry on failure

**Good for:** Enemy AI, monsters, aggressive NPCs

**Time to run:** Infinite (while players are present)

---

### 4. **AutonomousVehicle.lua** — Self-Driving Car
Car autonomously drives a delivery route. Shows:
- Vehicle steering mode with PID tuning
- Route planning
- Throttle and braking
- Multi-trip logistics

**Steering config:**
```lua
vehiclePID = {
    kp = 1.2,  -- Turn aggressiveness
    ki = 0.01,  -- Drift correction
    kd = 0.4,   -- Settling/damping
}
```

**Good for:** Autonomous taxis, delivery vehicles, traffic simulation

**Time to run:** ~60 seconds per trip (4 waypoints)

---

### 5. **CustomSteering.lua** — Floating Orb with BodyVelocity
Orb flies through waypoints using custom steering callback. Shows:
- Custom steering mode
- BodyVelocity-based movement
- Rotation toward direction
- Smooth acceleration/deceleration

**Good for:** Flying creatures, floating objects, physics-based rigs

**Time to run:** ~30 seconds per loop

---

### 6. **MultiAgent.lua** — 5 NPCs Running in Parallel
Five humanoid NPCs move simultaneously without blocking each other. Shows:
- Parallel pathfinding power (all 5 path computations happen at once)
- Agent status monitoring
- Batch operations
- Scalability

**Good for:** Crowds, squads, school scenes, simultaneous navigation

**Time to run:** ~60 seconds per cycle (3 waypoints each)

---

### 7. **ErrorHandling.lua** — Comprehensive Error Recovery
Advanced example showing all error scenarios and recovery patterns. Shows:
- All signals: `Reached`, `WaypointReached`, `Blocked`, `Stuck`, `Failed`
- All failure reasons: `NoPath`, `ComputationError`, `MaxRetriesExceeded`, `AgentStuck`
- Retry patterns
- Statistics collection
- Detailed failure analysis

**Good for:** Learning best practices, debugging issues, understanding failsafes

**Time to run:** ~20 seconds (3 test scenarios)

---

## Running Examples

### Option 1: Direct Copy (Recommended)
1. Open example file
2. Copy entire contents
3. In Roblox Studio, right-click **ServerScriptService** → Insert Object → LocalScript
4. Paste code
5. Run game

### Option 2: As Module
Place example in ServerScriptService, modify require paths if needed:
```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local example = require(game.ServerScriptService["2_PatrolBehavior"])
```

### Option 3: As Tests
Combine multiple examples in one script to test simultaneously:
```lua
-- Run PatrolBehavior AND ChasePlayer at the same time
local parallel_path = require(...)
Scheduler.init(8)
dofile(game.ServerScriptService["2_PatrolBehavior"])
dofile(game.ServerScriptService["3_ChasePlayer"])
```

---

## Customization Tips

### Change Movement Speed
Modify the waypoint distance or stuckTimeout:
```lua
Agent.new(npc, {
    stuckTimeout = 5,           -- Takes longer to mark stuck = faster perceived speed
    waypointReachedRadius = 3,  -- Tighter tolerance = more precise paths
})
```

### Add More Agents
Copy the agent creation loop and increase `npcCount`:
```lua
local npcCount = 10  -- Run 10 agents instead of 5
```

### Tune Vehicle Steering
Adjust PID values in AutonomousVehicle.lua:
```lua
vehiclePID = {
    kp = 2.0,   -- Higher = sharper turns
    ki = 0.05,  -- Higher = more drift correction
    kd = 0.5,   -- Higher = smoother settling
}
```

### Change Detection Range
In ChasePlayer.lua:
```lua
local chaseDistance = 100  -- 100 studs instead of 60
```

---

## Performance Notes

- **BasicSetup**: ~1ms per frame (1 agent, simple path)
- **PatrolBehavior**: ~2ms per frame (1 agent, looping)
- **ChasePlayer**: ~3ms per frame (1 agent, dynamic target)
- **AutonomousVehicle**: ~3ms per frame (1 vehicle, PID steering)
- **CustomSteering**: ~2ms per frame (1 custom rig)
- **MultiAgent**: ~8ms per frame (5 agents in parallel)

Scheduler adds ~1ms per pathfinding computation (happens in parallel, not per frame).

---

## Troubleshooting

### "Agent requires a model"
- Make sure you're passing a Model instance, not a Part
- Model must have a PrimaryPart set

### "Model must have a Humanoid"
- Only applies to `steeringMode = "Humanoid"`
- Use Vehicle or Custom mode for other types

### "No valid path" error
- Target is unreachable (behind walls, off the map, etc.)
- Try a closer target or clear obstacles
- Use `fallbackToDirectMove = true` to ignore pathfinding

### Agent moves too slowly
- Decrease `waypointReachedRadius` to force tighter paths
- Increase `stuckTimeout` to avoid false stuck detection
- Reduce waypoint distance

### Multiple agents blocking each other
- Increase `chaseDistance` or detection radius
- Use offset waypoints so they don't converge
- This is expected real-world pathfinding behavior

---

## Next Steps

After running examples:

1. **Read the API reference** — Understand all config options
2. **Check the guides** — Vehicle steering tuning, parallel computation details
3. **Adapt for your game** — Combine patterns to fit your needs

See [docs/](../docs/) for comprehensive documentation.

---

## Questions?

- Check [api-reference.md](../docs/api-reference.md) for method signatures
- See [guides/failsafe-hierarchy.md](../docs/guides/failsafe-hierarchy.md) for error handling
- Read [guides/vehicle-steering.md](../docs/guides/vehicle-steering.md) for PID tuning
