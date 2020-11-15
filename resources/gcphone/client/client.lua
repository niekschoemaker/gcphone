--====================================================================================
-- #Author: Jonathan D @ Gannon
--====================================================================================

-- Configuration
local KeyToucheCloseEvent = {
	{ code = 172, event = 'ArrowUp' },
	{ code = 173, event = 'ArrowDown' },
	{ code = 174, event = 'ArrowLeft' },
	{ code = 175, event = 'ArrowRight' },
	{ code = 176, event = 'Enter' },
	{ code = 177, event = 'Backspace' },
}
local KeyOpenClose = 244 -- M
local KeyTakeCall = 38 -- E
local menuIsOpen = false
local contacts = {}
local messages = {}
local myPhoneNumber = ''
local isDead = false
local USE_RTC = false
local useMouse = false
local ignoreFocus = false
local takePhoto = false
local hasFocus = false

local PhoneInCall = {}
local currentPlaySound = false
local soundDistanceMax = 8.0
local voiceChannel = 0


--====================================================================================
--  Check si le joueurs poséde un téléphone
--  Callback true or false
--====================================================================================
-- function hasPhone (cb)
--   cb(true)
-- end
--====================================================================================
--  Que faire si le joueurs veut ouvrir sont téléphone n'est qu'il en a pas ?
--====================================================================================
function ShowNoPhoneWarning ()
end

--[[
Ouverture du téphone lié a un item
Un solution ESC basé sur la solution donnée par HalCroves
https://forum.fivem.net/t/tutorial-for-gcphone-with-call-and-job-message-other/177904
--]]

ESX = nil
Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(0)
	end
	while ESX.GetPlayerData().job == nil do
		Citizen.Wait(100)
	end
	ESX.PlayerData = ESX.GetPlayerData()
end)

function hasPhone (cb)
	local playerData = ESX.GetPlayerData()
	if (ESX == nil) then return cb(0) end
	while playerData == nil or playerData.inventory == nil do
		playerData = ESX.GetPlayerData()
		Citizen.Wait(100)
	end
	for i=1, #playerData.inventory, 1 do
		if playerData.inventory[i].name == 'phone' then
			cb(playerData.inventory[i].count > 0)
		end
	end
end
function ShowNoPhoneWarning ()
	if (ESX == nil) then return end
	ESX.ShowNotification("Je hebt geen ~r~telefoon~s~")
end

--====================================================================================
--
--====================================================================================

RegisterCommand("toggle_phone", function(source, args, raw)
	if takePhoto or not IsControlEnabled(1, KeyOpenClose) or IsDisabledControlPressed(1, 36) or IsDisabledControlPressed(1, 61) then
		return
	end

	hasPhone(function (hasPhone)
		if hasPhone == true then
			TooglePhone()
		else
			ShowNoPhoneWarning()
		end
	end)
end)

RegisterKeyMapping("toggle_phone", "Open/Sluit telefoon", "keyboard", "M")

function SetMenuIsOpen(value)
	menuIsOpen = value

	if menuIsOpen then
		Citizen.CreateThread(function()
			while menuIsOpen do
				Citizen.Wait(0)
				for _, value in ipairs(KeyToucheCloseEvent) do
					if IsControlJustPressed(1, value.code) then
						SendNUIMessage({keyUp = value.event})
					end
				end
				if useMouse == true and hasFocus == ignoreFocus then
					local nuiFocus = not hasFocus
					SetNuiFocus(nuiFocus, nuiFocus)
					hasFocus = nuiFocus
				elseif useMouse == false and hasFocus == true then
					SetNuiFocus(false, false)
					hasFocus = false
				end
			end
		end)
	elseif hasFocus == true then
		SetNuiFocus(false, false)
		hasFocus = false
	end
end

--====================================================================================
--  Active ou Deactive une application (appName => config.json)
--====================================================================================
RegisterNetEvent('gcPhone:setEnableApp')
AddEventHandler('gcPhone:setEnableApp', function(appName, enable)
	SendNUIMessage({event = 'setEnableApp', appName = appName, enable = enable })
end)

