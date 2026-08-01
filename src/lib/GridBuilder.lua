--!strict

type GridBuilder = {
	_cellSize: number,
	_height: number,
	_grid: { { boolean } },
	_minBounds: Vector3,
	_maxBounds: Vector3,
	_initialized: boolean,

	build: (self: GridBuilder) -> (),
	isWalkable: (self: GridBuilder, position: Vector3) -> boolean,
	getNearestWalkable: (self: GridBuilder, position: Vector3) -> Vector3?,
}

local GridBuilder = {}
GridBuilder.__index = GridBuilder

function GridBuilder.new(cellSize: number?, scanHeight: number?): GridBuilder
	return setmetatable({
		_cellSize = cellSize or 4,
		_height = scanHeight or 50,
		_grid = {},
		_minBounds = Vector3.new(-256, 0, -256),
		_maxBounds = Vector3.new(256, 0, 256),
		_initialized = false,
	} :: any, GridBuilder) :: GridBuilder
end

function GridBuilder:build()
	local width = math.ceil((self._maxBounds.X - self._minBounds.X) / self._cellSize)
	local depth = math.ceil((self._maxBounds.Z - self._minBounds.Z) / self._cellSize)

	for x = 1, width do
		self._grid[x] = {}
		for z = 1, depth do
			self._grid[x][z] = self:_isCellWalkable(x, z)
		end
	end

	self._initialized = true
end

function GridBuilder:_isCellWalkable(gridX: number, gridZ: number): boolean
	local cellX = self._minBounds.X + (gridX - 0.5) * self._cellSize
	local cellZ = self._minBounds.Z + (gridZ - 0.5) * self._cellSize
	local cellPos = Vector3.new(cellX, self._minBounds.Y + self._height / 2, cellZ)

	local region = Region3.new(
		cellPos - Vector3.new(self._cellSize / 2, self._height / 2, self._cellSize / 2),
		cellPos + Vector3.new(self._cellSize / 2, self._height / 2, self._cellSize / 2)
	)
	region = region:ExpandToGrid(4)

	local parts = workspace:FindPartBoundsInRadius(cellPos, math.sqrt(2) * self._cellSize / 2)
	for _, part in ipairs(parts) do
		if part.CanCollide and not part.Parent:FindFirstChildOfClass("Humanoid") then
			return false
		end
	end

	return true
end

function GridBuilder:isWalkable(position: Vector3): boolean
	if not self._initialized then
		return true
	end

	local gridX = math.floor((position.X - self._minBounds.X) / self._cellSize) + 1
	local gridZ = math.floor((position.Z - self._minBounds.Z) / self._cellSize) + 1

	if gridX < 1 or gridX > #self._grid or gridZ < 1 or gridZ > #self._grid[1] then
		return false
	end

	return self._grid[gridX][gridZ]
end

function GridBuilder:getNearestWalkable(position: Vector3): Vector3?
	if not self._initialized then
		return position
	end

	if self:isWalkable(position) then
		return position
	end

	local gridX = math.floor((position.X - self._minBounds.X) / self._cellSize) + 1
	local gridZ = math.floor((position.Z - self._minBounds.Z) / self._cellSize) + 1

	local searchRadius = 5
	local best: Vector3? = nil
	local bestDist = math.huge

	for x = gridX - searchRadius, gridX + searchRadius do
		for z = gridZ - searchRadius, gridZ + searchRadius do
			if x >= 1 and x <= #self._grid and z >= 1 and z <= #self._grid[1] then
				if self._grid[x][z] then
					local cellX = self._minBounds.X + (x - 0.5) * self._cellSize
					local cellZ = self._minBounds.Z + (z - 0.5) * self._cellSize
					local cellPos = Vector3.new(cellX, position.Y, cellZ)
					local dist = (cellPos - position).Magnitude
					if dist < bestDist then
						best = cellPos
						bestDist = dist
					end
				end
			end
		end
	end

	return best
end

return GridBuilder
