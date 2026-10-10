-- Author -> lolokdev.
-- Last Edit -> September 13, 2026 6:43 PM CDT

local Signal = {} do
	Signal.__index = Signal
	Signal.ClassName = 'Signal'

	-- new -> Signal
	-- Creates a lightweight BindableEvent-backed signal.
	function Signal.new()
		local this = setmetatable({}, Signal)

		this._Bindable = Instance.new('BindableEvent')
		this._Destroyed = false

		return this;
	end

	-- Connect -> RBXScriptConnection
	-- Connects a callback to this signal.
	-- @param Callback, function -> Listener callback.
	function Signal:Connect(Callback)
		assert(not self._Destroyed, 'Signal is destroyed.')
		assert(type(Callback) == 'function', 'Signal callback must be a function.')

		return self._Bindable.Event:Connect(Callback);
	end

	-- Once -> RBXScriptConnection
	-- Connects a callback for a single emission.
	-- @param Callback, function -> Listener callback.
	function Signal:Once(Callback)
		assert(not self._Destroyed, 'Signal is destroyed.')
		assert(type(Callback) == 'function', 'Signal callback must be a function.')

		return self._Bindable.Event:Once(Callback);
	end

	-- Wait -> ...any
	-- Yields until the next signal emission.
	function Signal:Wait()
		assert(not self._Destroyed, 'Signal is destroyed.')

		return self._Bindable.Event:Wait();
	end

	-- Fire -> nil
	-- Emits the signal to every connected listener.
	-- @param ..., any -> Arguments passed to listeners.
	function Signal:Fire(...)
		if self._Destroyed then return end

		self._Bindable:Fire(...)
	end

	-- Destroy -> nil
	-- Disconnects listeners and destroys the backing event.
	function Signal:Destroy()
		if self._Destroyed then return end

		self._Destroyed = true

		self._Bindable:Destroy()
	end
end

return Signal;