--====================================================================================
--  Gestion des appels fixe
--====================================================================================
function startFixeCall (fixeNumber)
	local number = ''
	DisplayOnscreenKeyboard(1, "FMMC_MPM_NA", "", "", "", "", "", 10)
	TriggerEvent('disableAllControls', GetCurrentResourceName())
	while (UpdateOnscreenKeyboard() == 0) do
		DisableAllControlActions(0);
		Wait(0);
	end
	TriggerEvent('enableAllControls', GetCurrentResourceName())
	if (GetOnscreenKeyboardResult()) then
		number =  GetOnscreenKeyboardResult()
	end
	if number ~= '' then
		TriggerEvent('gcphone:autoCall', number, {
			useNumber = fixeNumber
		})
		PhonePlayCall(true)
	end
end

function TakeAppel (infoCall)
	TriggerEvent('gcphone:autoAcceptCall', infoCall)
end

RegisterNetEvent("gcPhone:notifyFixePhoneChange")
AddEventHandler("gcPhone:notifyFixePhoneChange", function(_PhoneInCall)
	PhoneInCall = _PhoneInCall
end)

--[[
Show information when approaching a fixed telephone
--]]
function showFixePhoneHelper (coords)
	for number, data in pairs(FixePhone) do
		local dist = GetDistanceBetweenCoords(
		data.coords.x, data.coords.y, data.coords.z,
		coords.x, coords.y, coords.z, 1)
		if dist <= 2.0 then
			SetTextComponentFormat("STRING")
			AddTextComponentString("~g~" .. data.name .. ' ~o~' .. number .. '~n~Druk op ~INPUT_PICKUP~~w~ om te bellen')
			DisplayHelpTextFromStringLabel(0, 0, 0, -1)
			if IsControlJustPressed(1, KeyTakeCall) then
				startFixeCall(number)
			end
			break
		end
	end
end

function PlaySoundJS (sound, volume)
	SendNUIMessage({ event = 'playSound', sound = sound, volume = volume })
end

function SetSoundVolumeJS (sound, volume)
	SendNUIMessage({ event = 'setSoundVolume', sound = sound, volume = volume})
end

function StopSoundJS (sound)
	SendNUIMessage({ event = 'stopSound', sound = sound})
end

RegisterNetEvent("gcPhone:forceOpenPhone")
AddEventHandler("gcPhone:forceOpenPhone", function(_myPhoneNumber)
	if menuIsOpen == false then
		TooglePhone()
	end
end)

--====================================================================================
--  Events
--====================================================================================
RegisterNetEvent("gcPhone:myPhoneNumber")
AddEventHandler("gcPhone:myPhoneNumber", function(_myPhoneNumber)
	myPhoneNumber = _myPhoneNumber
	SendNUIMessage({event = 'updateMyPhoneNumber', myPhoneNumber = myPhoneNumber})
end)

RegisterNetEvent("gcPhone:contactList")
AddEventHandler("gcPhone:contactList", function(_contacts)
	SendNUIMessage({event = 'updateContacts', contacts = _contacts})
	contacts = _contacts
end)

RegisterNetEvent("gcPhone:allMessage")
AddEventHandler("gcPhone:allMessage", function(allmessages)
	SendNUIMessage({event = 'updateMessages', messages = allmessages})
	messages = allmessages
end)

RegisterNetEvent("gcPhone:getBourse")
AddEventHandler("gcPhone:getBourse", function(bourse)
	SendNUIMessage({event = 'updateBourse', bourse = bourse})
end)

local lastDistress = nil
local LastMessageCoords = nil
RegisterNetEvent("gcPhone:receiveMessage")
AddEventHandler("gcPhone:receiveMessage", function(message)
	-- SendNUIMessage({event = 'updateMessages', messages = messages})
	SendNUIMessage({event = 'newMessage', message = message})
	table.insert(messages, message)
	print(json.encode(message))
	if message.owner == 0 then
		local text = '~o~Nieuw bericht'
		if message.distress then
			text = '~r~NOODSIGNAAL:'
		end
		if ShowNumberNotification == true then
			text = '~o~Nieuw bericht van ~y~' .. message.transmitter
			if message.distress then
				text = '~r~NOODSIGNAAL VAN ~y~' .. (message.name or message.transmitter)
			end
			for _,contact in pairs(contacts) do
				if contact.number == message.transmitter then
					text = '~o~Nieuw bericht van ~g~'.. contact.display
					break
				end
			end
		end
		if message.distress then
			RemoveDistress()
			AddDistress(message)
		end
		SetNotificationTextEntry("STRING")
		AddTextComponentString(text)
		DrawNotification(false, false)
		if message.coords then
			LastMessageCoords = message.coords
		end
		if message.distress then
			PlayDistressNotificationSound()
		else
			PlayNotificationSound()
		end
	end
end)

