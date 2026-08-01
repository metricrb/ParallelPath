--!strict

local HumanoidSteering = require(script.Parent.Parent.src.Steering.HumanoidSteering)
local VehicleSteering = require(script.Parent.Parent.src.Steering.VehicleSteering)
local CustomSteering = require(script.Parent.Parent.src.Steering.CustomSteering)

return function()
	describe("HumanoidSteering", function()
		it("should create a steering controller for humanoid models", function()
			local model = Instance.new("Model")
			local primaryPart = Instance.new("Part")
			primaryPart.Parent = model
			model.PrimaryPart = primaryPart

			local humanoid = Instance.new("Humanoid")
			humanoid.Parent = model

			local steering = HumanoidSteering.new(model)
			expect(steering).to.be.ok()

			model:Destroy()
		end)

		it("should call MoveTo on the humanoid", function()
			local model = Instance.new("Model")
			local primaryPart = Instance.new("Part")
			primaryPart.Parent = model
			model.PrimaryPart = primaryPart

			local humanoid = Instance.new("Humanoid")
			humanoid.Parent = model

			local steering = HumanoidSteering.new(model)
			steering:moveTo(Vector3.new(10, 0, 10))

			model:Destroy()
		end)
	end)

	describe("VehicleSteering", function()
		it("should create a steering controller for vehicle models", function()
			local model = Instance.new("Model")
			local primaryPart = Instance.new("Part")
			primaryPart.Parent = model
			model.PrimaryPart = primaryPart

			local seat = Instance.new("VehicleSeat")
			seat.Parent = model

			local steering = VehicleSteering.new(model)
			expect(steering).to.be.ok()

			model:Destroy()
		end)

		it("should use custom PID config if provided", function()
			local model = Instance.new("Model")
			local primaryPart = Instance.new("Part")
			primaryPart.Parent = model
			model.PrimaryPart = primaryPart

			local seat = Instance.new("VehicleSeat")
			seat.Parent = model

			local pidConfig = { kp = 2.0, ki = 0.1, kd = 0.5 }
			local steering = VehicleSteering.new(model, pidConfig)

			expect(steering._pidConfig.kp).to.equal(2.0)
			expect(steering._pidConfig.ki).to.equal(0.1)
			expect(steering._pidConfig.kd).to.equal(0.5)

			model:Destroy()
		end)
	end)

	describe("CustomSteering", function()
		it("should accept a user-supplied callback", function()
			local model = Instance.new("Model")
			local primaryPart = Instance.new("Part")
			primaryPart.Parent = model
			model.PrimaryPart = primaryPart

			local callback = function(pos: Vector3, lookAt: Vector3) end
			local steering = CustomSteering.new(model, callback)
			expect(steering).to.be.ok()

			model:Destroy()
		end)

		it("should call the callback on moveTo", function()
			local model = Instance.new("Model")
			local primaryPart = Instance.new("Part")
			primaryPart.Parent = model
			model.PrimaryPart = primaryPart

			local called = false
			local callback = function(pos: Vector3, lookAt: Vector3)
				called = true
			end

			local steering = CustomSteering.new(model, callback)
			steering:moveTo(Vector3.new(10, 0, 10))

			expect(called).to.equal(true)
			model:Destroy()
		end)
	end)
end
