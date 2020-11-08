RegisterNetEvent("gcPhone:tchat_receive")
AddEventHandler("gcPhone:tchat_receive", function(message)
    SendNUIMessage({event = 'tchat_receive', message = message})
end)

RegisterNetEvent("gcPhone:tchat_channel")
AddEventHandler("gcPhone:tchat_channel", function(channel, messages)
    SendNUIMessage({event = 'tchat_channel', messages = messages})
end)

RegisterNUICallback('tchat_notify', function(data, cb)
    local text = '~o~Nieuw bericht in deepweb kanaal: ~y~'.. data.channel
    SetNotificationTextEntry("STRING")
    AddTextComponentString(text)
    DrawNotification(false, false)
end)

RegisterNUICallback('tchat_addMessage', function(data, cb)
    if data.message == '%pos%' then
		local myPos = GetEntityCoords(PlayerPedId())
		data.message = 'GPS: ' .. myPos.x .. ', ' .. myPos.y
    end
    TriggerServerEvent('gcPhone:tchat_addMessage', data.channel, data.message)
end)

RegisterNUICallback('tchat_getChannel', function(data, cb)
    TriggerServerEvent('gcPhone:tchat_channel', data.channel)
end)