function PlayDistressNotificationSound()
	PlaySoundFrontend(-1, "TIMER_STOP", "HUD_MINI_GAME_SOUNDSET")
	Citizen.Wait(200)
	PlaySoundFrontend(-1, "TIMER_STOP", "HUD_MINI_GAME_SOUNDSET")
	Citizen.Wait(800)
	PlaySoundFrontend(-1, "TIMER_STOP", "HUD_MINI_GAME_SOUNDSET")
	Citizen.Wait(200)
	PlaySoundFrontend(-1, "TIMER_STOP", "HUD_MINI_GAME_SOUNDSET")
	Citizen.Wait(800)
	PlaySoundFrontend(-1, "TIMER_STOP", "HUD_MINI_GAME_SOUNDSET")
	Citizen.Wait(200)
	PlaySoundFrontend(-1, "TIMER_STOP", "HUD_MINI_GAME_SOUNDSET")
	Citizen.Wait(800)
end

function PlayNotificationSound()
	PlaySound(-1, "Menu_Accept", "Phone_SoundSet_Default", 0, 0, 1)
	Citizen.Wait(300)
	PlaySound(-1, "Menu_Accept", "Phone_SoundSet_Default", 0, 0, 1)
	Citizen.Wait(300)
	PlaySound(-1, "Menu_Accept", "Phone_SoundSet_Default", 0, 0, 1)
end

function RemoveDistress()
	if lastDistress then
		RemoveBlip(lastDistress.blip)
		lastDistress = nil
	end
end

RegisterCommand("removedistress", function()
	RemoveDistress()
end)

function AddDistress(message)
	if message.coords then
		local thisDistress = {}
		lastDistress = thisDistress
		lastDistress.blip = AddBlipForCoord(message.coords.x, message.coords.y, message.coords.z)
		lastDistress.coords = vector3(message.coords.x, message.coords.y, message.coords.z)

		SetBlipSprite(lastDistress.blip, 1)
		SetBlipColour(lastDistress.blip, 1)
		SetBlipRoute(lastDistress.blip, true)
		SetBlipRouteColour(lastDistress.blip, 1)
		Citizen.CreateThread(function()
			local startedBlip = GetGameTimer()
			while lastDistress == thisDistress and thisDistress ~= nil do
				Citizen.Wait(2500)
				if #(thisDistress.coords - GetEntityCoords(PlayerPedId())) < 25.0 or GetGameTimer() - startedBlip > 60000 * 5 then
					RemoveDistress()
					break
				end
			end
		end)
	end
end

RegisterCommand("setgpslastmessage", function()
	if LastMessageCoords then
		SetNewWaypoint(LastMessageCoords.x, LastMessageCoords.y)
	end
end)

RegisterKeyMapping("setgpslastmessage", "Zet GPS locatie naar laatste bericht", "keyboard", "")

--====================================================================================
--  Function client | Contacts
--====================================================================================
function addContact(display, num)
	TriggerServerEvent('gcPhone:addContact', display, num)
end

function deleteContact(num)
	TriggerServerEvent('gcPhone:deleteContact', num)
end
--====================================================================================
--  Function client | Messages
--====================================================================================
function sendMessage(num, message)
	TriggerServerEvent('gcPhone:sendMessage', num, message)
end

function deleteByReference(reference)
	if not reference then
		return
	end
	for k, v in ipairs(messages) do
		if v.reference == reference then
			table.remove(messages, k)
			SendNUIMessage({event = 'updateMessages', messages = messages})
			return
		end
	end
end

function deleteMessage(msgId)
	if msgId ~= nil then
		TriggerServerEvent('gcPhone:deleteMessage', msgId)
	end
	for k, v in ipairs(messages) do
		if v.id == msgId then
			table.remove(messages, k)
			SendNUIMessage({event = 'updateMessages', messages = messages})
			return
		end
	end
end

function deleteMessageContact(num)
	TriggerServerEvent('gcPhone:deleteMessageNumber', num)
end

function deleteAllMessage()
	TriggerServerEvent('gcPhone:deleteAllMessage')
end

