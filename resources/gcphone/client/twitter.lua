--====================================================================================
-- #Author: Jonathan D @ Gannon
--====================================================================================
local twitterChatEnabled = true

Citizen.CreateThread(function()
	local data = GetResourceKvpString("twitter_chat")
	if data then
		twitterChatEnabled = json.decode(data)
	end
end)

RegisterNetEvent("gcPhone:twitter_getTweets")
AddEventHandler("gcPhone:twitter_getTweets", function(tweets)
	SendNUIMessage({event = 'twitter_tweets', tweets = tweets})
end)

RegisterNetEvent("gcPhone:twitter_getFavoriteTweets")
AddEventHandler("gcPhone:twitter_getFavoriteTweets", function(tweets)
	SendNUIMessage({event = 'twitter_favoritetweets', tweets = tweets})
end)

RegisterCommand("toggletwitter", function(source, args, raw)
	twitterChatEnabled = not twitterChatEnabled
	SetResourceKvp("twitter_chat", json.encode(twitterChatEnabled))
	if twitterChatEnabled then
		exports['esx_rpchat']:printToChat("Twitter", "Twitter berichten worden ^2weer^7 naar je chat gestuurd")
	else
		exports['esx_rpchat']:printToChat("Twitter", "Twitter berichten worden ^1niet meer^7 naar je chat gestuurd")
	end
end)

RegisterNetEvent("gcPhone:twitter_newTweets")
AddEventHandler("gcPhone:twitter_newTweets", function(tweet, data)
	hasPhone(function (hasPhone)
		if hasPhone == true or IsAdmin then
			SendNUIMessage({event = 'twitter_newTweet', tweet = tweet})
			if twitterChatEnabled or (tweet.author and string.find(tweet.author:lower(), "politie")) then
				local author = ("@%s"):format(tweet.author)
				if IsAdmin then
					author = ("[%s] %s @%s"):format(data.source, data.name, tweet.author)
				end
				TriggerEvent('chat:addMessage', {
					template = '<div style="padding: 0.5vw; margin: 0.5vw; background-color: rgba(28, 160, 242, 0.6); border-radius: 3px;"><i class="fab fa-twitter"></i> {0}:<br> {1}</div>',
					args = { author, tweet.message }
				})
			end
		end
	end)
end)

RegisterNetEvent("gcPhone:twitter_updateTweetLikes")
AddEventHandler("gcPhone:twitter_updateTweetLikes", function(tweetId, likes)
	SendNUIMessage({event = 'twitter_updateTweetLikes', tweetId = tweetId, likes = likes})
end)

RegisterNetEvent("gcPhone:twitter_setAccount")
AddEventHandler("gcPhone:twitter_setAccount", function(username, password, avatarUrl)
	SendNUIMessage({event = 'twitter_setAccount', username = username, password = password, avatarUrl = avatarUrl})
end)

RegisterNetEvent("gcPhone:twitter_createAccount")
AddEventHandler("gcPhone:twitter_createAccount", function(account)
	SendNUIMessage({event = 'twitter_createAccount', account = account})
end)

RegisterNetEvent("gcPhone:twitter_showError")
AddEventHandler("gcPhone:twitter_showError", function(title, message)
	ESX.ShowNotification("~r~Onjuiste gebruikersnaam of wachtwoord!~s~")
	SendNUIMessage({event = 'twitter_showError', message = message, title = title})
end)

RegisterNetEvent("gcPhone:twitter_showSuccess")
AddEventHandler("gcPhone:twitter_showSuccess", function(title, message)
	SendNUIMessage({event = 'twitter_showSuccess', message = message, title = title})
end)

RegisterNetEvent("gcPhone:twitter_setTweetLikes")
AddEventHandler("gcPhone:twitter_setTweetLikes", function(tweetId, isLikes)
	SendNUIMessage({event = 'twitter_setTweetLikes', tweetId = tweetId, isLikes = isLikes})
end)

RegisterNUICallback('twitter_login', function(data, cb)
	TriggerServerEvent('gcPhone:twitter_login', data.username, data.password)
end)
RegisterNUICallback('twitter_changePassword', function(data, cb)
	TriggerServerEvent('gcPhone:twitter_changePassword', data.username or '', data.password or '', data.newPassword)
end)


RegisterNUICallback('twitter_createAccount', function(data, cb)
	TriggerServerEvent('gcPhone:twitter_createAccount', data.username or '', data.password or '', data.avatarUrl or false)
end)

RegisterNUICallback('twitter_getTweets', function(data, cb)
	TriggerServerEvent('gcPhone:twitter_getTweets', data.username or '', data.password or '')
end)

RegisterNUICallback('twitter_getFavoriteTweets', function(data, cb)
	TriggerServerEvent('gcPhone:twitter_getFavoriteTweets', data.username or '', data.password or '')
end)

RegisterNUICallback('twitter_postTweet', function(data, cb)
	data.message = data.message:gsub("%^%d", "")
	TriggerServerEvent('gcPhone:twitter_postTweets', data.username or '', data.password or '', data.message, `gcPhone:twitter_postTweets`)
end)

RegisterNUICallback('twitter_toggleLikeTweet', function(data, cb)
	TriggerServerEvent('gcPhone:twitter_toogleLikeTweet', data.username or '', data.password or '', data.tweetId)
end)

RegisterNUICallback('twitter_setAvatarUrl', function(data, cb)
	TriggerServerEvent('gcPhone:twitter_setAvatarUrl', data.username or '', data.password or '', data.avatarUrl)
end)

function hasPhone (cb)
	while (ESX == nil) do
		Citizen.Wait(100)
	end
	local playerData = ESX.GetPlayerData()
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