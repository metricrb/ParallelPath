--!strict
--[[
    4. AUTONOMOUS VEHICLE

    Self-driving car using Vehicle steering mode with PID control.
    Drop this in ServerScriptService.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local parallel_path = require(ReplicatedStorage.Packages.ParallelPath)
local Agent = parallel_path.Agent
local Scheduler = parallel_path.Scheduler

Scheduler.init(4)

-- Create a simple car model
local car = Instance.new("Model")
car.Name = "AutoCar"

local chassis = Instance.new("Part")
chassis.Name = "Chassis"
chassis.Size = Vector3.new(4, 2, 8)
chassis.Color = Color3.fromRGB(0, 100, 255)
chassis.CanCollide = true
chassis.Parent = car
car.PrimaryPart = chassis

local seat = Instance.new("VehicleSeat")
seat.Name = "Seat"
seat.Size = Vector3.new(2, 1, 2)
seat.CanCollide = false
seat.Parent = car

-- Create wheels (for visual only)
for _, name in ipairs({ "WheelFL", "WheelFR", "WheelBL", "WheelBR" }) do
	local wheel = Instance.new("Part")
	wheel.Name = name
	wheel.Shape = Enum.PartType.Cylinder
	wheel.Size = Vector3.new(0.6, 2, 2)
	wheel.Color = Color3.fromRGB(0, 0, 0)
	wheel.CanCollide = true
	wheel.Parent = car
end

car:MoveTo(Vector3.new(0, 5, 0))
car.Parent = workspace

-- Create the agent with Vehicle steering
local agent = Agent.new(car, {
	steeringMode = "Vehicle",
	waypointReachedRadius = 4,
	recomputeOnBlock = true,
	maxRetries = 2,
	vehiclePID = {
		kp = 1.2,  -- Proportional: turn aggressiveness
		ki = 0.01,  -- Integral: correct drift
		kd = 0.4,   -- Derivative: dampen oscillation
	},
})

-- Define route waypoints
local route = {
	Vector3.new(0, 5, 0),
	Vector3.new(100, 5, 0),
	Vector3.new(100, 5, 100),
	Vector3.new(0, 5, 100),
	Vector3.new(0, 5, 0),
}

local currentWaypoint = 1
local trips = 0

agent.Reached:Connect(function()
	print("Car reached waypoint", currentWaypoint)
	currentWaypoint = (currentWaypoint % #route) + 1

	if currentWaypoint == 1 then
		trips = trips + 1
		print("Completed trip", trips)
		task.wait(3)  -- Rest at depot
	else
		task.wait(1)
	end

	agent:MoveTo(route[currentWaypoint])
end)

agent.WaypointReached:Connect(function(_, from, to)
	local dist = (to.Position - from.Position).Magnitude
	print("Passed waypoint, distance:", math.floor(dist), "studs")
end)

agent.Blocked:Connect(function()
	print("Car blocked, recomputing...")
end)

agent.Stuck:Connect(function()
	print("Car stuck, retrying...")
	agent:MoveTo(route[currentWaypoint])
end)

agent.Failed:Connect(function(_, reason)
	print("Route failed:", reason, "- trying next waypoint")
	currentWaypoint = (currentWaypoint % #route) + 1
	agent:MoveTo(route[currentWaypoint])
end)

-- Start autonomous driving
print("Car initialized, starting route...")
agent:MoveTo(route[1])

-- Display status every 5 seconds
task.spawn(function()
	while car.Parent do
		print(string.format("Car status: %s | Trip: %d | Waypoint: %d/%d", agent.Status, trips, currentWaypoint, #route))
		task.wait(5)
	end
end)
