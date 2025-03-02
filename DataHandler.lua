local RS = game:GetService("ReplicatedStorage")
local PLAYERS = game:GetService("Players")
local SS = game:GetService("ServerStorage")
local DSS = game:GetService("DataStoreService")
local PLRDATA = DSS:GetDataStore("Player_Data")

local DATA_HANDLER = {

}

self = DATA_HANDLER

local SERVERDATA = setmetatable({}, {__index = DATA_HANDLER, __newindex = function(TAB, IND, VAL)

	return rawset(DATA_HANDLER, IND, VAL)

end})

-- Functions

function self:PLR_ADDED(PLR : Player)

	local LS = Instance.new("Folder", PLR)
	LS.Name = "leaderstats"

	local CASH = Instance.new("IntValue", LS)
	CASH.Name = "Cash"
	CASH.Value = 500

	local ARRESTS = Instance.new("IntValue", LS)
	ARRESTS.Name = "Arrests"
	ARRESTS.Value = 0

	-- other stuff

	local KEY = PLR.UserId

	local SUCC, RESULT = pcall(PLRDATA.GetAsync, PLRDATA, KEY)

	if SUCC then

		SERVERDATA[PLR] = RESULT or {}

		CASH.Value = RESULT.CASH or 0
		ARRESTS.Value = RESULT.ARRESTS or 0

		print("SUCCESSFULLY FETCHED DATA FOR: " .. PLR.UserId)

	else

		return PLR:Kick("FAILED TO FETCH DATA.\nIF ISSUE PERSIST, CONTACT DEVELOPERS.")

	end

end

function self:PLR_LEAVE(PLR : Player)

	local KEY = PLR.UserId

	local SUCC, RESULT = pcall(PLRDATA.SetAsync, PLRDATA, KEY, self[PLR], {KEY})

	if SUCC then

		print("SUCCESSFULLY SAVED DATA TO KEY: " .. KEY)

	else

		warn("FAILED TO SAVE DATA TO KEY: " .. KEY)

		print("SAVING TO BACKUP FOLDER...")

		local BACKUP_FOLDER = SS:FindFirstChild("BACKUPDATA")
		
		if not BACKUP_FOLDER then
			
			local NEW_FOLDER = Instance.new("Folder", SS)
			NEW_FOLDER.Name = "BACKUPDATA"
			
		end

		local PLR_FOLDER = Instance.new("Folder", BACKUP_FOLDER)
		PLR_FOLDER.Name = PLR.UserId

		if self[PLR] and self[PLR] ~= nil then

			for I, V in self[PLR] do

				local VALUE = Instance.new("IntValue", PLR_FOLDER)
				VALUE.Name = tostring(I)
				VALUE.Value = V

			end

		else

			return warn("FAILED TO SAVE BACKUP DATA.")

		end

	end

end

function self:REMOVE_DATA(PLR : Player)

	local KEY = PLR.UserId

	local L_S, LAST_DATA = pcall(PLRDATA.GetAsync, PLRDATA, KEY)
	local D_S, E = pcall(PLRDATA.RemoveAsync, PLRDATA, KEY)

	if L_S and D_S then

		print(string.format("DATA SUCCESSFULLY REMOVED FROM KEY %d.\nLAST DATA WAS %s.", KEY, tostring(unpack(LAST_DATA))))

	end

end

function self.HANDLE_BACKUPS()

	while task.wait(60) do

		local BACKUPS = SS:FindFirstChild("BACKUPDATA")

		if not BACKUPS then

			BACKUPS = Instance.new("Folder", SS)
			BACKUPS.Name = "BACKUPDATA"

		end

		if BACKUPS and #BACKUPS:GetChildren() > 0 then

			for _, PLR_FOLDER in ipairs(BACKUPS:GetChildren()) do

				local KEY = tonumber(PLR_FOLDER.Name)
				local DATA = {}

				if KEY then

					for _, VALUE in ipairs(PLR_FOLDER:GetChildren()) do

						DATA[VALUE.Name] = VALUE.Value

					end

					local SUCCESS, RESULT = pcall(PLRDATA.SetAsync, PLRDATA, KEY, DATA)

					if SUCCESS then

						print("SUCCESSFULLY RESTORED BACKUP DATA FOR KEY: " .. KEY)

						PLR_FOLDER:Destroy()

					else

						warn("FAILED TO RESTORE BACKUP DATA FOR KEY: " .. KEY)

					end

				else

					continue

				end

			end

		end

	end

end

function self:UPDATE_SERVER_DATA()

	for _, PLAYER in PLAYERS:GetPlayers() do

		local LS = PLAYER:FindFirstChild("leaderstats")

		if LS then

			for _, V in LS:GetChildren() do

				V.Changed:Connect(function(NEW_VALUE)

					rawset(self[PLAYER], V.Name, NEW_VALUE)

				end)

			end

		else

			warn("LEADERSTATS NOT FOUND.")

		end

	end

end

function self:SHUTDOWN()

	for _, PLR in PLAYERS:GetPlayers() do

		self:PLR_LEAVE(PLR)

	end

end

return DATA_HANDLER
