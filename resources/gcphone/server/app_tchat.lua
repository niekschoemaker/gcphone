function TchatGetMessageChannel (channel, cb)
	MySQL.Async.fetchAll("SELECT * FROM phone_app_chat WHERE channel = @channel AND `time` > FROM_UNIXTIME(@time) ORDER BY time ASC LIMIT 200", {
		['@channel'] = channel,
		['@time'] = os.time() - (48 * 3600)
	}, cb)
end

function TchatAddMessage (channel, message, source)
	local name = GetPlayerName(source)
	local xPlayer = ESX.GetPlayerFromId(source)
	local identifier = xPlayer.identifier
	print('[gcphone:deepweb] deepweb message sent by: ' .. tostring(name) .. '(' .. identifier.. ')')
	TriggerEvent('DiscordBot:ToDiscord', 'deepweb', channel ..'\n',
	'```\n'
	..xPlayer.name..' [ID: '..source..'] ('..identifier..')\n'
	..message ..'```', 'user', true, source, false)
	local Query = "INSERT INTO phone_app_chat (`channel`, `message`, `identifier`) VALUES(@channel, @message, @identifier);"
	local Query2 = 'SELECT * from phone_app_chat WHERE `id` = @id;'
	local Parameters = {
		['@channel'] = channel,
		['@message'] = message,
		['@identifier'] = identifier
	}
	MySQL.Async.insert(Query, Parameters, function (id)
		MySQL.Async.fetchAll(Query2, { ['@id'] = id }, function (reponse)
			TriggerClientEvent('gcPhone:tchat_receive', -1, reponse[1])
		end)
	end)
end


RegisterServerEvent('gcPhone:tchat_channel')
AddEventHandler('gcPhone:tchat_channel', function(channel)
	local sourcePlayer = tonumber(source)
	TchatGetMessageChannel(channel, function (messages)
		TriggerClientEvent('gcPhone:tchat_channel', sourcePlayer, channel, messages)
	end)
end)

RegisterServerEvent('gcPhone:tchat_addMessage')
AddEventHandler('gcPhone:tchat_addMessage', function(channel, message)
	TchatAddMessage(channel, message, source)
end)