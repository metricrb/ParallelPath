--!strict
--[[
    AI Car Example

    Autonomous vehicle using Vehicle steering mode with PID-controlled lateral steering.
    Demonstrates multi-mode pathfinding and custom steering tuning.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local parallel_path = require(ReplicatedStorage.Packages.ParallelPath)
local Agent = parallel_path.Agent
local Scheduler = parallel_path.Scheduler

-- Initialize the scheduler
Scheduler.init(4)

local car = workspace.MyCar
assert(car, "Must have a car model named 'MyCar' in workspace")
assert(car:FindFirstChildOfClass("VehicleSeat"), "Car must have a VehicleSeat")

-- Create the agent with Vehicle steering
-- PID tuning: kp controls turn aggressiveness, kd controls settling/damping
local agent = Agent.new(car, {
	steeringMode = "Vehicle",
	waypointReachedRadius = 4,  -- Larger tolerance for vehicles
	recomputeOnBlock = true,
	maxRetries = 2,
	vehiclePID = {
		kp = 1.2,  -- Proportional: how aggressively to steer
		ki = 0.01,  -- Integral: correct accumulated drift (small value)
		kd = 0.4,  -- Derivative: dampen oscillation
	},
})

-- Waypoint network (taxi route)
local destinations = {
	{ name = "Pickup A", position = workspace.LocationA.Position },
	{ name = "Dropoff A", position = workspace.LocationDropoffA.Position },
	{ name = "Pickup B", position = workspace.LocationB.Position },
	{ name = "Dropoff B", position = workspace.LocationDropoffB.Position },
}

-- Track movement
agent.Reached:Connect(function(model, waypoint)
	print("Car reached destination")
	local seat = car:FindFirstChildOfClass("VehicleSeat")
	if seat then
		seat.Throttle = 0  -- Stop
	end
end)

agent.WaypointReached:Connect(function(model, from, to)
	print("Passed waypoint, distance to next:", (to.Position - car.PrimaryPart.Position).Magnitude)
end)

agent.Blocked:Connect(function(model, waypoint)
	print("Path blocked! Recomputing...")
end)

agent.Stuck:Connect(function(model)
	print("Car is stuck! Attempting recovery...")
	-- Could implement reverse-and-turn logic here
	local seat = car:FindFirstChildOfClass("VehicleSeat")
	if seat then
		seat.Throttle = -1  -- Reverse
		task.wait(2)
	end
end)

agent.Failed:Connect(function(model, reason)
	print("Navigation failed:", reason)
	local seat = car:FindFirstChildOfClass("VehicleSeat")
	if seat then
		seat.Throttle = 0
	end
end)

-- Autonomous taxi loop
local function autonomousTaxi()
	local tripNumber = 0
	while car.Parent do
		tripNumber = tripNumber + 1
		print("=== Trip", tripNumber, "===")

		for _, destination in ipairs(destinations) do
			print("Driving to", destination.name)
			agent:MoveTo(destination.position)

			-- Wait for arrival (with timeout safety)
			local arrived = false
			agent.Reached:Once(function()
				arrived = true
			end)

			local timeout = tick() + 60  -- 60 second timeout
			while not arrived and tick() < timeout and car.Parent do
				task.wait(0.5)
			end

			if arrived then
				print("Arrived at", destination.name)
				task.wait(3)  -- Wait at destination
			else
				print("Failed to reach", destination.name)
				break
			end
		end

		task.wait(5)  -- Wait between trips
	end
end

-- Alternative: Manual waypoint-by-waypoint driving
local function manualDriving()
	while car.Parent do
		for i, destination in ipairs(destinations) do
			print("Driving to destination", i, "of", #destinations)

			-- Check distance and log
			local distance = (destination.position - car.PrimaryPart.Position).Magnitude
			print("Distance to target:", distance)

			agent:MoveTo(destination.position)

			-- Listen for all outcomes
			local done = false
			local reason = nil

			agent.Reached:Once(function()
				done = true
				reason = "reached"
			end)

			agent.Failed:Once(function(_, failReason)
				done = true
				reason = failReason
			end)

			while not done do
				task.wait(0.5)
				-- Could log intermediate status here
				print("Status:", agent.Status)
			end

			if reason == "reached" then
				print("Success!")
				task.wait(2)
			else
				print("Failed:", reason)
				break
			end
		end

		task.wait(10)
	end
end

-- Start the taxi
task.spawn(autonomousTaxi)

-- Cleanup
car.PrimaryPart:FindFirstChildOfClass("BodyVelocity").Destroy()

print("AI Car initialized and ready!")