local governmentNumbers = {
	police = true,
	dsi = true,
	taxi = true,
	ambulance = true,
	mechanic = true,
	justitie = true,
}
function setReadMessageNumber(num)
	local hasReference, found, changed = 0, 0, false
	for k, v in ipairs(messages) do
		if v.reference ~= nil then
			hasReference = hasReference + 1
		end
		found = found + 1
		if v.transmitter == num and v.isRead ~= 1 then
			changed = true
			v.isRead = 1
		end
	end
	if not governmentNumbers[num] and changed then
		TriggerServerEvent('gcPhone:setReadMessageNumber', num)
	end
end

function requestAllMessages()
	TriggerServerEvent('gcPhone:requestAllMessages')
end

function requestAllContact()
	TriggerServerEvent('gcPhone:requestAllContact')
end


--====================================================================================
--  Function client | Appels
--====================================================================================
local aminCall = false
local inCall = false

local call = false
RegisterNetEvent("gcPhone:waitingCall")
AddEventHandler("gcPhone:waitingCall", function(infoCall, initiator)
	if not initiator then
		for i=1, #contacts do
			if infoCall.transmitter_num == contacts[i].number and contacts[i].blocked == 1 then
				return
			end
		end
	end
	Citizen.CreateThread(function()
		call = true
		while call do
			Citizen.Wait(0)
			DisableControlAction(0, 24, true)
		end
	end)
	SendNUIMessage({event = 'waitingCall', infoCall = infoCall, initiator = initiator})
	if initiator == true then
		PhonePlayCall()
		if menuIsOpen == false then
			TooglePhone()
		end
	end
end)

RegisterNetEvent("gcPhone:acceptCall")
AddEventHandler("gcPhone:acceptCall", function(infoCall, initiator)
	call = false
	if inCall == false and USE_RTC == false then
		inCall = true
		voiceChannel = infoCall.id
		exports["mumble-voip"]:SetCallChannel(tonumber(infoCall.id))
	end
	if menuIsOpen == false then
		TooglePhone()
	end
	PhonePlayCall()
	SendNUIMessage({event = 'acceptCall', infoCall = infoCall, initiator = initiator})
end)

RegisterNetEvent("gcPhone:rejectCall")
AddEventHandler("gcPhone:rejectCall", function(infoCall)
	if inCall == true then
		inCall = false
		exports["mumble-voip"]:SetCallChannel(0)
		exports['mumble-voip']:ResetVoiceTarget()
	end
	PhonePlayText()
	SendNUIMessage({event = 'rejectCall', infoCall = infoCall})
end)


RegisterNetEvent("gcPhone:historiqueCall")
AddEventHandler("gcPhone:historiqueCall", function(historique)
	SendNUIMessage({event = 'historiqueCall', historique = historique})
end)


function startCall (phone_number, rtcOffer, extraData)
	call = false
	TriggerServerEvent('gcPhone:startCall', phone_number, rtcOffer, extraData)
end

function acceptCall(infoCall, rtcAnswer)
	call = false
	TriggerServerEvent('gcPhone:acceptCall', infoCall, rtcAnswer)
end

function rejectCall(infoCall)
	call = false
	TriggerServerEvent('gcPhone:rejectCall', infoCall)
end

function ignoreCall(infoCall)
	call = false
	TriggerServerEvent('gcPhone:ignoreCall', infoCall)
end

function requestHistoriqueCall()
	TriggerServerEvent('gcPhone:getHistoriqueCall')
end

function appelsDeleteHistorique (num)
	TriggerServerEvent('gcPhone:appelsDeleteHistorique', num)
end

function appelsDeleteAllHistorique ()
	TriggerServerEvent('gcPhone:appelsDeleteAllHistorique')
end


--====================================================================================
--  Event NUI - Appels
--====================================================================================

RegisterNUICallback('startCall', function (data, cb)
	startCall(data.numero, data.rtcOffer or false, data.extraData or false)
	cb()
end)

RegisterNUICallback('acceptCall', function (data, cb)
	while IsDisabledControlPressed(0, 24) do
		Citizen.Wait(100)
	end
	acceptCall(data.infoCall or false, data.rtcAnswer or false)
	cb()
end)
RegisterNUICallback('rejectCall', function (data, cb)
	rejectCall(data.infoCall)
	cb()
end)

RegisterNUICallback('ignoreCall', function (data, cb)
	ignoreCall(data.infoCall)
	cb()
end)

RegisterNUICallback('setService', function (data, cb)
	TriggerServerEvent("gcphone:setTaken", data.reference)
	cb()
end)

