--!strict

local Types = require(script.Parent.Types)
local Promise = require(script.Parent.lib.Promise)

type ComputeRequest = Types.ComputeRequest

type SchedulerState = {
	_actors: { Actor },
	_nextWorker: number,
	_resultEvent: BindableEvent,
	_pendingRequests: { [string]: {
		resolve: (any) -> (),
		reject: (string) -> (),
		timeout: number,
	} },
	_initialized: boolean,
}

local Scheduler = {} :: SchedulerState & {
	init: (workerCount: number?, parent: Instance?) -> (),
	compute: (request: ComputeRequest) -> Promise.Promise<{ PathWaypoint }>,
	destroy: () -> (),
}

Scheduler._actors = {}
Scheduler._nextWorker = 1
Scheduler._resultEvent = Instance.new("BindableEvent")
Scheduler._pendingRequests = {}
Scheduler._initialized = false

local function generateId(): string
	return game:GetService("HttpService"):GenerateGUID(false)
end

function Scheduler.init(workerCount: number?, parent: Instance?)
	if Scheduler._initialized then
		return
	end

	local count = workerCount or 4
	local parentFolder = parent or Instance.new("Folder")
	if not parent then
		parentFolder.Parent = workspace
		parentFolder.Name = "PathfindingWorkers"
	end

	for i = 1, count do
		local actor = Instance.new("Actor")
		actor.Name = "Worker_" .. i

		local workerScript = Instance.new("Script")
		workerScript.Name = "Worker"
		workerScript.Source = require(script.Parent.Worker)

		workerScript.Parent = actor
		actor.Parent = parentFolder

		table.insert(Scheduler._actors, actor)
	end

	Scheduler._resultEvent.Event:Connect(function(id: string, waypoints: { PathWaypoint }?, error: string?)
		local request = Scheduler._pendingRequests[id]
		if not request then
			return
		end

		Scheduler._pendingRequests[id] = nil

		if error then
			request.reject(error)
		else
			request.resolve(waypoints or {})
		end
	end)

	Scheduler._initialized = true
end

function Scheduler.compute(request: ComputeRequest): Promise.Promise<{ PathWaypoint }>
	if not Scheduler._initialized then
		Scheduler.init()
	end

	return Promise.new(function(resolve, reject)
		if #Scheduler._actors == 0 then
			reject("No workers initialized")
			return
		end

		local id = generateId()
		request.id = id

		local worker = Scheduler._actors[Scheduler._nextWorker]
		Scheduler._nextWorker = (Scheduler._nextWorker % #Scheduler._actors) + 1

		Scheduler._pendingRequests[id] = {
			resolve = resolve,
			reject = reject,
			timeout = tick() + 5,
		}

		task.defer(function()
			worker:SendMessage("Compute", id, request.start, request.goal, request.agentParams)
		end)

		task.delay(5, function()
			if Scheduler._pendingRequests[id] then
				Scheduler._pendingRequests[id] = nil
				reject("ComputationError")
			end
		end)
	end)
end

function Scheduler.destroy()
	for _, actor in ipairs(Scheduler._actors) do
		actor:Destroy()
	end
	table.clear(Scheduler._actors)
	Scheduler._resultEvent:Destroy()
	Scheduler._initialized = false
end

return Scheduler
