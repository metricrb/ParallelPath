--!strict

local Scheduler = require(script.Parent.Parent.src.Scheduler)

return function()
	describe("Scheduler", function()
		it("should initialize with default worker count", function()
			Scheduler.init(2)
			expect(#Scheduler._actors).to.equal(2)
			Scheduler.destroy()
		end)

		it("should create a custom parent folder", function()
			local parent = Instance.new("Folder")
			parent.Name = "CustomParent"
			Scheduler.init(1, parent)

			local hasWorker = false
			for _, child in ipairs(parent:GetChildren()) do
				if child.Name:find("Worker") then
					hasWorker = true
					break
				end
			end

			expect(hasWorker).to.equal(true)
			Scheduler.destroy()
			parent:Destroy()
		end)

		it("should maintain idempotency on multiple init calls", function()
			Scheduler.init(2)
			local firstCount = #Scheduler._actors
			Scheduler.init(4)
			local secondCount = #Scheduler._actors

			expect(firstCount).to.equal(secondCount)
			Scheduler.destroy()
		end)

		it("should clean up on destroy", function()
			Scheduler.init(2)
			Scheduler.destroy()

			expect(#Scheduler._actors).to.equal(0)
			expect(Scheduler._initialized).to.equal(false)
		end)
	end)
end