function setTaken(source, reference)
	for k, v in ipairs(messages) do
		if v.reference == reference then
			messages[k].isTaken = 1
			messages[k].source = source
			SendNUIMessage({event = 'updateMessages', messages = messages})
			return
		end
	end
end

RegisterNetEvent('gcphone:setTaken')
AddEventHandler('gcphone:setTaken', function(source, reference)
	setTaken(source, reference)
end)

RegisterNUICallback('notififyUseRTC', function (use, cb)
	USE_RTC = use
	if USE_RTC == true and inCall == true then
		inCall = false
		exports["mumble-voip"]:SetCallChannel(0)
	end
	cb()
end)


RegisterNUICallback('onCandidates', function (data, cb)
	TriggerServerEvent('gcPhone:candidates', data.id, data.candidates)
	cb()
end)

RegisterNetEvent("gcPhone:candidates")
AddEventHandler("gcPhone:candidates", function(candidates)
	SendNUIMessage({event = 'candidatesAvailable', candidates = candidates})
end)



RegisterNetEvent('gcphone:autoCall')
AddEventHandler('gcphone:autoCall', function(number, extraData)
	if number ~= nil then
		SendNUIMessage({ event = "autoStartCall", number = number, extraData = extraData})
	end
end)

RegisterNetEvent('gcphone:autoCallNumber')
AddEventHandler('gcphone:autoCallNumber', function(data)
	TriggerEvent('gcphone:autoCall', data.number)
end)

RegisterNetEvent('gcphone:autoAcceptCall')
AddEventHandler('gcphone:autoAcceptCall', function(infoCall)
	SendNUIMessage({ event = "autoAcceptCall", infoCall = infoCall})
end)

--====================================================================================
--  Gestion des evenements NUI
--====================================================================================
RegisterNUICallback('log', function(data, cb)
	cb()
end)
RegisterNUICallback('focus', function(data, cb)
	cb()
end)
RegisterNUICallback('blur', function(data, cb)
	cb()
end)
RegisterNUICallback('reponseText', function(data, cb)
	local limit = data.limit or 255
	local text = data.text or ''

	DisplayOnscreenKeyboard(1, "FMMC_MPM_NA", "", text, "", "", "", limit)
	TriggerEvent('disableAllControls', GetCurrentResourceName())
	while (UpdateOnscreenKeyboard() == 0) do
		DisableAllControlActions(0);
		DisableAllControlActions(2);
		Wait(0);
	end
	TriggerEvent('enableAllControls', GetCurrentResourceName())
	if (GetOnscreenKeyboardResult()) then
		text = GetOnscreenKeyboardResult()
	end
	cb(json.encode({text = text}))
end)
--====================================================================================
--  Event - Messages
--====================================================================================
RegisterNUICallback('getMessages', function(data, cb)
	cb(json.encode(messages))
end)

local lastMessage = 0
RegisterNUICallback('sendMessage', function(data, cb)
	if GetGameTimer() - lastMessage < 3500 then
		exports['esx_rpchat']:printToChat("Telefoon", "Je verstuurt te veel berichten, probeer het over enkele seconden opnieuw!", {r = 255})
		return
	end
	if data.message == '%pos%' then
		local myPos = GetEntityCoords(PlayerPedId())
		data.message = 'GPS: ' .. myPos.x .. ', ' .. myPos.y
	end

	lastMessage = GetGameTimer()
	TriggerServerEvent('gcPhone:sendMessage', data.phoneNumber, data.message)
end)
RegisterNUICallback('deleteMessage', function(data, cb)
	if data.reference then
		deleteByReference(data.reference)
	else
		deleteMessage(data.id)
	end
	cb()
end)
RegisterNUICallback('deleteMessageNumber', function (data, cb)
	deleteMessageContact(data.number)
	cb()
end)
RegisterNUICallback('deleteAllMessage', function (data, cb)
	deleteAllMessage()
	cb()
end)
RegisterNUICallback('setReadMessageNumber', function (data, cb)
	setReadMessageNumber(data.number)
	cb()
end)
--====================================================================================
--  Event - Contacts
--====================================================================================
RegisterNUICallback('addContact', function(data, cb)
	TriggerServerEvent('gcPhone:addContact', data.display, data.phoneNumber)
	cb()
end)
RegisterNUICallback('updateContact', function(data, cb)
	TriggerServerEvent('gcPhone:updateContact', data.id, data.display, data.phoneNumber)
	cb()
end)
RegisterNUICallback('deleteContact', function(data, cb)
	TriggerServerEvent('gcPhone:deleteContact', data.id)
	cb()
end)
RegisterNUICallback('blockContact', function(data, cb)
	local blocked = true
	for i=1, #contacts do
		if contacts[i].id == data.id then
			if contacts[i].blocked == 1 then
				blocked = false
			end
		end
	end
	TriggerServerEvent('gcPhone:blockContact', data.id, blocked)
	cb()
end)
RegisterNUICallback('getContacts', function(data, cb)
	cb(json.encode(contacts))
end)
RegisterNUICallback('setGPS', function(data, cb)
	SetNewWaypoint(tonumber(data.x), tonumber(data.y))
	cb()
end)

