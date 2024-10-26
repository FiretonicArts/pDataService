local DataStoreService = game:GetService("DataStoreService")

local pDataService = {}
pDataService.ActiveProfiles = {}  
pDataService.DataStoreKey = "CHANGE_ME"

if pDataService.DataStoreKey == "CHANGE_ME" then
	warn("pDataService WARNING! - Your data store key is still as from the start we recommend you to CHANGE it! As soon as possible..")
end

function pDataService:GetDataStore(name)
	return DataStoreService:GetDataStore(name)
end

function pDataService:SaveData(store, key, data)
	local success, result = pcall(function()
		store:SetAsync(self.DataStoreKey .. key, data)
	end)
	return success, result
end

function pDataService:LoadData(store, key)
	local success, result
	for i = 1, 3 do  
		success, result = pcall(function()
			return store:GetAsync(self.DataStoreKey .. key)
		end)
		if success then
			return result
		else
			wait(2)
		end
	end
	return nil  
end

function pDataService:RetrySave(store, key, data, attempts)
	local success, result
	for i = 1, attempts do
		success, result = self:SaveData(store, key, data)
		if success then break end
		wait(2)
	end
	return success, result
end

function pDataService:LoadProfile(playerId, defaultData)
	if self.ActiveProfiles[playerId] then
		return nil
	end

	local profileStore = self:GetDataStore("PlayerProfiles")
	local data = self:LoadData(profileStore, tostring(playerId)) or defaultData

	self.ActiveProfiles[playerId] = {data = data, locked = true}
	return data
end

function pDataService:SaveProfile(playerId)
	local profile = self.ActiveProfiles[playerId]
	if profile then
		self:SaveData(self:GetDataStore("PlayerProfiles"), tostring(playerId), profile.data)
		profile.locked = false
	end
end

function pDataService:ReleaseProfile(playerId)
	if self.ActiveProfiles[playerId] then
		self.ActiveProfiles[playerId] = nil
	end
end

function pDataService:SaveGlobalData(key, data)
	local store = self:GetDataStore("GlobalData")
	self:RetrySave(store, self.DataStoreKey .. key, data, 3)
end

function pDataService:LoadGlobalData(key)
	local store = self:GetDataStore("GlobalData")
	return self:LoadData(store, self.DataStoreKey .. key)
end

return pDataService
