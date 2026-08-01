# parallel-path

> Parallel Luau pathfinding for humanoids, vehicles, and custom rigs — no MoveToFinished stutter.

[![CI](https://github.com/metricsrb/parallel-path/actions/workflows/ci.yml/badge.svg)](https://github.com/metricsrb/parallel-path/actions/workflows/ci.yml)
[![Build Documentation](https://github.com/metricsrb/parallel-path/actions/workflows/build-docs.yml/badge.svg)](https://metricsrb.github.io/parallel-path/)
[![Wally Package](https://img.shields.io/badge/wally-metricsrb%2Fparallel--path-blue)](https://wally.run/package/metricsrb/parallel-path)

## Why parallel-path?

SimplePath is great, but has one critical flaw: **MoveToFinished event causes visible stuttering** when humanoids reach waypoints. The event fires on the server after the client has already moved past the waypoint, creating noticeable jitter.

**parallel-path solves this** by replacing MoveToFinished with a **Heartbeat distance-polling loop**, borrowed from Roblox's ClickToMove controller logic. This eliminates stutter entirely.

Beyond that, parallel-path offers:

- **Parallel path computation** via Actors + Parallel Luau. Compute multiple paths at once without blocking gameplay.
- **Multi-mode steering**: Humanoid rigs, vehicles with PID steering, or completely custom controllers.
- **Robust failsafes**: Automatic recomputation on block, stuck detection with recovery, fallback to direct movement.
- **No external dependencies**: Signal and Promise are bundled.
- **Comprehensive documentation**: Full API reference, guides, and examples.

## Quick start

### Installation

Add to your `wally.toml`:

```toml
[dependencies]
ParallelPath = "metricsrb/parallel-path@0.1"
```

Run `wally install`.

### Basic usage

```luau
local parallel_path = require(game:GetService("ReplicatedStorage").Packages.ParallelPath)
local Agent = parallel_path.Agent
local Scheduler = parallel_path.Scheduler

-- Initialize once at game startup
Scheduler.init(4)

-- Create an agent for a humanoid NPC
local agent = Agent.new(workspace.MyNPC, {
    steeringMode = "Humanoid",
})

-- Move to target
agent:MoveTo(workspace.Target.Position)

-- Handle events
agent.Reached:Connect(function(model, waypoint)
    print("Reached target!")
end)

agent.Failed:Connect(function(model, reason)
    print("Movement failed:", reason)
end)
```

See [Getting Started](https://metricsrb.github.io/parallel-path/getting-started.html) for more.

## Features

### Heartbeat distance-polling

No more MoveToFinished stutter. The Agent reads the model's position every frame and compares it to the target waypoint distance. When close enough, the next waypoint is queued instantly.

### Parallel path computation

Path requests run in Actor-isolated Parallel Luau, never blocking the main thread. Submit multiple paths at once — they compute in parallel.

### Multi-mode steering

| Mode | Use case |
|------|----------|
| **Humanoid** | NPCs, monsters, animated characters |
| **Vehicle** | Cars, tanks, with PID-controlled steering |
| **Custom** | AnimationControllers, TweenService, BodyVelocity, physics rigs |

### Built-in stuck detection

If an agent doesn't move for 3 seconds, it automatically attempts a recovery jump (humanoids) or fires the `Stuck` signal. Configurable timeout and recovery strategy.

### Failsafe hierarchy

When pathfinding fails:
1. Automatically recompute (up to maxRetries)
2. Attempt partial path to nearest reachable node
3. Optionally fall back to direct steering
4. Fire `Failed` signal with detailed reason code

## Documentation

- **[API Reference](https://metricsrb.github.io/parallel-path/api-reference.html)** — All methods, signals, and types
- **[Getting Started](https://metricsrb.github.io/parallel-path/getting-started.html)** — Step-by-step walkthrough
- **[Guides](https://metricsrb.github.io/parallel-path/guides/)** — Vehicle steering, parallel computation, failsafes, migration from SimplePath
- **[Examples](https://metricsrb.github.io/parallel-path/examples/)** — Humanoid NPC, AI car, custom rig with BodyVelocity

## Project structure

```
parallel-path/
├── src/
│   ├── init.luau                    -- Main export point
│   ├── Agent.luau                   -- Core movement controller
│   ├── Scheduler.luau               -- Actor pool manager
│   ├── WorkerScript.server.luau     -- Runs inside each Actor
│   ├── GridBuilder.luau             -- Optional walkability grid
│   ├── Signal.luau                  -- Lightweight Signal (no BindableEvents)
│   ├── Promise.luau                 -- Minimal Promise implementation
│   ├── Types.luau                   -- Type definitions
│   └── Steering/
│       ├── HumanoidSteering.luau    -- Humanoid:MoveTo() wrapper
│       ├── VehicleSteering.luau     -- PID-controlled vehicle steering
│       └── CustomSteering.luau      -- User-supplied callback
├── tests/
│   ├── Agent.spec.luau
│   ├── Scheduler.spec.luau
│   └── Steering.spec.luau
├── docs/
│   ├── index.md                     -- Overview
│   ├── getting-started.md           -- Quick start
│   ├── api-reference.md             -- Full API
│   ├── guides/
│   │   ├── vehicle-steering.md
│   │   ├── parallel-computation.md
│   │   ├── failsafe-hierarchy.md
│   │   └── migrating-from-simplepath.md
│   └── examples/
│       ├── humanoid-npc.luau
│       ├── ai-car.luau
│       └── custom-rig.luau
├── wally.toml
├── default.project.json
├── .luaurc
└── selene.toml
```

## Performance

- **Humanoid NPCs**: 2–3x smoother due to Heartbeat polling (no MoveToFinished stutter)
- **Many agents (10+)**: 5–10x faster with parallel computation
- **Vehicles**: New capability, significantly faster than humanoid pathfinding
- **Memory**: Slightly higher (Actor overhead), negligible for most games

## Comparison with SimplePath

| Feature | SimplePath | parallel-path |
|---------|-----------|----------------|
| Humanoid pathfinding | ✓ | ✓ |
| No MoveToFinished stutter | ✗ | ✓ |
| Parallel path computation | ✗ | ✓ |
| Vehicle steering | ✗ | ✓ |
| Custom steering callbacks | ✗ | ✓ |
| Stuck detection | ✗ | ✓ |
| Pause/resume | ✗ | ✓ |
| Recompute on block | ✓ | ✓ |
| Error signals | ✓ | ✓ (more detailed) |

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -am 'Add feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Open a Pull Request

## Testing

Run tests with:

```bash
wally install
rojo test
```

## License

MIT — see [LICENSE](./LICENSE) for details.

## Acknowledgments

- Inspired by Roblox's ClickToMove controller for the Heartbeat polling approach
- Built with Luau strict mode for safety and type checking
- Designed for production games with performance in mind

---

**Questions?** Check the [documentation](https://metricsrb.github.io/parallel-path/) or open an issue on GitHub.
