local DataStoreService = game:GetService("DataStoreService")

local pDataService = {}
pDataService.ActiveProfiles = {}  

function pDataService:GetDataStore(name)
	return DataStoreService:GetDataStore(name)
end

function pDataService:SaveData(store, key, data)
	local success, result = pcall(function()
		store:SetAsync(key, data)
	end)
	return success, result
end

function pDataService:LoadData(store, key)
	local success, result = pcall(function()
		return store:GetAsync(key)
	end)
	return success and result or nil
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
	local data = self:LoadData(profileStore, playerId) or defaultData


	self.ActiveProfiles[playerId] = {data = data, locked = true}
	return data
end

function pDataService:SaveProfile(playerId)
	local profile = self.ActiveProfiles[playerId]
	if profile then
		self:SaveData(self:GetDataStore("PlayerProfiles"), playerId, profile.data)
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
	self:RetrySave(store, key, data, 3)
end

function pDataService:LoadGlobalData(key)
	local store = self:GetDataStore("GlobalData")
	return self:LoadData(store, key)
end

return pDataService
