-- Services

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CP = game:GetService("ContentProvider")

-- Vars

local GPWS_Module = {}
local plr = Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local humroot = char:WaitForChild("HumanoidRootPart")
local Sound_dir = script.Parent.Parent:WaitForChild("GPWS")
local Plane = nil

local UI = script:WaitForChild("Debugging")
local Plane_Debug = UI.Main.Plane_Debug
local GPWS_Debug = UI.Main.GPWS_Debug
local Template = script:WaitForChild("Template")

local DebugStart = false

local lastPosition = humroot.Position
local lastTime = tick()
local lastVSUpdateTime = tick()
local lastAltitude = humroot.Position.Y
GPWS_Module.lastBankWarningTime = tick()
GPWS_Module.lastPullUpWarningTime = tick()
GPWS_Module.lastSinkRateWarningTime = tick()
GPWS_Module.lastTerrainWarningTime = tick()
GPWS_Module.lastTerrainCautionTime = tick()
GPWS_Module.lastTerrainPullUpTime = tick()

-- Constants

local BANK_ANGLE_WARNING_COOLDOWN = 5
local PULL_UP_WARNING_COOLDOWN = 3
local SINK_RATE_WARNING_COOLDOWN = 2
local TERRAIN_WARNING_COOLDOWN = 2
local TERRAIN_CAUTION_COOLDOWN = 2
local TERRAIN_PULL_UP_COOLDOWN = 2
local CAUTION_DISTANCE = 2500
local PULL_UP_DISTANCE = 1000

local cooldown = false

-- Functions

function GPWS_Module.calculateAltitude()
	
	local altitudeFeet = humroot.Position.Y * 3.281
	return math.floor(altitudeFeet / 10) * 10
	
end

function GPWS_Module.calculateSpeed()
	
	local currentPosition = humroot.Position
	local currentTime = tick()
	local distance = (currentPosition - lastPosition).Magnitude
	local timeDelta = currentTime - lastTime

	if timeDelta > 0 then
		
		local speedKnots = (distance / timeDelta) * 2.037
		lastPosition = currentPosition
		lastTime = currentTime
		return math.floor(speedKnots / 10) * 10
		
	end
	
	return 0
	
end

function GPWS_Module.calculateDegrees()
	
	local degrees = (humroot.Orientation.Y + 360) % 360
	return math.floor(degrees / 10) * 10
	
end

function GPWS_Module.calculateBankAngle()
	
	local bankAngle = humroot.Orientation.Z
	return math.floor(math.abs(bankAngle) / 5) * 5 * (bankAngle < 0 and -1 or 1)
	
end

function GPWS_Module.getVerticalSpeed()

	local currentALT = humroot.Position.Y * 3.281
	local currentTime = tick()
	local timeDelta = currentTime - lastVSUpdateTime

	if timeDelta > 0 then

		local verticalSpeedFPM = ((currentALT - lastAltitude) / timeDelta) * 60
		lastAltitude = currentALT
		lastVSUpdateTime = currentTime
		return math.floor(verticalSpeedFPM)

	end

	return 0

end

function GPWS_Module:getPitchAngle()
	
	local PitchAngle = humroot.Orientation.X
	return math.floor(math.abs(PitchAngle) / 5) * 5 * (PitchAngle < 0 and -1 or 1)
	
end



