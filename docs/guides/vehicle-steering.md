# Vehicle Steering

This guide covers using parallel-path to drive vehicles with AI.

## Setup

1. Your vehicle model must have a `VehicleSeat` instance
2. The `PrimaryPart` should be the chassis (or another rigid body that represents the vehicle's position)
3. The VehicleSeat doesn't need to be occupied — the Agent controls it via `Steer` and `Throttle` properties

**Example vehicle structure:**
```
Workspace/
  MyCar/
    PrimaryPart = Chassis (Part)
    Chassis (Part)
    FrontLeft (Part, collision = on)
    FrontRight (Part, collision = on)
    BackLeft (Part, collision = on)
    BackRight (Part, collision = on)
    VehicleSeat (Seat, CanCollide = false)
    BodyVelocity or Motor6D joints for steering
```

## Basic usage

```luau
local Agent = parallel_path.Agent

local car = workspace.MyCar
local agent = Agent.new(car, {
    steeringMode = "Vehicle",
    waypointReachedRadius = 4,    -- Cars need more distance tolerance
    vehiclePID = { kp = 1.5, ki = 0, kd = 0.3 },  -- Tuning (see below)
})

agent:MoveTo(workspace.Destination.Position)

agent.Reached:Connect(function()
    print("Car reached destination")
end)
```

## PID steering control

parallel-path uses a **Proportional-Integral-Derivative (PID)** controller to steer the vehicle.

Each Heartbeat:
1. Compute the **lateral error**: how far off-center (left/right) the target is
2. Apply the formula: `steer = kp*error + ki*integral + kd*derivative`
3. Clamp the result to [-1, 1] and set `seat.Steer`

### Understanding PID coefficients

- **kp (Proportional)**: How aggressively to steer toward the target
  - Higher = tighter turns, may overshoot or oscillate
  - Lower = looser turns, may miss waypoints
  - **Default: 1.5**

- **ki (Integral)**: How much to correct accumulated steering errors
  - Use sparingly; can cause overshooting
  - Helps if the vehicle naturally drifts
  - **Default: 0 (disabled)**

- **kd (Derivative)**: How much to dampen steering changes
  - Reduces oscillation and overshoot
  - Helps the vehicle settle on a heading
  - **Default: 0.3**

### Tuning for your vehicle

Start with the defaults, then adjust:

1. **If the car zigzags or oscillates**, increase `kd` (damping) to smooth turns.
2. **If the car drifts and never corrects**, increase `ki` slightly (0.01–0.1).
3. **If the car overshoots waypoints**, decrease `kp` or increase `kd`.
4. **If the car turns too slowly**, increase `kp`.

**Example: Fast, aggressive turning**
```luau
{
    steeringMode = "Vehicle",
    vehiclePID = { kp = 2.5, ki = 0, kd = 0.5 },  -- Tighter, faster
}
```

**Example: Smooth, gentle turns (big truck)**
```luau
{
    steeringMode = "Vehicle",
    vehiclePID = { kp = 0.8, ki = 0, kd = 0.2 },  -- Loose, stable
}
```

## Stuck detection for vehicles

Vehicles are marked "stuck" when:
- Velocity magnitude < 0.5 studs/s for `stuckTimeout` seconds (default 3)
- Unlike humanoids, this uses actual velocity, not position delta

If stuck:
1. The `Stuck` signal fires
2. The path is recomputed from the current position
3. No recovery jump (vehicles don't jump)

**Handling stuck for vehicles:**
```luau
agent.Stuck:Connect(function(model)
    print("Car is stuck — attempting reverse")
    -- Could implement reverse-and-turn logic here
    local seat = model:FindFirstChildOfClass("VehicleSeat")
    seat.Throttle = -1  -- Reverse
    task.wait(2)
    agent:MoveTo(workspace.NextTarget)
end)
```

## Throttle and braking

parallel-path automatically controls `seat.Throttle`:
- **Moving to next waypoint**: `Throttle = 1` (full forward)
- **Near waypoint**: `Throttle = 0` (coast to stop)
- **In stop() call**: `Throttle = -0.5` (light reverse)

If you need custom throttle logic, use **Custom steering** mode instead:

```luau
Agent.new(car, {
    steeringMode = "Custom",
    steeringCallback = function(position, lookAt)
        local seat = car:FindFirstChildOfClass("VehicleSeat")
        local direction = (position - car.PrimaryPart.Position)
        local distance = direction.Magnitude

        if distance > 5 then
            seat.Throttle = 1  -- Full speed far from target
        elseif distance > 1 then
            seat.Throttle = 0.5  -- Half speed near target
        else
            seat.Throttle = 0  -- Coast to stop
        end

        -- Lateral steering (same as VehicleSteering)
        local localTarget = car.PrimaryPart.CFrame:PointToObjectSpace(position)
        local lateralError = math.clamp(localTarget.X / localTarget.Magnitude, -1, 1)
        seat.Steer = lateralError * 0.8  -- Custom steering formula
    end,
})
```

## Example: Autonomous taxi

```luau
local parallel_path = require(game:GetService("ReplicatedStorage").Packages.ParallelPath)
local Agent = parallel_path.Agent
local Scheduler = parallel_path.Scheduler

Scheduler.init(4)

local taxi = workspace.Taxi
local agent = Agent.new(taxi, {
    steeringMode = "Vehicle",
    waypointReachedRadius = 4,
    vehiclePID = { kp = 1.2, ki = 0.01, kd = 0.4 },
})

local passengers = { workspace.Passenger1, workspace.Passenger2 }

local function drivePassenger(passenger, destination)
    print("Picking up", passenger.Name)
    agent:MoveTo(passenger.PrimaryPart)
    agent.Reached:Wait()

    print("Driving to", destination.Name)
    agent:MoveTo(destination.PrimaryPart)
    agent.Reached:Wait()

    print("Dropped off at", destination.Name)
    task.wait(2)
end

for _, passenger in ipairs(passengers) do
    drivePassenger(passenger, workspace.DropOff)
end
```

## Troubleshooting

**Car doesn't move:**
- Ensure VehicleSeat has `CanCollide = false` and is parented to the car model
- Check that the car's chassis has physics (CanCollide = true, CustomPhysicalProperties if needed)
- Verify the car isn't in an anchor state

**Car turns too slowly:**
- Increase `kp` (e.g., 1.5 → 2.0 or 2.5)
- Decrease `waypointReachedRadius` to force tighter waypoint tracking

**Car oscillates/zigzags:**
- Increase `kd` (damping) to smooth turns
- Decrease `kp` to make turns less aggressive

**Car drifts and misses waypoints:**
- Increase `ki` slightly (0.01–0.05) to correct drift
- Increase `waypointReachedRadius` to give more tolerance
- Adjust your path-planning `AgentParameters` (wider agent radius = wider turns)

---

See also: [Parallel Computation](./parallel-computation.md), [Failsafe Hierarchy](./failsafe-hierarchy.md)
