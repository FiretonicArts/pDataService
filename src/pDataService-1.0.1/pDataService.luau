local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Config = require(script.Config)

local pDataService = {}
pDataService.ActiveProfiles = {}
pDataService.DataStoreKey = Config.DataStoreKey or "GameData"
pDataService.DataVersion = Config.DataVersion or "1.0"
pDataService.AutoSaveInterval = Config.AutoSaveInterval or 60
pDataService.ProfileBackupInterval = Config.ProfileBackupInterval or 300
pDataService.RequestRateLimit = Config.RequestRateLimit or 5
pDataService.lastSaveTime = {}
pDataService.ProfileLocks = {}
pDataService.MaxRetries = Config.MaxRetries or 3
pDataService.UseBackup = Config.UseBackup or true
pDataService.BackupKeySuffix = Config.BackupKeySuffix or "_backup"
pDataService.CompressionEnabled = Config.CompressionEnabled or true
pDataService.ProfileExpirationTime = Config.ProfileExpirationTime or 3600
pDataService.ChangeLog = {}
pDataService.BatchSaveQueue = {}
pDataService.Stats = {}
pDataService.Snapshots = {}
pDataService.Configuration = Config
pDataService.EventHooks = {
	OnProfileLoad = {},
	OnProfileSave = {},
	OnProfileDelete = {},
}

local ERROR_SAVE_FAIL = "Failed to save profile for player: "
local ERROR_LOAD_FAIL = "Failed to load profile for player: "
local ERROR_BACKUP_FAIL = "Failed to create backup for player: "
local ERROR_RESTORE_FAIL = "Failed to restore backup for player: "
local LOG_PREFIX = "[pDataService]"

function pDataService:Log(message, level)
	level = level or "INFO"
	print(string.format("[%s][%s] %s", os.date("%Y-%m-%d %H:%M:%S"), level, message))
end

function pDataService:GenerateKey(playerId)
	return self.DataStoreKey .. "_" .. tostring(playerId)
end

function pDataService:GetDataStore()
	return DataStoreService:GetDataStore(self.DataStoreKey)
end

function pDataService:CompressData(data)
	return self.CompressionEnabled and HttpService:JSONEncode(data) or data
end

function pDataService:DecompressData(data)
	return self.CompressionEnabled and HttpService:JSONDecode(data) or data
end

function pDataService:RateLimit(playerId)
	self.lastSaveTime[playerId] = self.lastSaveTime[playerId] or 0
	if os.time() - self.lastSaveTime[playerId] < self.RequestRateLimit then
		return false
	end
	self.lastSaveTime[playerId] = os.time()
	return true
end

function pDataService:ValidateData(data)
	if type(data) ~= "table" or next(data) == nil then
		self:Log("Invalid data: Data is either not a table or is empty.", "ERROR")
		return false
	end

	local requiredFields = {"username", "level", "experience"}
	for _, field in ipairs(requiredFields) do
		if data[field] == nil then
			self:Log("Invalid data: Missing required field '" .. field .. "'.", "ERROR")
			return false
		end
	end

	if type(data.username) ~= "string" or #data.username == 0 then
		self:Log("Invalid data: 'username' must be a non-empty string.", "ERROR")
		return false
	end

	if type(data.level) ~= "number" or data.level < 0 then
		self:Log("Invalid data: 'level' must be a non-negative number.", "ERROR")
		return false
	end

	if type(data.experience) ~= "number" or data.experience < 0 then
		self:Log("Invalid data: 'experience' must be a non-negative number.", "ERROR")
		return false
	end

	self:Log("Data validation successful.", "INFO")
	return true
end

function pDataService:LoadProfile(playerId, defaultData)
	if self.ActiveProfiles[playerId] then
		return nil
	end

	local data = self:LoadData(tostring(playerId), defaultData)
	if not data then
		self:Log("Failed to load data for playerId: " .. playerId, "ERROR")
		return defaultData
	end

	data.version = self.DataVersion
	self.ActiveProfiles[playerId] = { data = data, locked = false, lastSaved = os.time(), version = data.version }
	return data
end

function pDataService:SaveProfile(playerId)
	local profile = self.ActiveProfiles[playerId]
	if profile and not profile.locked then
		local store = self:GetDataStore()
		local success, result = self:SaveData(store, tostring(playerId), profile.data)
		if success then
			profile.lastSaved = os.time()
			if os.time() - (profile.backupTime or 0) > self.ProfileBackupInterval then
				self:BackupProfile(playerId)
				profile.backupTime = os.time()
			end
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

function pDataService:BackupProfile(playerId)
	local profile = self.ActiveProfiles[playerId]
	if profile then
		local store = self:GetDataStore()
		local key = self:GenerateKey(playerId) .. self.BackupKeySuffix
		local success, result = self:SaveData(store, key, profile.data)

		if not success then
			self:Log(ERROR_BACKUP_FAIL .. playerId, "WARNING")
		end
	end
end

function pDataService:RestoreBackup(playerId)
	local store = self:GetDataStore()
	local key = self:GenerateKey(playerId) .. self.BackupKeySuffix
	local data = self:LoadData(key)

	if data then
		self:UpdateProfile(playerId, data)
	else
		self:Log(ERROR_RESTORE_FAIL .. playerId, "WARNING")
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

function pDataService:AsyncSaveData(playerId, data)
	if not self:ValidateData(data) then
		self:Log("Data validation failed for player: " .. tostring(playerId), "ERROR")  
		return false
	end

	local store = self:GetDataStore()
	local key = self:GenerateKey(playerId)  
	data = self:CompressData(data)

	coroutine.wrap(function()
		local success, result = false, nil
		for attempt = 1, self.MaxRetries do
			success, result = pcall(function()
				return store:SetAsync(key, data)
			end)

			if success then
				self.Stats[playerId] = (self.Stats[playerId] or 0) + 1
				self:TriggerEvent("OnProfileSave", playerId, data)
				return true
			else
				self:Log(ERROR_SAVE_FAIL .. tostring(result), "ERROR")  
				wait(2 ^ attempt)  
			end
		end
		return false
	end)()
end

function pDataService:LoadData(playerId, defaultData)
	local store = self:GetDataStore()
	local key = self:GenerateKey(playerId)
	local success, result

	for attempt = 1, self.MaxRetries do
		success, result = pcall(function()
			return store:GetAsync(key)
		end)

		if success then
			if result then
				result = self:DecompressData(result)
				if self:ValidateData(result) then
					self:TriggerEvent("OnProfileLoad", playerId, result)
					return result
				else
					self:Log("Data validation failed for loaded data for player: " .. tostring(playerId), "ERROR")
					return defaultData
				end
			else
				return defaultData
			end
		else
			self:Log(ERROR_LOAD_FAIL .. tostring(playerId) .. ": " .. tostring(result), "ERROR")
			wait(2 ^ attempt)
		end
	end

	return defaultData
end


function pDataService:TriggerEvent(eventType, ...)
	if self.EventHooks[eventType] then
		for _, callback in ipairs(self.EventHooks[eventType]) do
			callback(...)
		end
	end
end


function pDataService:RegisterEventHook(eventType, callback)
	if self.EventHooks[eventType] then
		table.insert(self.EventHooks[eventType], callback)
	else
		self:Log("Invalid event type: " .. tostring(eventType), "ERROR")
	end
end

function pDataService:ClearProfiles()
	for playerId in pairs(self.ActiveProfiles) do
		self:ReleaseProfile(playerId)
	end
end

function pDataService:Init()
	coroutine.wrap(function()
		self:AutoSaveProfiles()
	end)()
end

return pDataService