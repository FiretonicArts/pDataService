local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local pDataService = {}
pDataService.ActiveProfiles = {}
pDataService.DataStoreKey = "CHANGE_ME"
pDataService.DataVersion = 1
pDataService.AutoSaveInterval = 10

if pDataService.DataStoreKey == "CHANGE_ME" then
	warn("pDataService WARNING! - Please change the DataStoreKey for enhanced data security.")
end

function pDataService:GetDataStore(name)
	return DataStoreService:GetDataStore(name)
end

function pDataService:GenerateKey(key)
	return self.DataStoreKey .. key
end

function pDataService:ValidateData(data, defaultData)
	for key, value in pairs(defaultData) do
		if data[key] == nil then
			data[key] = value
		end
	end
	return data
end

function pDataService:SaveData(store, key, data)
	local success, result = pcall(function()
		store:SetAsync(self:GenerateKey(key), data)
	end)
	if not success then
		warn("SaveData Error:", result)
	end
	return success, result
end

function pDataService:LoadData(store, key, defaultData)
	local success, result
	for attempt = 1, 3 do
		success, result = pcall(function()
			return store:GetAsync(self:GenerateKey(key))
		end)
		if success then
			return self:ValidateData(result or {}, defaultData)
		else
			warn("LoadData Retry Attempt", attempt, "Failed:", result)
			wait(2)
		end
	end
	return defaultData
end

function pDataService:LoadProfile(playerId, defaultData)
	if self.ActiveProfiles[playerId] then
		return nil
	end

	local profileStore = self:GetDataStore("PlayerProfiles")
	local data = self:LoadData(profileStore, tostring(playerId), defaultData)

	self.ActiveProfiles[playerId] = { data = data, locked = false, lastSaved = os.time() }
	return data
end

function pDataService:SaveProfile(playerId)
	local profile = self.ActiveProfiles[playerId]
	if profile and not profile.locked then
		local store = self:GetDataStore("PlayerProfiles")
		local success, result = self:SaveData(store, tostring(playerId), profile.data)
		if success then
			profile.lastSaved = os.time()
		else
			warn("Failed to save profile for player:", playerId)
		end
	end
end

function pDataService:ReleaseProfile(playerId)
	if self.ActiveProfiles[playerId] then
		self.ActiveProfiles[playerId] = nil
	end
end

function pDataService:SaveGlobalData(key, data)
	local store = self:GetDataStore("GlobalData")
	return self:SaveData(store, key, data)
end

function pDataService:LoadGlobalData(key, defaultData)
	local store = self:GetDataStore("GlobalData")
	return self:LoadData(store, key, defaultData)
end

function pDataService:AutoSaveProfiles()
	while true do
		wait(self.AutoSaveInterval)
		for playerId, profile in pairs(self.ActiveProfiles) do
			if not profile.locked then
				self:SaveProfile(playerId)
			end
		end
	end
end

function pDataService:LockProfile(playerId)
	local profile = self.ActiveProfiles[playerId]
	if profile then
		profile.locked = true
	end
end

function pDataService:UnlockProfile(playerId)
	local profile = self.ActiveProfiles[playerId]
	if profile then
		profile.locked = false
	end
end

function pDataService:IsProfileLocked(playerId)
	local profile = self.ActiveProfiles[playerId]
	return profile and profile.locked or false
end

function pDataService:GetLastSaveTime(playerId)
	local profile = self.ActiveProfiles[playerId]
	return profile and profile.lastSaved or nil
end

function pDataService:UpdateProfile(playerId, updates)
	local profile = self.ActiveProfiles[playerId]
	if profile then
		for key, value in pairs(updates) do
			profile.data[key] = value
		end
		profile.locked = false
	end
end

coroutine.wrap(function()
	pDataService:AutoSaveProfiles()
end)()

return pDataService