-- Add security for event (leuit#0100)
RegisterNUICallback('callEvent', function(data, cb)
	local eventName = data.eventName or ''
	if string.match(eventName, 'gcphone') then
		if data.data ~= nil then
			TriggerEvent(data.eventName, data.data)
		else
			TriggerEvent(data.eventName)
		end
	end
	cb()
end)
RegisterNUICallback('useMouse', function(um, cb)
	useMouse = um
end)
RegisterNUICallback('deleteALL', function(data, cb)
	TriggerServerEvent('gcPhone:deleteALL')
	cb()
end)



function TooglePhone()
	SetMenuIsOpen(not menuIsOpen)
	SetNuiFocus(true, true)
	Citizen.Wait(0)
	SetNuiFocus(false, false)
	SendNUIMessage({show = menuIsOpen})
	if menuIsOpen == true then
		PhonePlayIn()
	else
		PhonePlayOut()
	end
end

RegisterNUICallback('faketakePhoto', function(data, cb)
	SetMenuIsOpen(false)
	SendNUIMessage({show = false})
	cb()
	TriggerEvent('camera:open')
end)

RegisterNUICallback('closePhone', function(data, cb)
	SetMenuIsOpen(false)
	SendNUIMessage({show = false})
	PhonePlayOut()
	cb()
end)




----------------------------------
---------- GESTION APPEL ---------
----------------------------------
RegisterNUICallback('appelsDeleteHistorique', function (data, cb)
	appelsDeleteHistorique(data.numero)
	cb()
end)
RegisterNUICallback('appelsDeleteAllHistorique', function (data, cb)
	appelsDeleteAllHistorique(data.infoCall)
	cb()
end)


----------------------------------
---------- GESTION VIA WEBRTC ----
----------------------------------
AddEventHandler('onClientResourceStart', function(res)
	DoScreenFadeIn(300)
	if res == "gcphone" then
		TriggerServerEvent('gcPhone:allUpdate')
	end
end)


RegisterNUICallback('setIgnoreFocus', function (data, cb)
	ignoreFocus = data.ignoreFocus
	cb()
end)


RegisterNUICallback('takePhoto', function(data, cb)
	CreateMobilePhone(1)
	CellCamActivate(true, true)
	takePhoto = true
	Citizen.Wait(0)
	if hasFocus == true then
		SetNuiFocus(false, false)
		hasFocus = false
	end
	while takePhoto do
		Citizen.Wait(0)

		if IsControlJustPressed(1, 27) then -- Toogle Mode
			frontCam = not frontCam
			CellFrontCamActivate(frontCam)
		elseif IsControlJustPressed(1, 177) then -- CANCEL
			DestroyMobilePhone()
			CellCamActivate(false, false)
			cb(json.encode({ url = nil }))
			takePhoto = false
			break
		elseif IsControlJustPressed(1, 176) then -- TAKE.. PIC
			Citizen.CreateThread(function()
				exports['screenshot-basic']:requestScreenshotUpload(data.url, data.field, function(data)
					done = true
					cb(json.encode({ url = data }))
				end)
			end)
			local done = false
			local startTime = GetGameTimer()
			while not done and GetGameTimer() - startTime < 5000 do
				Citizen.Wait(0)
			end
			DestroyMobilePhone()
			CellCamActivate(false, false)
			takePhoto = false
		end
		HideHudComponentThisFrame(7)
		HideHudComponentThisFrame(8)
		HideHudComponentThisFrame(9)
		HideHudComponentThisFrame(6)
		HideHudComponentThisFrame(19)
		HideHudAndRadarThisFrame()
	end
	Citizen.Wait(1000)
	PhonePlayAnim('text', false, true)
end)