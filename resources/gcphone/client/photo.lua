-- Author: Xinerki (https://forum.fivem.net/t/release-cellphone-camera/43599)

local phone = false
local phoneId = 0

RegisterNetEvent('camera:open')
AddEventHandler('camera:open', function()
	CreateMobilePhone(1)
	CellCamActivate(true, true)
	SetPhone(true)
	PhonePlayOut()
end)

frontCam = false

function CellFrontCamActivate(activate)
	return Citizen.InvokeNative(0x2491A93618B7D838, activate)
end

function SetPhone(value)
	phone = value
	if phone then
		Citizen.CreateThread(function()
			while phone do
				Citizen.Wait(0)
				if (IsControlJustPressed(1, 177) or IsControlJustPressed(0, 177) or IsControlJustPressed(2, 177) or IsControlJustPressed(3, 177)) then -- CLOSE PHONE
					DestroyMobilePhone()
					SetPhone(false)
					CellCamActivate(false, false)
					if firstTime == true then
						firstTime = false
						Citizen.Wait(2500)
						displayDoneMission = true
					end
				end
	
				if IsControlJustPressed(1, 27) then -- SELFIE MODE
					frontCam = not frontCam
					CellFrontCamActivate(frontCam)
				end
	
				HideHudComponentThisFrame(7)
				HideHudComponentThisFrame(8)
				HideHudComponentThisFrame(9)
				HideHudComponentThisFrame(6)
				HideHudComponentThisFrame(19)
				HideHudAndRadarThisFrame()
			end
		end)
	end
end

Citizen.CreateThread(function()
	DestroyMobilePhone()
end)
-- Citizen.CreateThread(function()
-- 	DestroyMobilePhone()
-- 	while true do
-- 		Citizen.Wait(0)

-- 		if phone == true then
-- 			if (IsControlJustPressed(1, 177) or IsControlJustPressed(0, 177) or IsControlJustPressed(2, 177) or IsControlJustPressed(3, 177)) then -- CLOSE PHONE
-- 				DestroyMobilePhone()
-- 				SetPhone(false)
-- 				CellCamActivate(false, false)
-- 				if firstTime == true then
-- 					firstTime = false
-- 					Citizen.Wait(2500)
-- 					displayDoneMission = true
-- 				end
-- 			end

-- 			if IsControlJustPressed(1, 27) then -- SELFIE MODE
-- 				frontCam = not frontCam
-- 				CellFrontCamActivate(frontCam)
-- 			end

-- 			if phone == true then
-- 				HideHudComponentThisFrame(7)
-- 				HideHudComponentThisFrame(8)
-- 				HideHudComponentThisFrame(9)
-- 				HideHudComponentThisFrame(6)
-- 				HideHudComponentThisFrame(19)
-- 				HideHudAndRadarThisFrame()
-- 			end
-- 		end

-- 		-- ren = GetMobilePhoneRenderId()
-- 		-- SetTextRenderId(ren)

-- 		-- -- Everything rendered inside here will appear on your phone.

-- 		-- SetTextRenderId(1) -- NOTE: 1 is default
-- 	end
-- end)