function GPWS_Module:play_GPWS()

	RunService.Heartbeat:Connect(function()

		local ALT = self.calculateAltitude()
		local DES = self.getVerticalSpeed()
		local BANK = self.calculateBankAngle()
		local SPEED = self.calculateSpeed()
		local PITCH = self:getPitchAngle()

		local rayOrigin = humroot.Position
		local lookVector = humroot.CFrame.LookVector
		local rayDirection = lookVector * CAUTION_DISTANCE
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = {char, Plane}
		local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

		--print(string.format("Debug: {ALT: %s, SPEED: %s, FPM: %s, BANK: %s, PITCH: %s}", tostring(ALT), tostring(SPEED), tostring(DES), tostring(BANK), tostring(PITCH)))

		if raycastResult and raycastResult.Instance == workspace.Terrain then
			
			local terrainDistance = (raycastResult.Position - rayOrigin).Magnitude

			if terrainDistance <= PULL_UP_DISTANCE then
				
				if tick() - self.lastTerrainPullUpTime > TERRAIN_PULL_UP_COOLDOWN then
					
					if cooldown then return end
					
					cooldown = true
					
					local terrain = Sound_dir:FindFirstChild("Terrain Terrain")
					local pullUpSound = Sound_dir:FindFirstChild("PullUp_Normal")

					if terrain and pullUpSound then
						
						terrain:Play()

						terrain.Ended:Wait()

						pullUpSound:Play()

						self.lastTerrainPullUpTime = tick()
						
					else
						
						warn("Terrain or PullUp sound not found!")
						
					end
					task.wait(1)
					cooldown = false
					
				end
				
			elseif terrainDistance <= CAUTION_DISTANCE then
				
				if tick() - self.lastTerrainCautionTime > TERRAIN_CAUTION_COOLDOWN then
					
					print("Caution Cooldown Expired")
					local cautionSound = Sound_dir:FindFirstChild("Caution Terrain")

					if cautionSound then
						cautionSound:Play()
						print("Playing Caution Terrain sound")
						self.lastTerrainCautionTime = tick()
					else
						warn("Caution Terrain sound not found!")
					end
				else
					print("Caution Cooldown Active")
				end
			end
		end
		
		if DES <= -1000 and tick() - self.lastSinkRateWarningTime > SINK_RATE_WARNING_COOLDOWN then

			local sinkrate = Sound_dir:FindFirstChild("Sinkrate")
			local pullup = Sound_dir:FindFirstChild("PullUp_Whoop")

			if ALT >= 3000 then
				
				if sinkrate then
					
					sinkrate:Play()
					self.lastSinkRateWarningTime = tick()
					
				end
				
			else

				if pullup then

					pullup:Play()						
					self.lastSinkRateWarningTime = tick()

				end				
				
			end
			
		end

		-- Bank Angle Warning
		if math.abs(BANK) > 40 and tick() - self.lastBankWarningTime > BANK_ANGLE_WARNING_COOLDOWN then
			local bankAngleWarning = Sound_dir:FindFirstChild("Bankangle")
			if bankAngleWarning then
				bankAngleWarning:Play()

				print("Bankangle called")

				self.lastBankWarningTime = tick()
			end
		end

		-- Terrain Warning
		if ALT < 1000 and DES > 1000 and tick() - self.lastTerrainWarningTime > TERRAIN_WARNING_COOLDOWN then

			local terrain = Sound_dir:FindFirstChild("Terrain Terrain")

			if terrain then

				terrain:Play()

				print("Terrain called.")

				self.lastTerrainWarningTime = tick()

			end

		end

		local altitudeCallouts = {2500, 1000, 500, 100, 50, 40, 30, 20, 10}

		for _, callout in ipairs(altitudeCallouts) do

			if ALT == callout and DES < 0 then

				local calloutSound = Sound_dir:FindFirstChild(tostring(callout))

				if calloutSound then

					calloutSound:Play()
					break

				end

			end

		end

	end)

end


function GPWS_Module.preLoad()
	
	for _, sound in pairs(Sound_dir:GetChildren()) do
		
		if sound:IsA("Sound") then
			
			CP:PreloadAsync({sound})
			print("Loaded:", sound.Name)
			
		end
		
	end
	
end

function GPWS_Module.fetch_Plane(model : Model)
	
	Plane = model
	
end

function GPWS_Module:Debug()
	
	if not DebugStart then
		
		print("Setting Parent..")
		
		UI.Parent = plr:WaitForChild("PlayerGui")
		
		print("Parent set..")
		
		DebugStart = true
		
	end
	
	Plane_Debug.ALT.Text = "ALT: " .. self.calculateAltitude() .. "ft"
	Plane_Debug.FPM.Text = "FPM: " .. self.getVerticalSpeed() .. "fpm"
	Plane_Debug.BANK.Text = "BANK: " .. self.calculateBankAngle() .. "°"
	
	for i, v in GPWS_Module do
		
		if typeof(v) == "function" then continue end
		
		local clone = Template:Clone()
		
		clone.Text = tostring(i) .. " = " .. tostring(v)
		
	end
	
end

return GPWS_Module
