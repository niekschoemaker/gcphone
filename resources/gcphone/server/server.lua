--====================================================================================
-- #Author: Jonathan D @Gannon
-- #Version 2.0
--====================================================================================
ESX = nil
--- @type function
local internalAddMessage
QueryCounter = {}
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

RegisterCommand('getquerycount', function()
	local sb = {}
	local a = {}
	for k,v in pairs(QueryCounter) do
		if v > 0 then
			table.insert(a, {value = v, key = k })
		end
	end
    table.sort(a, function(a, b) return a.value>b.value end)
	for k,v in ipairs(a) do
		sb[#sb + 1] = ("%-30s:%5s"):format(v.key, v.value)
	end
	print(table.concat(sb, "\n"))
end, true)

MySQL.ready(function()
	MySQL.Async.execute(
		"DELETE FROM `phone_messages` "
		.."WHERE `time` < DATE_ADD(NOW(), INTERVAL -14 DAY)",
	{},
	function(result)
		print(("[gcphone] removed %s messages"):format(result))
	end)
	MySQL.Async.execute(
		"DELETE FROM `twitter_tweets` "
		.."WHERE `time` < DATE_ADD(NOW(), INTERVAL -15 DAY)",
	{},
	function(result)
		print(("[gcphone] removed %s messages"):format(result))
	end)
	MySQL.Async.execute(
		"UPDATE twitter_tweets "
		.."SET `old` = 1 "
		.."WHERE `old` != 1 AND id NOT IN (SELECT id FROM (SELECT `id` FROM twitter_tweets ORDER BY `time` DESC LIMIT 130) tmp)",
	{},
	function(result)
		print(("[gcphone] marked %s tweets as old"):format(result))
	end)
end)

math.randomseed(os.time())

--- Pour les numero du style XXX-XXXX
--function getPhoneRandomNumber()
--    local numBase0 = math.random(100,999)
--    local numBase1 = math.random(0,9999)
--    local num = string.format("%03d-%04d", numBase0, numBase1 )
--	return num
--end

--- Exemple pour les numero du style 06XXXXXXXX
function GetPhoneRandomNumber()
	return '0' .. math.random(600000000,699999999)
end


--[[
Ouverture du téphone lié a un item
Un solution ESC basé sur la solution donnée par HalCroves
https://forum.fivem.net/t/tutorial-for-gcphone-with-call-and-job-message-other/177904
--]]

local ESX = nil
TriggerEvent('esx:getSharedObject', function(obj)
	ESX = obj
	ESX.RegisterServerCallback('gcphone:getItemAmount', function(source, cb, item)
		local items = ESX.Player.GetInventoryItem(source, item)
		if items == nil then
			cb(0)
		else
			cb(items.count)
		end
	end)
end)

RegisterNetEvent('gcphone:setTaken')
AddEventHandler('gcphone:setTaken', function(reference)
	local source = source
	TriggerClientEvent('gcphone:setTaken', -1, source, reference)
end)


--====================================================================================
--  Utils
--====================================================================================
function getSourceFromIdentifier(identifier)
	return ESX.Player.GetSourceFromIdentifier(identifier)
end

QueryCounter["GetNumberPhone"] = 0
local numberCache = {}
function GetPhoneNumber(identifier, ignoreCache)
	if numberCache[identifier] and not ignoreCache then
		return numberCache[identifier]
	end
	QueryCounter["GetNumberPhone"] = QueryCounter["GetNumberPhone"] + 1
	local result = MySQL.Sync.fetchAll(
		"SELECT users.phone_number "
		.."FROM users "
		.."WHERE users.identifier = @identifier",
	{
		['@identifier'] = identifier
	})
	if result[1] ~= nil then
		if result[1].phone_number then
			numberCache[identifier] = result[1].phone_number
		end
		return result[1].phone_number
	end
	return nil
end

QueryCounter["getIdentifierByPhoneNumber"] = 0
local identifierCache = {}
function GetIdentifierFromPhoneNumber(phone_number)
	if identifierCache[phone_number] then
		return identifierCache[phone_number]
	end
	QueryCounter["getIdentifierByPhoneNumber"] = QueryCounter["getIdentifierByPhoneNumber"] + 1
	local result = MySQL.Sync.fetchAll(
		"SELECT users.identifier "
		.."FROM users "
		.."WHERE users.phone_number = @phone_number",
	{
		['@phone_number'] = phone_number
	})
	if result[1] ~= nil then
		identifierCache[phone_number] = result[1].identifier
		return result[1].identifier
	end
	return nil
end


function getPlayerID(source)
	return GetPlayerIdentifier(source, 0)
end

QueryCounter["getOrGeneratePhoneNumber"] = 0
function GetOrGeneratePhoneNumber(sourcePlayer, identifier, cb)
	local myPhoneNumber = GetPhoneNumber(identifier)
	if myPhoneNumber == '0' or myPhoneNumber == nil then
		repeat
			myPhoneNumber = GetPhoneRandomNumber()
			local id = GetIdentifierFromPhoneNumber(myPhoneNumber)
		until id == nil
		QueryCounter["getOrGeneratePhoneNumber"] = QueryCounter["getOrGeneratePhoneNumber"] + 1
		MySQL.Async.insert(
			"UPDATE users "
			.."SET phone_number = @myPhoneNumber "
			.."WHERE identifier = @identifier",
		{
			['@myPhoneNumber'] = myPhoneNumber,
			['@identifier'] = identifier
		}, function()
			cb(myPhoneNumber)
		end)
	else
		cb(myPhoneNumber)
	end
end

ESX.RegisterUsableItem('simcard', function(source)
	local identifier = ESX.Player.GetIdentifier(source)
	local myOldPhoneNumber = GetPhoneNumber(identifier)
	local myPhoneNumber = 0
	repeat
		myPhoneNumber = GetPhoneRandomNumber()
		local id = GetIdentifierFromPhoneNumber(myPhoneNumber)
	until id == nil
	MySQL.Async.insert(
			"UPDATE users "
			.."SET phone_number = @myPhoneNumber "
			.."WHERE identifier = @identifier",
	{
		['@myPhoneNumber'] = myPhoneNumber,
		['@identifier'] = identifier
	}, function() end)

	MySQL.Async.insert(
			"INSERT INTO phone_simcard "
			.."VALUES(@identifier, @myOldNumber, @myNewNumber)",
	{
		['@myOldNumber'] = myOldPhoneNumber,
		['@myNewNumber'] = myPhoneNumber,
		['@identifier'] = identifier
	}, function()
		print("[gcphone] ".. identifier .. " updated " .. myOldPhoneNumber .. " to " .. myPhoneNumber)
	end)

	ESX.Player.RemoveInventoryItem(source,'simcard', 1)
	TriggerClientEvent("gcPhone:myPhoneNumber", source, myPhoneNumber)
	TriggerClientEvent("gcPhone:contactList", source, GetContacts(identifier))
	TriggerClientEvent("gcPhone:allMessage", source, GetMessages(identifier))
	SendCallHistory(source, myPhoneNumber)
end)


--====================================================================================
--  Contacts
--====================================================================================
function GetContacts(identifier)
	local result = MySQL.Sync.fetchAll(
			"SELECT * "
			.."FROM phone_users_contacts "
			.."WHERE phone_users_contacts.identifier = @identifier",
	{
		['@identifier'] = identifier
	})
	return result
end

QueryCounter["addContact"] = 0
function AddContact(source, identifier, number, display)
	local sourcePlayer = tonumber(source)
	QueryCounter["addContact"] = QueryCounter["addContact"] + 1
	MySQL.Async.insert(
		"INSERT INTO phone_users_contacts (`identifier`, `number`,`display`) "
		.."VALUES(@identifier, @number, @display)",
	{
		['@identifier'] = identifier,
		['@number'] = number,
		['@display'] = display,
	},function()
		NotifyContactChange(sourcePlayer, identifier)
	end)
end

QueryCounter["updateContact"] = 0
function UpdateContact(source, identifier, id, number, display)
	local sourcePlayer = tonumber(source)
	QueryCounter["updateContact"] = QueryCounter["updateContact"] + 1
	MySQL.Async.insert(
		"UPDATE phone_users_contacts "
		.."SET number = @number, display = @display "
		.."WHERE id = @id",
	{
		['@number'] = number,
		['@display'] = display,
		['@id'] = id,
	},function()
		NotifyContactChange(sourcePlayer, identifier)
	end)
end

QueryCounter["deleteContact"] = 0
function DeleteContact(source, identifier, id)
	local sourcePlayer = tonumber(source)
	QueryCounter["deleteContact"] = QueryCounter["deleteContact"] + 1
	MySQL.Sync.execute(
		"DELETE FROM phone_users_contacts "
		.."WHERE `identifier` = @identifier AND `id` = @id",
	{
		['@identifier'] = identifier,
		['@id'] = id,
	})
	NotifyContactChange(sourcePlayer, identifier)
end

QueryCounter["blockContact"] = 0
function BlockContact(source, identifier, id, blocked)
	local sourcePlayer = tonumber(source)
	QueryCounter["blockContact"] = QueryCounter["blockContact"] + 1
	MySQL.Sync.execute(
		"UPDATE phone_users_contacts "
		.."SET blocked = @blocked "
		.."WHERE `identifier` = @identifier AND `id` = @id",
	{
		['@identifier'] = identifier,
		['@blocked'] = blocked and true or false,
		['@id'] = id,
	})
	NotifyContactChange(sourcePlayer, identifier)
end

QueryCounter["deleteAllContact"] = 0
function DeleteAllContact(identifier)
	QueryCounter["deleteAllContact"] = QueryCounter["deleteAllContact"] + 1
	MySQL.Sync.execute(
		"DELETE FROM phone_users_contacts "
		.."WHERE `identifier` = @identifier",
	{
		['@identifier'] = identifier
	})
end
function NotifyContactChange(source, identifier)
	local sourcePlayer = tonumber(source)
	local identifier = identifier
	if sourcePlayer ~= nil then
		TriggerClientEvent("gcPhone:contactList", sourcePlayer, GetContacts(identifier))
	end
end

RegisterServerEvent('gcPhone:addContact')
AddEventHandler('gcPhone:addContact', function(display, phoneNumber)
	local source = source
	local sourcePlayer = tonumber(source)
	local identifier = getPlayerID(source)
	AddContact(sourcePlayer, identifier, phoneNumber, display)
end)

RegisterServerEvent('gcPhone:updateContact')
AddEventHandler('gcPhone:updateContact', function(id, display, phoneNumber)
	local source = source
	local sourcePlayer = tonumber(source)
	local identifier = getPlayerID(source)
	UpdateContact(sourcePlayer, identifier, id, phoneNumber, display)
end)

RegisterServerEvent('gcPhone:deleteContact')
AddEventHandler('gcPhone:deleteContact', function(id)
	local sourcePlayer = tonumber(source)
	local identifier = getPlayerID(sourcePlayer)
	DeleteContact(sourcePlayer, identifier, id)
end)

RegisterNetEvent('gcPhone:blockContact')
AddEventHandler('gcPhone:blockContact', function(id, blocked)
	local sourcePlayer = tonumber(source)
	local identifier = getPlayerID(sourcePlayer)
	BlockContact(sourcePlayer, identifier, id, blocked)
end)

--====================================================================================
--  Messages
--====================================================================================
QueryCounter["getMessages"] = 0
function GetMessages(identifier)
	QueryCounter["getMessages"] = QueryCounter["getMessages"] + 1
	local result = MySQL.Sync.fetchAll(
		"SELECT phone_messages.* "
		.."FROM phone_messages "
		.."LEFT JOIN users ON users.identifier = @identifier "
		.."WHERE phone_messages.receiver = users.phone_number AND phone_messages.deleted = 0",
	{
		['@identifier'] = identifier
	})
	return result
	--return MySQLQueryTimeStamp("SELECT phone_messages.* FROM phone_messages LEFT JOIN users ON users.identifier = @identifier WHERE phone_messages.receiver = users.phone_number", {['@identifier'] = identifier})
end

RegisterServerEvent('gcPhone:_internalAddMessage')
AddEventHandler('gcPhone:_internalAddMessage', function(transmitter, receiver, message, owner, cb)
	cb(internalAddMessage(transmitter, receiver, message, owner))
end)

QueryCounter["_internalAddMessage"] = 0
--- Function to add message to database
--- @param transmitter string
--- @param receiver string
--- @param message string
--- @param owner integer
--- @return table message
function internalAddMessage(transmitter, receiver, message, owner)
	QueryCounter["_internalAddMessage"] = QueryCounter["_internalAddMessage"] + 1
	local Query =
		"INSERT INTO phone_messages (`transmitter`, `receiver`,`message`, `isRead`,`owner`) "
		.."VALUES(@transmitter, @receiver, @message, @isRead, @owner);"

	local time = os.time() * 1000.0
	local Parameters = {
		['@transmitter'] = transmitter,
		['@receiver'] = receiver,
		['@message'] = message,
		['@isRead'] = owner,
		['@owner'] = owner
	}
	local id = MySQL.Sync.insert(Query, Parameters)
	return {transmitter = transmitter, receiver = receiver, owner = owner, id = id, message = message, isRead = owner, time = time}
end

function AddMessage(source, identifier, phone_number, message)
	local sourcePlayer = tonumber(source)
	local otherIdentifier = GetIdentifierFromPhoneNumber(phone_number)
	local myPhone = GetPhoneNumber(identifier)
	if otherIdentifier ~= nil then
		local tomess = internalAddMessage(myPhone, phone_number, message, 0)
		local sourceOther = ESX.Player.GetSourceFromIdentifier(otherIdentifier)
		if sourceOther then
			TriggerClientEvent("gcPhone:receiveMessage", sourceOther, tomess)
		end
	end
	local memess = internalAddMessage(phone_number, myPhone, message, 1)
	TriggerClientEvent("gcPhone:receiveMessage", sourcePlayer, memess)
end

QueryCounter["setReadMessageNumber"] = 0
function SetReadMessageNumber(identifier, num)
	local mePhoneNumber = GetPhoneNumber(identifier)
	QueryCounter["setReadMessageNumber"] = QueryCounter["setReadMessageNumber"] + 1
	MySQL.Sync.execute(
		"UPDATE phone_messages "
		.."SET phone_messages.isRead = 1 "
		.."WHERE phone_messages.receiver = @receiver AND phone_messages.transmitter = @transmitter",
	{
		['@receiver'] = mePhoneNumber,
		['@transmitter'] = num
	})
end

QueryCounter["deleteMessage"] = 0
function DeleteMessage(msgId)
	QueryCounter["deleteMessage"] = QueryCounter["deleteMessage"] + 1
	MySQL.Sync.execute("UPDATE phone_messages SET deleted = 1 WHERE `id` = @id", {
		['@id'] = msgId
	})
end

QueryCounter["deleteAllMessageFromPhoneNumber"] = 0
function DeleteAllMessageFromPhoneNumber(source, identifier, phone_number)
	local source = source
	local identifier = identifier
	local mePhoneNumber = GetPhoneNumber(identifier)
	QueryCounter["deleteAllMessageFromPhoneNumber"] = QueryCounter["deleteAllMessageFromPhoneNumber"] + 1
	MySQL.Async.execute(
		"DELETE FROM phone_messages "
		.."WHERE `receiver` = @mePhoneNumber and `transmitter` = @phone_number",
	{
		['@mePhoneNumber'] = mePhoneNumber,
		['@phone_number'] = phone_number
	}, function() end)
end

QueryCounter["deleteAllMessage"] = 0
function DeleteAllMessage(identifier)
	local mePhoneNumber = GetPhoneNumber(identifier)
	QueryCounter["deleteAllMessage"] = QueryCounter["deleteAllMessage"] + 1
	MySQL.Async.execute(
		"DELETE FROM phone_messages "
		.."WHERE `receiver` = @mePhoneNumber",
	{
		['@mePhoneNumber'] = mePhoneNumber
	}, function() end)
end

local rateLimiters = {}
RegisterServerEvent('gcPhone:sendMessage')
AddEventHandler('gcPhone:sendMessage', function(phoneNumber, message)
	local source = source
	if rateLimiters[source] and os.time() - rateLimiters[source] < 3 then
		print(("Rate limited message sent by %s (%s)"):format(GetPlayerName(source), GetPlayerIdentifier(source, 0)))
		return
	end
	rateLimiters[source] = os.time()
	local sourcePlayer = tonumber(source)
	local identifier = getPlayerID(source)
	AddMessage(sourcePlayer, identifier, phoneNumber, message)
end)

ESX.RegisterServerCallback("gcPhone:getPhoneNumber", function(identifier ,cb)
	cb(GetPhoneNumber(identifier))
end)

RegisterServerEvent('gcPhone:deleteMessage')
AddEventHandler('gcPhone:deleteMessage', function(msgId)
	DeleteMessage(msgId)
end)

RegisterServerEvent('gcPhone:deleteMessageNumber')
AddEventHandler('gcPhone:deleteMessageNumber', function(number)
	local sourcePlayer = tonumber(source)
	local identifier = getPlayerID(source)
	DeleteAllMessageFromPhoneNumber(sourcePlayer,identifier, number)
end)

RegisterServerEvent('gcPhone:deleteAllMessage')
AddEventHandler('gcPhone:deleteAllMessage', function()
	local sourcePlayer = tonumber(source)
	local identifier = getPlayerID(source)
	DeleteAllMessage(identifier)
end)

RegisterServerEvent('gcPhone:setReadMessageNumber')
AddEventHandler('gcPhone:setReadMessageNumber', function(num)
	local identifier = getPlayerID(source)
	SetReadMessageNumber(identifier, num)
end)

RegisterServerEvent('gcPhone:deleteALL')
AddEventHandler('gcPhone:deleteALL', function()
	local sourcePlayer = tonumber(source)
	local identifier = getPlayerID(source)
	DeleteAllMessage(identifier)
	DeleteAllContact(identifier)
	appelsDeleteAllHistorique(identifier)
	TriggerClientEvent("gcPhone:contactList", sourcePlayer, {})
	TriggerClientEvent("gcPhone:allMessage", sourcePlayer, {})
	TriggerClientEvent("appelsDeleteAllHistorique", sourcePlayer, {})
end)

--====================================================================================
--  Gestion des appels
--====================================================================================
local AppelsEnCours = {}
local PhoneFixeInfo = {}
local lastIndexCall = 10

QueryCounter["getHistoriqueCall"] = 0
function GetCallHistory(num)
	QueryCounter["getHistoriqueCall"] = QueryCounter["getHistoriqueCall"] + 1
	local result = MySQL.Sync.fetchAll(
		"SELECT * FROM phone_calls "
		.."WHERE phone_calls.owner = @num "
		.."ORDER BY time DESC LIMIT 120",
	{
		['@num'] = num
	})
	return result
end

function SendCallHistory(src, num)
	local histo = GetCallHistory(num)
	TriggerClientEvent('gcPhone:historiqueCall', src, histo)
end

QueryCounter["saveAppels"] = 0
function SaveCall(appelInfo)
	if not appelInfo.extraData or appelInfo.extraData.useNumber == nil then
		QueryCounter["saveAppels"] = QueryCounter["saveAppels"] + 1
		MySQL.Async.insert(
			"INSERT INTO phone_calls (`owner`, `num`,`incoming`, `accepts`) "
			.."VALUES(@owner, @num, @incoming, @accepts)",
		{
			['@owner'] = appelInfo.transmitter_num,
			['@num'] = appelInfo.receiver_num,
			['@incoming'] = 1,
			['@accepts'] = appelInfo.is_accepts
		}, function()
			notifyNewAppelsHisto(appelInfo.transmitter_src, appelInfo.transmitter_num)
		end)
	end
	if appelInfo.is_valid == true then
		local num = appelInfo.transmitter_num
		if appelInfo.hidden == true then
			num = "###-####"
		end
		QueryCounter["saveAppels"] = QueryCounter["saveAppels"] + 1
		MySQL.Async.insert(
			"INSERT INTO phone_calls (`owner`, `num`,`incoming`, `accepts`) "
			.."VALUES(@owner, @num, @incoming, @accepts)",
		{
			['@owner'] = appelInfo.receiver_num,
			['@num'] = num,
			['@incoming'] = 0,
			['@accepts'] = appelInfo.is_accepts
		}, function()
			if appelInfo.receiver_src ~= nil then
				notifyNewAppelsHisto(appelInfo.receiver_src, appelInfo.receiver_num)
			end
		end)
	end
end

function notifyNewAppelsHisto(src, num)
	SendCallHistory(src, num)
end

RegisterServerEvent('gcPhone:getHistoriqueCall')
AddEventHandler('gcPhone:getHistoriqueCall', function()
	local sourcePlayer = tonumber(source)
	local srcIdentifier = getPlayerID(source)
	local srcPhone = GetPhoneNumber(srcIdentifier)
	SendCallHistory(sourcePlayer, srcPhone)
end)

AddEventHandler('gcPhone:internal_startCall', function(source, phone_number, rtcOffer, extraData)
	if rtcOffer == false then
		rtcOffer = nil
	end
	if extraData == false then
		extraData = nil
	end
	if FixePhone[phone_number] ~= nil then
		OnCallLandlinePhone(source, phone_number, rtcOffer, extraData)
		return
	end

	local rtcOffer = rtcOffer
	if phone_number == nil or phone_number == '' then 
		print('BAD CALL NUMBER IS NIL')
		return
	end

	local hidden = string.sub(phone_number, 1, 1) == '#'
	if hidden == true then
		phone_number = string.sub(phone_number, 2)
	end
	local indexCall = lastIndexCall
	if lastIndexCall < 1000 then
		lastIndexCall = lastIndexCall + math.random(1, 10)
	else
		lastIndexCall = math.random(1, 10)
	end

	local sourcePlayer = tonumber(source)
	local srcIdentifier = ESX.Player.GetIdentifier(source)

	local srcPhone = ''
	if extraData and extraData.useNumber ~= nil then
		srcPhone = extraData.useNumber
	else
		srcPhone = GetPhoneNumber(srcIdentifier)
	end
	local destPlayer = GetIdentifierFromPhoneNumber(phone_number)
	local is_valid = destPlayer ~= nil and destPlayer ~= srcIdentifier
	AppelsEnCours[indexCall] = {
		id = indexCall,
		transmitter_src = sourcePlayer,
		transmitter_num = srcPhone,
		receiver_src = nil,
		receiver_num = phone_number,
		is_valid = destPlayer ~= nil,
		is_accepts = false,
		hidden = hidden,
		rtcOffer = rtcOffer,
		extraData = extraData
	}

	if is_valid == true then
		local destSource = ESX.Player.GetSourceFromIdentifier(destPlayer)
		if destSource then
			local item = ESX.Player.GetInventoryItem(destSource, 'phone')
			if item and item.count > 0 then
				AppelsEnCours[indexCall].receiver_src = destSource
				TriggerEvent('gcPhone:addCall', AppelsEnCours[indexCall])
				TriggerClientEvent('gcPhone:waitingCall', sourcePlayer, AppelsEnCours[indexCall], true)
				TriggerClientEvent('gcPhone:waitingCall', destSource, AppelsEnCours[indexCall], false)
			else
				TriggerClientEvent('esx:showNotification', sourcePlayer, "Deze persoon heeft geen telefoon...")
				AppelsEnCours[indexCall] = nil
			end
		else
			TriggerClientEvent('esx:showNotification', sourcePlayer, "Deze persoon is niet aanwezig...")
			AppelsEnCours[indexCall] = nil
		end
	else
		TriggerClientEvent('esx:showNotification', sourcePlayer, "Dit telefoonnummer bestaat niet...")
		AppelsEnCours[indexCall] = nil
	end
end)

RegisterServerEvent('gcPhone:startCall')
AddEventHandler('gcPhone:startCall', function(phone_number, rtcOffer, extraData)
	local source = source
	TriggerEvent('gcPhone:internal_startCall',source, phone_number, rtcOffer, extraData)
end)

RegisterServerEvent('gcPhone:candidates')
AddEventHandler('gcPhone:candidates', function (callId, candidates)
	if AppelsEnCours[callId] ~= nil then
		local source = source
		local to = AppelsEnCours[callId].transmitter_src
		if source == to then 
			to = AppelsEnCours[callId].receiver_src
		end

		TriggerClientEvent('gcPhone:candidates', to, candidates)
	end
end)


RegisterServerEvent('gcPhone:acceptCall')
AddEventHandler('gcPhone:acceptCall', function(infoCall, rtcAnswer)
	if not rtcAnswer then
		rtcAnswer = nil
	end
	local id = infoCall.id
	if AppelsEnCours[id] ~= nil then
		if PhoneFixeInfo[id] ~= nil then
			OnAcceptLandlinePhone(source, infoCall, rtcAnswer)
			return
		end
		AppelsEnCours[id].receiver_src = infoCall.receiver_src or AppelsEnCours[id].receiver_src
		if AppelsEnCours[id].transmitter_src ~= nil and AppelsEnCours[id].receiver_src ~= nil then
			AppelsEnCours[id].is_accepts = true
			AppelsEnCours[id].rtcAnswer = rtcAnswer
			TriggerClientEvent('gcPhone:acceptCall', AppelsEnCours[id].transmitter_src, AppelsEnCours[id], true)
			TriggerClientEvent('gcPhone:acceptCall', AppelsEnCours[id].receiver_src, AppelsEnCours[id], false)
			SaveCall(AppelsEnCours[id])
		end
	end
end)


RegisterServerEvent('gcPhone:rejectCall')
AddEventHandler('gcPhone:rejectCall', function (infoCall)
	local id = infoCall.id
	if AppelsEnCours[id] ~= nil then
		if PhoneFixeInfo[id] ~= nil then
			OnRejectLandlinePhone(source, infoCall)
			return
		end
		if AppelsEnCours[id].transmitter_src ~= nil then
			TriggerClientEvent('gcPhone:rejectCall', AppelsEnCours[id].transmitter_src)
		end
		if AppelsEnCours[id].receiver_src ~= nil then
			TriggerClientEvent('gcPhone:rejectCall', AppelsEnCours[id].receiver_src)
		end
		
		if AppelsEnCours[id].is_accepts == false then 
			SaveCall(AppelsEnCours[id])
		end
		TriggerEvent('gcPhone:removeCall', AppelsEnCours)
		AppelsEnCours[id] = nil
	end
end)

QueryCounter["gcPhone:appelsDeleteHistorique"] = 0
RegisterServerEvent('gcPhone:appelsDeleteHistorique')
AddEventHandler('gcPhone:appelsDeleteHistorique', function (numero)
	local sourcePlayer = tonumber(source)
	local srcIdentifier = getPlayerID(source)
	local srcPhone = GetPhoneNumber(srcIdentifier)
	QueryCounter["gcPhone:appelsDeleteHistorique"] = QueryCounter["gcPhone:appelsDeleteHistorique"] + 1
	MySQL.Sync.execute(
		"DELETE FROM phone_calls "
		.."WHERE `owner` = @owner AND `num` = @num",
	{
		['@owner'] = srcPhone,
		['@num'] = numero
	})
end)

QueryCounter["appelsDeleteAllHistorique"] = 0
function appelsDeleteAllHistorique(srcIdentifier)
	local srcPhone = GetPhoneNumber(srcIdentifier)
	QueryCounter["appelsDeleteAllHistorique"] = QueryCounter["appelsDeleteAllHistorique"] + 1
	MySQL.Sync.execute(
		"DELETE FROM phone_calls "
		.."WHERE `owner` = @owner",
	{
		['@owner'] = srcPhone
	})
end

RegisterServerEvent('gcPhone:appelsDeleteAllHistorique')
AddEventHandler('gcPhone:appelsDeleteAllHistorique', function ()
	local sourcePlayer = tonumber(source)
	local srcIdentifier = getPlayerID(source)
	appelsDeleteAllHistorique(srcIdentifier)
end)


--====================================================================================
--  OnLoad
--====================================================================================
AddEventHandler('es:playerLoaded',function(source)
	local sourcePlayer = tonumber(source)
	local identifier = getPlayerID(source)
	GetOrGeneratePhoneNumber(sourcePlayer, identifier, function (myPhoneNumber)
		TriggerClientEvent("gcPhone:myPhoneNumber", sourcePlayer, myPhoneNumber)
		TriggerClientEvent("gcPhone:contactList", sourcePlayer, GetContacts(identifier))
		TriggerClientEvent("gcPhone:allMessage", sourcePlayer, GetMessages(identifier))
	end)
end)

-- Just For reload
RegisterServerEvent('gcPhone:allUpdate')
AddEventHandler('gcPhone:allUpdate', function()
	local sourcePlayer = tonumber(source)
	local identifier = getPlayerID(source)
	local num = GetPhoneNumber(identifier)
	TriggerClientEvent("gcPhone:myPhoneNumber", sourcePlayer, num)
	TriggerClientEvent("gcPhone:contactList", sourcePlayer, GetContacts(identifier))
	TriggerClientEvent("gcPhone:allMessage", sourcePlayer, GetMessages(identifier))
	--TriggerLatentClientEvent('gcPhone:getBourse', sourcePlayer, 100000, getBourse())
	SendCallHistory(sourcePlayer, num)
end)

--====================================================================================
--  App bourse
--====================================================================================
function GetStocks()
	--  Format
	--  Array 
	--    Object
	--      -- libelle type String    | Nom
	--      -- price type number      | Prix actuelle
	--      -- difference type number | Evolution 
	-- 
	-- local result = MySQL.Sync.fetchAll("SELECT * FROM `recolt` LEFT JOIN `items` ON items.`id` = recolt.`treated_id` WHERE fluctuation = 1 ORDER BY price DESC",{})
	local result = {
		{
			libelle = 'Google',
			price = 125.2,
			difference =  -12.1
		},
		{
			libelle = 'Microsoft',
			price = 132.2,
			difference = 3.1
		},
		{
			libelle = 'Amazon',
			price = 120,
			difference = 0
		}
	}
	return result
end

--====================================================================================
--  App ... WIP
--====================================================================================


-- SendNUIMessage('ongcPhoneRTC_receive_offer')
-- SendNUIMessage('ongcPhoneRTC_receive_answer')

-- RegisterNUICallback('gcPhoneRTC_send_offer', function (data)


-- end)


-- RegisterNUICallback('gcPhoneRTC_send_answer', function (data)


-- end)



function OnCallLandlinePhone(source, phone_number, rtcOffer, extraData)
	local indexCall = lastIndexCall
	lastIndexCall = lastIndexCall + 1
	
	local hidden = string.sub(phone_number, 1, 1) == '#'
	if hidden == true then
		phone_number = string.sub(phone_number, 2)
	end
	local sourcePlayer = tonumber(source)
	local srcIdentifier = getPlayerID(source)
	
	local srcPhone = ''
	if extraData ~= nil and extraData.useNumber ~= nil then
		srcPhone = extraData.useNumber
	else
		srcPhone = GetPhoneNumber(srcIdentifier)
	end
	
	AppelsEnCours[indexCall] = {
		id = indexCall,
		transmitter_src = sourcePlayer,
		transmitter_num = srcPhone,
		receiver_src = nil,
		receiver_num = phone_number,
		is_valid = false,
		is_accepts = false,
		hidden = hidden,
		rtcOffer = rtcOffer,
		extraData = extraData,
		coords = FixePhone[phone_number].coords
	}

	PhoneFixeInfo[indexCall] = AppelsEnCours[indexCall]

	TriggerClientEvent('gcPhone:notifyFixePhoneChange', -1, PhoneFixeInfo)
	TriggerClientEvent('gcPhone:waitingCall', sourcePlayer, AppelsEnCours[indexCall], true)
end

AddEventHandler('playerDropped', function(reason)
	local source = source

end)

function OnAcceptLandlinePhone(source, infoCall, rtcAnswer)
	local id = infoCall.id
	
	AppelsEnCours[id].receiver_src = source
	if AppelsEnCours[id].transmitter_src ~= nil and AppelsEnCours[id].receiver_src~= nil then
		AppelsEnCours[id].is_accepts = true
		AppelsEnCours[id].forceSaveAfter = true
		AppelsEnCours[id].rtcAnswer = rtcAnswer
		PhoneFixeInfo[id] = nil
		TriggerClientEvent('gcPhone:notifyFixePhoneChange', -1, PhoneFixeInfo)
		TriggerClientEvent('gcPhone:acceptCall', AppelsEnCours[id].transmitter_src, AppelsEnCours[id], true)
		TriggerClientEvent('gcPhone:acceptCall', AppelsEnCours[id].receiver_src, AppelsEnCours[id], false)
		SaveCall(AppelsEnCours[id])
	end
end

function OnRejectLandlinePhone(source, infoCall, rtcAnswer)
	local id = infoCall.id
	PhoneFixeInfo[id] = nil
	TriggerClientEvent('gcPhone:notifyFixePhoneChange', -1, PhoneFixeInfo)
	TriggerClientEvent('gcPhone:rejectCall', AppelsEnCours[id].transmitter_src)
	if AppelsEnCours[id].is_accepts == false then
		SaveCall(AppelsEnCours[id])
	end
	AppelsEnCours[id] = nil
end