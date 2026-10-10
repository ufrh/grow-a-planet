local HttpService = game:GetService('HttpService')

local Persistence = {} do
	Persistence.Version = 1
	Persistence.ChunkSize = 180000
	Persistence.Prefix = 'FORGEStudio_Project'

	local function enumItem(Value)
		local Text = tostring(Value)
		local EnumType, Item = Text:match('^Enum%.([^%.]+)%.(.+)$')
		if not EnumType or not Item then return nil end

		local Type = Enum[EnumType]
		return Type and Type[Item] or nil
	end

	local function encode(Value)
		local Type = typeof(Value)

		if Value == nil or Type == 'string' or Type == 'number' or Type == 'boolean' then
			return Value
		end

		if Type == 'EnumItem' then
			return {__FORGEType = 'EnumItem', Value = tostring(Value)}
		elseif Type == 'Color3' then
			return {__FORGEType = 'Color3', R = Value.R, G = Value.G, B = Value.B}
		elseif Type == 'Vector2' then
			return {__FORGEType = 'Vector2', X = Value.X, Y = Value.Y}
		elseif Type == 'Vector3' then
			return {__FORGEType = 'Vector3', X = Value.X, Y = Value.Y, Z = Value.Z}
		elseif Type == 'UDim' then
			return {__FORGEType = 'UDim', Scale = Value.Scale, Offset = Value.Offset}
		elseif Type == 'UDim2' then
			return {
				__FORGEType = 'UDim2',
				XS = Value.X.Scale,
				XO = Value.X.Offset,
				YS = Value.Y.Scale,
				YO = Value.Y.Offset
			}
		elseif Type == 'Rect' then
			return {
				__FORGEType = 'Rect',
				MinX = Value.Min.X,
				MinY = Value.Min.Y,
				MaxX = Value.Max.X,
				MaxY = Value.Max.Y
			}
		elseif Type == 'NumberRange' then
			return {__FORGEType = 'NumberRange', Min = Value.Min, Max = Value.Max}
		elseif Type == 'BrickColor' then
			return {__FORGEType = 'BrickColor', Name = Value.Name}
		elseif Type == 'CFrame' then
			return {__FORGEType = 'CFrame', Components = {Value:GetComponents()}}
		elseif Type == 'Font' then
			return {
				__FORGEType = 'Font',
				Family = Value.Family,
				Weight = tostring(Value.Weight),
				Style = tostring(Value.Style)
			}
		elseif Type == 'ColorSequence' then
			local Points = {}
			for _, Point in ipairs(Value.Keypoints) do
				table.insert(Points, {
					Time = Point.Time,
					R = Point.Value.R,
					G = Point.Value.G,
					B = Point.Value.B
				})
			end
			return {__FORGEType = 'ColorSequence', Keypoints = Points}
		elseif Type == 'NumberSequence' then
			local Points = {}
			for _, Point in ipairs(Value.Keypoints) do
				table.insert(Points, {
					Time = Point.Time,
					Value = Point.Value,
					Envelope = Point.Envelope
				})
			end
			return {__FORGEType = 'NumberSequence', Keypoints = Points}
		elseif Type ~= 'table' then
			error('Unsupported FORGE Studio persistence value: ' .. Type)
		end

		local Entries = {}
		for Key, Child in pairs(Value) do
			table.insert(Entries, {
				Key = encode(Key),
				Value = encode(Child)
			})
		end

		return {
			__FORGEType = 'Table',
			Entries = Entries
		}
	end

	local function decode(Value)
		if type(Value) ~= 'table' then return Value end

		local Type = Value.__FORGEType
		if Type == 'EnumItem' then
			return enumItem(Value.Value)
		elseif Type == 'Color3' then
			return Color3.new(Value.R or 0, Value.G or 0, Value.B or 0)
		elseif Type == 'Vector2' then
			return Vector2.new(Value.X or 0, Value.Y or 0)
		elseif Type == 'Vector3' then
			return Vector3.new(Value.X or 0, Value.Y or 0, Value.Z or 0)
		elseif Type == 'UDim' then
			return UDim.new(Value.Scale or 0, Value.Offset or 0)
		elseif Type == 'UDim2' then
			return UDim2.new(Value.XS or 0, Value.XO or 0, Value.YS or 0, Value.YO or 0)
		elseif Type == 'Rect' then
			return Rect.new(Value.MinX or 0, Value.MinY or 0, Value.MaxX or 0, Value.MaxY or 0)
		elseif Type == 'NumberRange' then
			return NumberRange.new(Value.Min or 0, Value.Max or Value.Min or 0)
		elseif Type == 'BrickColor' then
			return BrickColor.new(Value.Name or 'Medium stone grey')
		elseif Type == 'CFrame' then
			return CFrame.new(table.unpack(Value.Components or {}))
		elseif Type == 'Font' then
			return Font.new(
				Value.Family or 'rbxasset://fonts/families/SourceSansPro.json',
				enumItem(Value.Weight) or Enum.FontWeight.Regular,
				enumItem(Value.Style) or Enum.FontStyle.Normal
			)
		elseif Type == 'ColorSequence' then
			local Points = {}
			for _, Point in ipairs(Value.Keypoints or {}) do
				table.insert(Points, ColorSequenceKeypoint.new(
					Point.Time or 0,
					Color3.new(Point.R or 0, Point.G or 0, Point.B or 0)
				))
			end
			return ColorSequence.new(Points)
		elseif Type == 'NumberSequence' then
			local Points = {}
			for _, Point in ipairs(Value.Keypoints or {}) do
				table.insert(Points, NumberSequenceKeypoint.new(
					Point.Time or 0,
					Point.Value or 0,
					Point.Envelope or 0
				))
			end
			return NumberSequence.new(Points)
		elseif Type == 'Table' then
			local Result = {}
			for _, Entry in ipairs(Value.Entries or {}) do
				Result[decode(Entry.Key)] = decode(Entry.Value)
			end
			return Result
		end

		local Result = {}
		for Key, Child in pairs(Value) do Result[Key] = decode(Child) end
		return Result
	end

	local function isArray(Value)
		local Count, Maximum = 0, 0
		for Key in pairs(Value) do
			if type(Key) ~= 'number' or Key < 1 or Key % 1 ~= 0 then return false end
			Count += 1
			Maximum = math.max(Maximum, Key)
		end
		return Count == Maximum
	end

	local function encodeCompact(Value, State)
		State = State or {Count = 0}
		State.Count += 1
		if State.Count % 1200 == 0 then task.wait() end
		local Type = typeof(Value)

		if Value == nil or Type == 'string' or Type == 'number' or Type == 'boolean' then
			return Value
		end

		if Type == 'EnumItem' then
			return {'E', tostring(Value)}
		elseif Type == 'Color3' then
			return {'C', Value.R, Value.G, Value.B}
		elseif Type == 'Vector2' then
			return {'V2', Value.X, Value.Y}
		elseif Type == 'Vector3' then
			return {'V3', Value.X, Value.Y, Value.Z}
		elseif Type == 'UDim' then
			return {'U', Value.Scale, Value.Offset}
		elseif Type == 'UDim2' then
			return {'U2', Value.X.Scale, Value.X.Offset, Value.Y.Scale, Value.Y.Offset}
		elseif Type == 'Rect' then
			return {'R', Value.Min.X, Value.Min.Y, Value.Max.X, Value.Max.Y}
		elseif Type == 'NumberRange' then
			return {'NR', Value.Min, Value.Max}
		elseif Type == 'BrickColor' then
			return {'B', Value.Name}
		elseif Type == 'CFrame' then
			local Result = {'CF'}
			for _, Component in ipairs({Value:GetComponents()}) do table.insert(Result, Component) end
			return Result
		elseif Type == 'Font' then
			return {'F', Value.Family, tostring(Value.Weight), tostring(Value.Style)}
		elseif Type == 'ColorSequence' then
			local Result = {'CS'}
			for _, Point in ipairs(Value.Keypoints) do
				table.insert(Result, {Point.Time, Point.Value.R, Point.Value.G, Point.Value.B})
			end
			return Result
		elseif Type == 'NumberSequence' then
			local Result = {'NS'}
			for _, Point in ipairs(Value.Keypoints) do
				table.insert(Result, {Point.Time, Point.Value, Point.Envelope})
			end
			return Result
		elseif Type ~= 'table' then
			error('Unsupported FORGE Studio persistence value: ' .. Type)
		end

		if isArray(Value) then
			local Result = {'A'}
			for Index = 1, #Value do table.insert(Result, encodeCompact(Value[Index], State)) end
			return Result
		end

		local Result = {'M'}
		for Key, Child in pairs(Value) do
			table.insert(Result, encodeCompact(Key, State))
			table.insert(Result, encodeCompact(Child, State))
		end
		return Result
	end

	local function decodeCompact(Value)
		if type(Value) ~= 'table' then return Value end
		local Tag = Value[1]

		if Tag == 'E' then return enumItem(Value[2])
		elseif Tag == 'C' then return Color3.new(Value[2] or 0, Value[3] or 0, Value[4] or 0)
		elseif Tag == 'V2' then return Vector2.new(Value[2] or 0, Value[3] or 0)
		elseif Tag == 'V3' then return Vector3.new(Value[2] or 0, Value[3] or 0, Value[4] or 0)
		elseif Tag == 'U' then return UDim.new(Value[2] or 0, Value[3] or 0)
		elseif Tag == 'U2' then return UDim2.new(Value[2] or 0, Value[3] or 0, Value[4] or 0, Value[5] or 0)
		elseif Tag == 'R' then return Rect.new(Value[2] or 0, Value[3] or 0, Value[4] or 0, Value[5] or 0)
		elseif Tag == 'NR' then return NumberRange.new(Value[2] or 0, Value[3] or Value[2] or 0)
		elseif Tag == 'B' then return BrickColor.new(Value[2] or 'Medium stone grey')
		elseif Tag == 'CF' then
			local Components = {}
			for Index = 2, #Value do Components[Index - 1] = Value[Index] end
			return CFrame.new(table.unpack(Components))
		elseif Tag == 'F' then
			return Font.new(
				Value[2] or 'rbxasset://fonts/families/SourceSansPro.json',
				enumItem(Value[3]) or Enum.FontWeight.Regular,
				enumItem(Value[4]) or Enum.FontStyle.Normal
			)
		elseif Tag == 'CS' then
			local Points = {}
			for Index = 2, #Value do
				local Point = Value[Index]
				table.insert(Points, ColorSequenceKeypoint.new(
					Point[1] or 0,
					Color3.new(Point[2] or 0, Point[3] or 0, Point[4] or 0)
				))
			end
			return ColorSequence.new(Points)
		elseif Tag == 'NS' then
			local Points = {}
			for Index = 2, #Value do
				local Point = Value[Index]
				table.insert(Points, NumberSequenceKeypoint.new(
					Point[1] or 0,
					Point[2] or 0,
					Point[3] or 0
				))
			end
			return NumberSequence.new(Points)
		elseif Tag == 'A' then
			local Result = {}
			for Index = 2, #Value do Result[Index - 1] = decodeCompact(Value[Index]) end
			return Result
		elseif Tag == 'M' then
			local Result = {}
			for Index = 2, #Value, 2 do
				Result[decodeCompact(Value[Index])] = decodeCompact(Value[Index + 1])
			end
			return Result
		end

		return decode(Value)
	end

	local function identity()
		local Universe = tonumber(game.GameId) or 0
		local Place = tonumber(game.PlaceId) or 0
		return string.format('%s_v%d_%d_%d', Persistence.Prefix, Persistence.Version, Universe, Place)
	end

	local function legacyIdentity()
		local Universe = tonumber(game.GameId) or 0
		local Place = tonumber(game.PlaceId) or 0
		return string.format('FORGEStudio.Project.v%d.%d.%d', Persistence.Version, Universe, Place)
	end

	local function slotPrefix(Base, Slot)
		return Base .. '_Slot_' .. Slot
	end

	local function setting(Plugin, Key)
		local Success, Value = pcall(Plugin.GetSetting, Plugin, Key)
		return Success and Value or nil
	end

	local function setSetting(Plugin, Key, Value)
		local Success, Error = pcall(Plugin.SetSetting, Plugin, Key, Value)
		return Success, Error
	end

	local function verifySetting(Plugin, Key, Expected)
		for Attempt = 1, 5 do
			local Value = setting(Plugin, Key)
			if Value == Expected then return true end
			if Attempt < 5 then task.wait(.04 * Attempt) end
		end
		return false
	end

	local function checksum(Source)
		local A, B = 1, 0
		for Index = 1, #Source do
			A = (A + string.byte(Source, Index)) % 65521
			B = (B + A) % 65521
			if Index % 750000 == 0 then task.wait() end
		end
		return string.format('%08X', B * 65536 + A)
	end

	local function readManifest(Plugin, Key)
		local Raw = setting(Plugin, Key)
		if type(Raw) ~= 'string' then return nil end

		local Success, Value = pcall(HttpService.JSONDecode, HttpService, Raw)
		return Success and type(Value) == 'table' and Value or nil
	end

	local function decodePayload(Source)
		local Success, Payload = pcall(HttpService.JSONDecode, HttpService, Source)
		if not Success or type(Payload) ~= 'table' then
			return nil, 'decode failed: ' .. tostring(Payload)
		end

		local Version = tonumber(Payload.V or Payload.Version)
		if Version ~= Persistence.Version then return nil, 'unsupported persistence version' end

		local Codec = tonumber(Payload.C or Payload.Codec) or 1
		local EncodedData = Payload.D ~= nil and Payload.D or Payload.Data
		local DecodeSuccess, Data = pcall(Codec == 2 and decodeCompact or decode, EncodedData)
		if not DecodeSuccess or type(Data) ~= 'table' then
			return nil, 'project reconstruction failed: ' .. tostring(Data)
		end
		return Data
	end

	local function loadSlot(Plugin, Base, Slot, LegacyKeys)
		local Prefix = LegacyKeys and (Base .. '.Slot.' .. Slot) or slotPrefix(Base, Slot)
		local ManifestKey = Prefix .. (LegacyKeys and '.Manifest' or '_Manifest')
		local ChunkKey = function(Index)
			return Prefix .. (LegacyKeys and '.Chunk.' or '_Chunk_') .. Index
		end

		local Manifest = readManifest(Plugin, ManifestKey)
		if not Manifest or tonumber(Manifest.Format) ~= 2 then
			return nil, 'slot manifest missing'
		end

		local Chunks = tonumber(Manifest.Chunks) or 0
		if Chunks <= 0 then return nil, 'slot manifest has no chunks' end

		local Parts = table.create(Chunks)
		for Index = 1, Chunks do
			local Chunk = setting(Plugin, ChunkKey(Index))
			if type(Chunk) ~= 'string' then
				return nil, 'slot is missing chunk ' .. Index
			end
			Parts[Index] = Chunk
		end

		local Source = table.concat(Parts)
		if tonumber(Manifest.Bytes) and #Source ~= tonumber(Manifest.Bytes) then
			return nil, 'slot byte count mismatch'
		end
		if Manifest.Checksum and checksum(Source) ~= Manifest.Checksum then
			return nil, 'slot checksum mismatch'
		end

		local Data, Error = decodePayload(Source)
		if not Data then return nil, Error end

		Manifest.Slot = Slot
		return Data, Manifest
	end

	local function loadLegacy(Plugin, Base)
		local Manifest = readManifest(Plugin, Base .. '.Manifest')
		if not Manifest or tonumber(Manifest.Version) ~= Persistence.Version then
			return nil, 'no legacy saved project'
		end

		local Chunks = tonumber(Manifest.Chunks) or 0
		if Chunks <= 0 then return nil, 'legacy manifest has no chunks' end

		local Parts = table.create(Chunks)
		for Index = 1, Chunks do
			local Chunk = setting(Plugin, Base .. '.Chunk.' .. Index)
			if type(Chunk) ~= 'string' then
				return nil, 'legacy save is missing chunk ' .. Index
			end
			Parts[Index] = Chunk
		end

		local Data, Error = decodePayload(table.concat(Parts))
		if not Data then return nil, Error end
		Manifest.Legacy = true
		return Data, Manifest
	end

	function Persistence:GetKey()
		return identity()
	end

	function Persistence:Save(Plugin, Data)
		assert(Plugin, 'FORGE Studio Persistence requires plugin.')
		assert(type(Data) == 'table', 'FORGE Studio Persistence requires project data.')

		local SavedAt = os.time()
		local StartedAt = os.clock()
		local Success, Encoded = pcall(function()
			return HttpService:JSONEncode({
				V = self.Version,
				C = 2,
				S = SavedAt,
				D = encodeCompact(Data)
			})
		end)
		if not Success then return false, 'encode failed: ' .. tostring(Encoded) end
		local EncodeSeconds = os.clock() - StartedAt
		local WriteStartedAt = os.clock()

		local Base = identity()
		local ActiveKey = Base .. '_ActiveSlot'
		local Active = setting(Plugin, ActiveKey)
		if Active ~= 'A' and Active ~= 'B' then Active = nil end

		local Target = Active == 'A' and 'B' or 'A'
		local Prefix = slotPrefix(Base, Target)
		local ManifestKey = Prefix .. '_Manifest'
		local Previous = readManifest(Plugin, ManifestKey)
		local PreviousChunks = Previous and tonumber(Previous.Chunks) or 0
		local Chunks = math.max(1, math.ceil(#Encoded / self.ChunkSize))

		for Index = 1, Chunks do
			local Start = (Index - 1) * self.ChunkSize + 1
			local Chunk = string.sub(Encoded, Start, Start + self.ChunkSize - 1)
			local Key = Prefix .. '_Chunk_' .. Index
			local Written, Error = setSetting(Plugin, Key, Chunk)
			if not Written then
				return false, 'slot ' .. Target .. ' chunk ' .. Index .. ' failed: ' .. tostring(Error)
			end
			if Index < Chunks then task.wait() end
		end

		local Manifest = {
			Format = 2,
			Version = self.Version,
			Chunks = Chunks,
			Bytes = #Encoded,
			Checksum = checksum(Encoded),
			SavedAt = SavedAt,
			GameId = game.GameId,
			PlaceId = game.PlaceId,
			Slot = Target
		}

		local ManifestSource = HttpService:JSONEncode(Manifest)
		local ManifestWritten, ManifestError = setSetting(Plugin, ManifestKey, ManifestSource)
		if not ManifestWritten then
			return false, 'slot ' .. Target .. ' manifest failed: ' .. tostring(ManifestError)
		end
		if not verifySetting(Plugin, ManifestKey, ManifestSource) then
			return false, 'slot ' .. Target .. ' manifest verification timed out'
		end

		local PointerWritten, PointerError = setSetting(Plugin, ActiveKey, Target)
		if not PointerWritten then
			return false, 'active slot commit failed: ' .. tostring(PointerError)
		end
		if not verifySetting(Plugin, ActiveKey, Target) then
			return false, 'active slot commit verification timed out'
		end

		for Index = Chunks + 1, PreviousChunks do
			setSetting(Plugin, Prefix .. '_Chunk_' .. Index, nil)
		end

		Manifest.Bytes = #Encoded
		Manifest.EncodeSeconds = EncodeSeconds
		Manifest.WriteSeconds = os.clock() - WriteStartedAt
		return true, Manifest
	end

	function Persistence:Load(Plugin)
		assert(Plugin, 'FORGE Studio Persistence requires plugin.')

		local Base = identity()
		local Active = setting(Plugin, Base .. '_ActiveSlot')
		local Tried = {}

		local function Try(CurrentBase, Slot, Recovered, LegacyKeys)
			local Key = tostring(CurrentBase) .. ':' .. tostring(Slot) .. ':' .. tostring(LegacyKeys)
			if Slot ~= 'A' and Slot ~= 'B' or Tried[Key] then return nil end
			Tried[Key] = true

			local Data, Manifest = loadSlot(Plugin, CurrentBase, Slot, LegacyKeys)
			if Data then
				Manifest.Recovered = Recovered == true
				return Data, Manifest
			end
			return nil
		end

		local Data, Manifest = Try(Base, Active, false, false)
		if Data then return Data, Manifest end

		local Fallback = Active == 'A' and 'B' or Active == 'B' and 'A' or 'A'
		Data, Manifest = Try(Base, Fallback, true, false)
		if Data then return Data, Manifest end
		Data, Manifest = Try(Base, 'B', true, false)
		if Data then return Data, Manifest end

		local LegacyBase = legacyIdentity()
		local LegacyActive = setting(Plugin, LegacyBase .. '.ActiveSlot')
		Data, Manifest = Try(LegacyBase, LegacyActive, true, true)
		if Data then return Data, Manifest end

		local LegacyFallback = LegacyActive == 'A' and 'B' or LegacyActive == 'B' and 'A' or 'A'
		Data, Manifest = Try(LegacyBase, LegacyFallback, true, true)
		if Data then return Data, Manifest end
		Data, Manifest = Try(LegacyBase, 'B', true, true)
		if Data then return Data, Manifest end

		Data, Manifest = loadLegacy(Plugin, LegacyBase)
		if Data then
			Manifest.Recovered = true
			return Data, Manifest
		end

		return nil, 'no valid saved project'
	end

	function Persistence:LoadPrevious(Plugin)
		assert(Plugin, 'FORGE Studio Persistence requires plugin.')

		local Base = identity()
		local Active = setting(Plugin, Base .. '_ActiveSlot')
		local Previous = Active == 'A' and 'B' or Active == 'B' and 'A' or nil
		if not Previous then return nil, 'no previous save slot is available' end

		local Data, Manifest = loadSlot(Plugin, Base, Previous, false)
		if not Data then return nil, Manifest or 'previous save slot could not be loaded' end
		Manifest.Recovered = true
		Manifest.Previous = true
		return Data, Manifest
	end

	function Persistence:Clear(Plugin)
		local Base = identity()
		for _, Slot in ipairs({'A', 'B'}) do
			local Prefix = slotPrefix(Base, Slot)
			local Manifest = readManifest(Plugin, Prefix .. '_Manifest')
			local Chunks = Manifest and tonumber(Manifest.Chunks) or 0
			for Index = 1, Chunks do
				setSetting(Plugin, Prefix .. '_Chunk_' .. Index, nil)
			end
			setSetting(Plugin, Prefix .. '_Manifest', nil)
		end
		setSetting(Plugin, Base .. '_ActiveSlot', nil)

		local LegacyBase = legacyIdentity()
		for _, Slot in ipairs({'A', 'B'}) do
			local Prefix = LegacyBase .. '.Slot.' .. Slot
			local Manifest = readManifest(Plugin, Prefix .. '.Manifest')
			local Chunks = Manifest and tonumber(Manifest.Chunks) or 0
			for Index = 1, Chunks do
				setSetting(Plugin, Prefix .. '.Chunk.' .. Index, nil)
			end
			setSetting(Plugin, Prefix .. '.Manifest', nil)
		end
		setSetting(Plugin, LegacyBase .. '.ActiveSlot', nil)

		local Legacy = readManifest(Plugin, LegacyBase .. '.Manifest')
		local LegacyChunks = Legacy and tonumber(Legacy.Chunks) or 0
		for Index = 1, LegacyChunks do
			setSetting(Plugin, LegacyBase .. '.Chunk.' .. Index, nil)
		end
		setSetting(Plugin, LegacyBase .. '.Manifest', nil)
	end
end

return Persistence
