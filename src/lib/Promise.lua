--!strict

export type Promise<T> = {
	_status: "pending" | "resolved" | "rejected" | "cancelled",
	_value: T?,
	_error: string?,
	_callbacks: { { resolve: (T) -> (), reject: (string) -> () } },
	_cancelled: boolean,

	andThen: (self: Promise<T>, fn: (T) -> any) -> Promise<any>,
	catch: (self: Promise<T>, fn: (string) -> any) -> Promise<any>,
	cancel: (self: Promise<T>) -> (),
	await: (self: Promise<T>) -> T,
}

type Executor<T> = (resolve: (T) -> (), reject: (string) -> ()) -> ()

local Promise = {}
Promise.__index = Promise

function Promise.new<T>(executor: Executor<T>): Promise<T>
	local self = setmetatable({
		_status = "pending",
		_value = nil,
		_error = nil,
		_callbacks = {},
		_cancelled = false,
	} :: any, Promise) :: Promise<T>

	local function resolve(value: T)
		if self._status ~= "pending" or self._cancelled then
			return
		end
		self._status = "resolved"
		self._value = value
		self:_notify()
	end

	local function reject(error: string)
		if self._status ~= "pending" or self._cancelled then
			return
		end
		self._status = "rejected"
		self._error = error
		self:_notify()
	end

	local ok = pcall(executor, resolve, reject)
	if not ok then
		reject(tostring(ok))
	end

	return self
end

function Promise:_notify()
	for _, callback in ipairs(self._callbacks) do
		if self._status == "resolved" then
			callback.resolve(self._value :: any)
		else
			callback.reject(self._error :: string)
		end
	end
	table.clear(self._callbacks)
end

function Promise:andThen<U>(fn: (T) -> U): Promise<U>
	local newPromise = Promise.new(function(resolve, reject)
		if self._status == "pending" then
			table.insert(self._callbacks, {
				resolve = function(value: any)
					local ok, result = pcall(fn, value)
					if ok then
						resolve(result)
					else
						reject(tostring(result))
					end
				end,
				reject = reject,
			})
		elseif self._status == "resolved" then
			local ok, result = pcall(fn, self._value :: any)
			if ok then
				resolve(result)
			else
				reject(tostring(result))
			end
		else
			reject(self._error :: string)
		end
	end) :: Promise<U>

	return newPromise
end

function Promise:catch<U>(fn: (string) -> U): Promise<U>
	local newPromise = Promise.new(function(resolve, reject)
		if self._status == "pending" then
			table.insert(self._callbacks, {
				resolve = function(value: any)
					resolve(value)
				end,
				reject = function(error: string)
					local ok, result = pcall(fn, error)
					if ok then
						resolve(result :: any)
					else
						reject(tostring(result))
					end
				end,
			})
		elseif self._status == "resolved" then
			resolve(self._value :: any)
		else
			local ok, result = pcall(fn, self._error :: string)
			if ok then
				resolve(result :: any)
			else
				reject(tostring(result))
			end
		end
	end) :: Promise<U>

	return newPromise
end

function Promise:cancel()
	if self._status == "pending" then
		self._cancelled = true
		self._status = "cancelled"
		table.clear(self._callbacks)
	end
end

function Promise:await(): T
	if self._status == "pending" then
		local thread = coroutine.running()
		table.insert(self._callbacks, {
			resolve = function(value: any)
				task.spawn(thread, true, value)
			end,
			reject = function(error: string)
				task.spawn(thread, false, error)
			end,
		})
		local ok, result = coroutine.yield()
		if ok then
			return result
		else
			error(result)
		end
	elseif self._status == "resolved" then
		return self._value :: T
	else
		error(self._error or "Promise rejected")
	end
end

return Promise
