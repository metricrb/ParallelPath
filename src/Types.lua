--!strict

--[=[
	@class Types

	Public type definitions for parallel-path.

	Exports all types needed to use the pathfinding library with full type safety.
]=]

--[=[
	@type SteeringMode = "Humanoid" | "Vehicle" | "Custom"
	@within Types

	Determines how the Agent moves:
	- "Humanoid": Uses Humanoid:MoveTo() directly
	- "Vehicle": Uses VehicleSeat steering with PID control
	- "Custom": Calls user-supplied steering callback
]=]
export type SteeringMode = "Humanoid" | "Vehicle" | "Custom"

export type FailReason = "NoPath" | "ComputationError" | "MaxRetriesExceeded" | "AgentStuck" | "AgentDestroyed"

export type AgentStatus = "Idle" | "Computing" | "Moving" | "Stuck" | "Paused"

export type AgentConfig = {
	-- PathfindingService params passed directly to CreatePath
	agentParams: AgentParameters?,

	-- How close the agent must be to a waypoint to advance (studs)
	waypointReachedRadius: number?,

	-- Recompute path automatically when Path.Blocked fires
	recomputeOnBlock: boolean?,

	-- Max recompute attempts before firing Failed
	maxRetries: number?,

	-- Steering
	steeringMode: SteeringMode,
	steeringCallback: ((position: Vector3, lookAt: Vector3) -> ())?,

	-- Vehicle-only PID tuning
	vehiclePID: { kp: number, ki: number, kd: number }?,

	-- Seconds without meaningful position change before declaring stuck
	stuckTimeout: number?,

	-- Humanoid-only: attempt a jump when stuck
	stuckRecoveryJump: boolean?,

	-- Skip pathfinding entirely and steer direct when dist < this value
	fallbackToDirectMove: boolean?,
	directMoveThreshold: number?,

	-- Debug
	visualise: boolean?,
}

export type ComputeRequest = {
	id: string,
	start: Vector3,
	goal: Vector3,
	agentParams: AgentParameters?,
}

return {}
