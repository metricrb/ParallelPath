# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2024-01-XX

### Added

#### Core Features
- **Heartbeat distance-polling loop** — Replaces MoveToFinished for stutter-free humanoid movement
- **Parallel path computation** — Actor-based worker pool for simultaneous pathfinding requests
- **Three steering modes**:
  - `Humanoid`: Direct `Humanoid:MoveTo()` integration
  - `Vehicle`: PID-controlled steering for VehicleSeat-based vehicles
  - `Custom`: User-supplied callback for arbitrary movement logic
- **Stuck detection** — Automatically detects when agents aren't moving and attempts recovery
- **Robust failsafe hierarchy**:
  - Automatic path recomputation on block
  - Partial path fallback to nearest reachable node
  - Optional direct steering when pathfinding fails
  - Configurable retry count and strategies

#### API
- `Agent.new(model, config)` — Create a movement controller
- `Agent:MoveTo(target)` — Move to a position or Part (returns cancel function)
- `Agent:Stop()`, `Agent:Pause()`, `Agent:Resume()` — Movement control
- `Agent:Destroy()` — Cleanup
- `Agent.Status` — Read-only movement state
- Signals: `Reached`, `WaypointReached`, `Blocked`, `Stuck`, `Failed`
- `Scheduler.init()`, `Scheduler.compute()` — Actor pool management
- `Types` export — All public types and enums

#### Utilities
- **Signal.luau** — Lightweight Signal implementation (no BindableEvents)
- **Promise.luau** — Minimal Promise for async operations
- **GridBuilder.luau** — Optional walkability grid baking for static geometry

#### Documentation
- Comprehensive API reference with all method signatures and types
- Getting started guide with basic setup and common patterns
- Multi-part guides: vehicle steering, parallel computation, failsafe hierarchy, migration from SimplePath
- Three fully-commented examples:
  - Humanoid NPC with patrol and chase logic
  - Autonomous vehicle with PID tuning
  - Custom rig movement with BodyVelocity
- Configuration documentation with defaults and trade-offs

#### Tooling
- `default.project.json` — Roblox model sync configuration
- `.luaurc` — Strict Luau mode enabled globally
- `selene.toml` — Linting configuration for Roblox
- GitHub Actions CI/CD:
  - `build-docs.yml` — Auto-deploy docs to GitHub Pages on changes
  - `build-rbxm.yml` — Build and release RBXM files on tags
  - `ci.yml` — Lint, type-check, and build on all PRs

#### Tests
- Agent behavior tests (creation, status transitions, signals)
- Scheduler tests (initialization, worker management)
- Steering mode tests (humanoid, vehicle, custom)

### Configuration Options

- `steeringMode` (required): `"Humanoid"`, `"Vehicle"`, or `"Custom"`
- `steeringCallback`: Required for Custom mode, function(pos, lookAt)
- `agentParams`: PathfindingService.CreatePath() configuration
- `waypointReachedRadius`: Distance threshold per steering mode (default 2/4 studs)
- `recomputeOnBlock`: Auto-recompute on Path.Blocked (default true)
- `maxRetries`: Recomputation attempts (default 3)
- `vehiclePID`: Vehicle steering tuning `{kp, ki, kd}` (default 1.5, 0, 0.3)
- `stuckTimeout`: Seconds before marking stuck (default 3)
- `stuckRecoveryJump`: Auto-jump on stuck (Humanoid only, default true)
- `fallbackToDirectMove`: Steer direct if pathfinding fails (default false)
- `directMoveThreshold`: Distance for direct steering (default 10 studs)
- `visualise`: Debug visualization flag (not yet implemented)

### Limitations

- Actor parallelism limited by game engine concurrency (typically 4–8 workers optimal)
- PathfindingService timeouts apply (no per-request override)
- Vehicle steering assumes differential-steering model (cars/tanks, not holonomic)
- No built-in animation blending (Custom mode recommended for animated rigs)

---

## Future roadmap

### Planned for v0.2.0
- [ ] Visualization debug drawing (waypoints, grid, stuck zones)
- [ ] Path caching for identical start/goal pairs
- [ ] Humanoid animation state sync with waypoint actions
- [ ] Predictive waypoint advance (heading-based, not just distance)

### Planned for v0.3.0
- [ ] Multi-layer pathfinding (different agent sizes)
- [ ] Formations API (group movement)
- [ ] Waypoint branching (choose path variants)
- [ ] Region-based cost modifiers for terrain preference

---

## Version history

### v0.1.0 (Initial release)
- All core features implemented
- Full documentation suite
- GitHub Actions CI/CD
- Wally package registry ready

---

## Known issues

*None at release.*

## Support

For issues, questions, or contributions, visit:
- GitHub: https://github.com/metricrb/parallel-path
- Documentation: https://metricrb.github.io/parallel-path/
