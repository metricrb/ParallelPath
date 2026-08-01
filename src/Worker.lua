--!strict

local actor = script:GetActor()
assert(actor, "Worker must run inside an Actor")

local ResultEvent: BindableEvent = Instance.new("BindableEvent")

local function ComputePath(id: string, start: Vector3, goal: Vector3, agentParams: AgentParameters?)
	task.desynchronize()

	local path = PathfindingService:CreatePath(agentParams or {})
	local ok = pcall(path.ComputeAsync, path, start, goal)

	task.synchronize()

	if not ok then
		ResultEvent:Fire(id, nil, "ComputationError")
		return
	end

	if path.Status == Enum.PathStatus.NoPath then
		ResultEvent:Fire(id, nil, "NoPath")
		return
	end

	local waypoints = path:GetWaypoints()
	ResultEvent:Fire(id, waypoints, nil)
end

actor:BindToMessage("Compute", function(id: string, start: Vector3, goal: Vector3, agentParams: AgentParameters?)
	ComputePath(id, start, goal, agentParams)
end)

-- Keep the script alive
while true do
	task.wait(1)
end
