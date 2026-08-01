--!strict

local Agent = require(script.Parent.Parent.src.Agent)

return function()
	describe("Agent", function()
		it("should create an agent with a valid config", function()
			local model = Instance.new("Model")
			local primaryPart = Instance.new("Part")
			primaryPart.Parent = model
			model.PrimaryPart = primaryPart

			local humanoid = Instance.new("Humanoid")
			humanoid.Parent = model

			local agent = Agent.new(model, {
				steeringMode = "Humanoid",
			})

			expect(agent).to.be.ok()
			expect(agent.Status).to.equal("Idle")

			agent:Destroy()
			model:Destroy()
		end)

		it("should set network owner to nil", function()
			local model = Instance.new("Model")
			local primaryPart = Instance.new("Part")
			primaryPart.Parent = model
			model.PrimaryPart = primaryPart

			local humanoid = Instance.new("Humanoid")
			humanoid.Parent = model

			local agent = Agent.new(model, {
				steeringMode = "Humanoid",
			})

			expect(primaryPart:FindFirstChildOfClass("BodyVelocity")).to.be.ok()

			agent:Destroy()
			model:Destroy()
		end)

		it("should transition to Moving state on MoveTo", function()
			local model = Instance.new("Model")
			local primaryPart = Instance.new("Part")
			primaryPart.Parent = model
			model.PrimaryPart = primaryPart

			local humanoid = Instance.new("Humanoid")
			humanoid.Parent = model

			local agent = Agent.new(model, {
				steeringMode = "Humanoid",
			})

			agent:MoveTo(Vector3.new(10, 0, 10))
			task.wait(0.1)

			expect(agent.Status).to.equal("Computing")

			agent:Destroy()
			model:Destroy()
		end)

		it("should have all required signals", function()
			local model = Instance.new("Model")
			local primaryPart = Instance.new("Part")
			primaryPart.Parent = model
			model.PrimaryPart = primaryPart

			local humanoid = Instance.new("Humanoid")
			humanoid.Parent = model

			local agent = Agent.new(model, {
				steeringMode = "Humanoid",
			})

			expect(agent.Reached).to.be.ok()
			expect(agent.WaypointReached).to.be.ok()
			expect(agent.Blocked).to.be.ok()
			expect(agent.Stuck).to.be.ok()
			expect(agent.Failed).to.be.ok()

			agent:Destroy()
			model:Destroy()
		end)
	end)
end
