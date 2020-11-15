--====================================================================================
-- #Author: Jonathan D @ Gannon
--====================================================================================
function string.isNullOrWhitespace(value)
	return value and value:match("^%s*$") ~= nil
end
 
QueryCounter["TwitterGetTweets"] = 0
QueryCounter["TwitterGetTweetsAccount"] = 0
function TwitterGetTweets(accountId, cb)
	if accountId == nil then
		QueryCounter["TwitterGetTweets"] = QueryCounter["TwitterGetTweets"] + 1
		MySQL.Async.fetchAll([===[
		SELECT twitter_tweets.*,
			twitter_accounts.username as author,
			twitter_accounts.avatar_url as authorIcon
		FROM twitter_tweets
		LEFT JOIN twitter_accounts
		ON twitter_tweets.authorId = twitter_accounts.id
		WHERE old = 0
		ORDER BY time DESC LIMIT 130
		]===], {}, cb)
	else
		QueryCounter["TwitterGetTweetsAccount"] = QueryCounter["TwitterGetTweetsAccount"] + 1
		MySQL.Async.fetchAll([===[
		SELECT twitter_tweets.*,
			twitter_accounts.username as author,
			twitter_accounts.avatar_url as authorIcon,
			twitter_likes.id AS isLikes
		FROM twitter_tweets
		LEFT JOIN twitter_accounts
		ON twitter_tweets.authorId = twitter_accounts.id
		LEFT JOIN twitter_likes
		ON twitter_tweets.id = twitter_likes.tweetId AND twitter_likes.authorId = @accountId
		WHERE old = 0
		ORDER BY time DESC LIMIT 130
		]===],
		{
			['@accountId'] = accountId
		}, cb)
	end
end

QueryCounter["TwitterGetFavotireTweets"] = 0
QueryCounter["TwitterGetFavotireTweetsAccount"] = 0
function TwitterGetFavotireTweets (accountId, cb)
	if accountId == nil then
		QueryCounter["TwitterGetFavotireTweets"] = QueryCounter["TwitterGetFavotireTweets"] + 1
		MySQL.Async.fetchAll([===[
		SELECT twitter_tweets.*,
			twitter_accounts.username as author,
			twitter_accounts.avatar_url as authorIcon
		FROM twitter_tweets
		LEFT JOIN twitter_accounts
		ON twitter_tweets.authorId = twitter_accounts.id
		WHERE twitter_tweets.TIME > CURRENT_TIMESTAMP() - INTERVAL '15' DAY
		ORDER BY likes DESC, TIME DESC LIMIT 30
		]===], {}, cb)
	else
		QueryCounter["TwitterGetFavotireTweetsAccount"] = QueryCounter["TwitterGetFavotireTweetsAccount"] + 1
		MySQL.Async.fetchAll([===[
		SELECT twitter_tweets.*,
			twitter_accounts.username as author,
			twitter_accounts.avatar_url as authorIcon,
			twitter_likes.id AS isLikes
		FROM twitter_tweets
		LEFT JOIN twitter_accounts
		ON twitter_tweets.authorId = twitter_accounts.id
		LEFT JOIN twitter_likes
		ON twitter_tweets.id = twitter_likes.tweetId AND twitter_likes.authorId = @accountId
		WHERE twitter_tweets.TIME > CURRENT_TIMESTAMP() - INTERVAL '15' DAY
		ORDER BY likes DESC, TIME DESC LIMIT 30
		]===],
		{
			['@accountId'] = accountId
		}, cb)
	end
end

QueryCounter["getUser"] = 0
local passwordCache = {}
local rateLimit = {}
function GetUser(source, username, password, cb)
	if string.isNullOrWhitespace(username) or string.isNullOrWhitespace(password) then
		print("username or password is null of empty")
		cb(nil)
		return
	end

	local key = username .. password
	if passwordCache[key] == false then
		cb(nil)
		return
	elseif passwordCache[key] then
		cb(passwordCache[key])
		return
	end

	-- Make sure you can't crash the server by simply spamming Twitter log-ins
	if IsRateLimited(source, rateLimit, 2) then
		TriggerClientEvent('esx:showNotification', source, "Probeer het over enkele seconden opnieuw!")
		cb(nil)
		return
	end

	QueryCounter["getUser"] = QueryCounter["getUser"] + 1
	MySQL.Async.fetchAll(
		"SELECT id, username as author, avatar_url as authorIcon, password, identifier "
		.."FROM twitter_accounts "
		.."WHERE username = @username "
		.."LIMIT 1",
	{
		['@username'] = username,
	}, function (data)
		if not data[1] then
			cb(nil)
			return
		end

		local identifier = GetPlayerIdentifier(source, 0)
		if data[1].identifier == identifier then
			passwordCache[key] = data[1]
			cb(data[1])
		elseif VerifyPasswordHash(password, data[1].password) then
			MySQL.Async.execute(
				"UPDATE twitter_accounts "
				.."SET `identifier` = @identifier "
				.."WHERE `username` = @username "
				.."LIMIT 1",
			{
				['identifier'] = identifier,
				['username'] = username
			}, function() end)
			passwordCache[key] = data[1]
			cb(data[1])
		else
			passwordCache[key] = false
			cb(nil)
		end
	end)
end

function GetUserAsync(source, username, password, p)
	QueryCounter["getUser"] = QueryCounter["getUser"] + 1
	p = p or promise.new()
	if string.isNullOrWhitespace(username) or string.isNullOrWhitespace(password) then
		print("username or password is null of empty")
		p:resolve(nil)
		return p
	end

	local key = username .. password
	if passwordCache[key] == false then
		p:resolve(nil)
		return p
	elseif passwordCache[key] then
		p:resolve(passwordCache[key])
		return p
	end

	MySQL.Async.fetchAll(
		"SELECT id, username as author, avatar_url as authorIcon, password, identifier "
		.."FROM twitter_accounts "
		.."WHERE twitter_accounts.username = @username "
		.."LIMIT 1",
	{
		['username'] = username,
	}, function (data)
		if not data[1] then
			p:resolve(nil)
			passwordCache[key] = false
			return p
		end

		local identifier = GetPlayerIdentifier(source, 0)
		if data[1].identifier == identifier then
			passwordCache[key] = data[1]
			p:resolve(data[1])
		elseif VerifyPasswordHash(password, data[1].password) then
			MySQL.Async.execute(
				"UPDATE twitter_accounts "
				.."SET `identifier` = @identifier "
				.."WHERE `username` = @username "
				.."LIMIT 1",
			{
				['identifier'] = identifier,
				['username'] = username
			}, function() end)
			passwordCache[key] = data[1]
			p:resolve(data[1])
		else
			p:resolve(nil)
		end
	end)
	return p
end

QueryCounter["TwitterPostTweet"] = 0
function TwitterPostTweet (username, password, message, source, realUser, cb)
	local p = GetUserAsync(source, username, password)
	if not p then
		if source ~= nil then
			TwitterShowError(source, 'Twitter Info', 'APP_TWITTER_NOTIF_LOGIN_ERROR')
		end
		return
	end
	local user = Citizen.Await(p)
	if not user then
		if source ~= nil then
			TwitterShowError(source, 'Twitter Info', 'APP_TWITTER_NOTIF_LOGIN_ERROR')
		end
		return
	end

	QueryCounter["TwitterPostTweet"] = QueryCounter["TwitterPostTweet"] + 1
	MySQL.Async.insert("INSERT INTO twitter_tweets (`authorId`, `message`, `realUser`) VALUES(@authorId, @message, @realUser);", {
		['@authorId'] = user.id,
		['@message'] = message,
		['@realUser'] = realUser
	}, function (id)
		QueryCounter["TwitterPostTweet"] = QueryCounter["TwitterPostTweet"] + 1
		MySQL.Async.fetchAll(
			'SELECT * '
			..'FROM twitter_tweets '
			..'WHERE id = @id',
		{
			['@id'] = id
		}, function (tweets)
			local tweet = tweets[1]
			tweet['author'] = user.author
			tweet['authorIcon'] = user.authorIcon
			TriggerClientEvent('gcPhone:twitter_newTweets', -1, tweet, { name = GetPlayerName(source), source = source })
			TriggerEvent('gcPhone:twitter_newTweets', tweet)
		end)
	end)
end

QueryCounter["TwitterToogleLike"] = 0
function TwitterToogleLike(username, password, tweetId, source)
	GetUser(source, username, password, function (user)
		if user == nil then
			if source ~= nil then
				TwitterShowError(source, 'Twitter Info', 'APP_TWITTER_NOTIF_LOGIN_ERROR')
			end
			return
		end
		QueryCounter["TwitterToogleLike"] = QueryCounter["TwitterToogleLike"] + 1
		MySQL.Async.fetchAll(
			'SELECT * '
			..'FROM twitter_tweets '
			..'WHERE id = @id',
		{
			['@id'] = tweetId
		}, function (tweets)
			if (tweets[1] == nil) then return end
			local tweet = tweets[1]
			QueryCounter["TwitterToogleLike"] = QueryCounter["TwitterToogleLike"] + 1
			MySQL.Async.fetchAll(
				'SELECT * '
				..'FROM twitter_likes '
				..'WHERE authorId = @authorId AND tweetId = @tweetId',
			{
				['authorId'] = user.id,
				['tweetId'] = tweetId
			}, function (row)
				if (row[1] == nil) then
					QueryCounter["TwitterToogleLike"] = QueryCounter["TwitterToogleLike"] + 1
					MySQL.Async.insert(
						'INSERT INTO twitter_likes (`authorId`, `tweetId`) '
						..'VALUES(@authorId, @tweetId)',
					{
						['authorId'] = user.id,
						['tweetId'] = tweetId
					}, function (newrow)
						QueryCounter["TwitterToogleLike"] = QueryCounter["TwitterToogleLike"] + 1
						MySQL.Async.execute(
							'UPDATE `twitter_tweets` '
							..'SET `likes`= likes + 1 '
							..'WHERE id = @id',
						{
							['@id'] = tweet.id
						}, function ()
							TriggerClientEvent('gcPhone:twitter_updateTweetLikes', -1, tweet.id, tweet.likes + 1)
							TriggerClientEvent('gcPhone:twitter_setTweetLikes', source, tweet.id, true)
							TriggerEvent('gcPhone:twitter_updateTweetLikes', tweet.id, tweet.likes + 1)
						end)
					end)
				else
					QueryCounter["TwitterToogleLike"] = QueryCounter["TwitterToogleLike"] + 1
					MySQL.Async.execute(
						'DELETE FROM twitter_likes '
						..'WHERE id = @id',
					{
						['@id'] = row[1].id,
					}, function (newrow)
						QueryCounter["TwitterToogleLike"] = QueryCounter["TwitterToogleLike"] + 1
						MySQL.Async.execute(
							'UPDATE `twitter_tweets` '
							..'SET `likes`= likes - 1 '
							..'WHERE id = @id',
						{
							['@id'] = tweet.id
						}, function ()
							TriggerClientEvent('gcPhone:twitter_updateTweetLikes', -1, tweet.id, tweet.likes - 1)
							TriggerClientEvent('gcPhone:twitter_setTweetLikes', source, tweet.id, false)
							TriggerEvent('gcPhone:twitter_updateTweetLikes', tweet.id, tweet.likes - 1)
						end)
					end)
				end
			end)
		end)
	end)
end

QueryCounter["TwitterCreateAccount"] = 0
function TwitterCreateAccount(username, password, avatarUrl, cb)
	QueryCounter["TwitterCreateAccount"] = QueryCounter["TwitterCreateAccount"] + 1
	MySQL.Async.fetchScalar('SELECT 1 FROM twitter_accounts WHERE `username` = @username', {['@username'] = username}, function(result)
		if result == nil then
			QueryCounter["TwitterCreateAccount"] = QueryCounter["TwitterCreateAccount"] + 1
			MySQL.Async.insert('INSERT IGNORE INTO twitter_accounts (`username`, `password`, `avatar_url`) VALUES(@username, @password, @avatarUrl)', {
				['username'] = username,
				['password'] = GetPasswordHash(password),
				['avatarUrl'] = avatarUrl
			}, cb)
		end
	end)
end
-- ALTER TABLE `twitter_accounts`	CHANGE COLUMN `username` `username` VARCHAR(50) NOT NULL DEFAULT '0' COLLATE 'utf8_general_ci';

function TwitterShowError (source, title, message)
	TriggerClientEvent('gcPhone:twitter_showError', source, message)
end
function TwitterShowSuccess (source, title, message)
	TriggerClientEvent('gcPhone:twitter_showSuccess', source, title, message)
end

RegisterServerEvent('gcPhone:twitter_login')
AddEventHandler('gcPhone:twitter_login', function(username, password)
	local source = tonumber(source)
	GetUser(source, username, password, function (user)
		if not user then
			TwitterShowError(source, 'Twitter Info', 'APP_TWITTER_NOTIF_LOGIN_ERROR')
		else
			TwitterShowSuccess(source, 'Twitter Info', 'APP_TWITTER_NOTIF_LOGIN_SUCCESS')
			TriggerClientEvent('gcPhone:twitter_setAccount', source, username, password, user.authorIcon)
		end
	end)
end)

QueryCounter["gcPhone:twitter_changePassword"] = 0
RegisterServerEvent('gcPhone:twitter_changePassword')
AddEventHandler('gcPhone:twitter_changePassword', function(username, password, newPassword)
	local source = tonumber(source)
	GetUser(source, username, password, function (user)
		if not user then
			TwitterShowError(source, 'Twitter Info', 'APP_TWITTER_NOTIF_NEW_PASSWORD_ERROR')
		else
			QueryCounter["gcPhone:twitter_changePassword"] = QueryCounter["gcPhone:twitter_changePassword"] + 1
			MySQL.Async.execute("UPDATE `twitter_accounts` SET `password`= @newPassword WHERE twitter_accounts.username = @username", {
				['@username'] = username,
				['@newPassword'] = GetPasswordHash(newPassword)
			}, function (result)
				if (result == 1) then
					TriggerClientEvent('gcPhone:twitter_setAccount', source, username, newPassword, user.authorIcon)
					TwitterShowSuccess(source, 'Twitter Info', 'APP_TWITTER_NOTIF_NEW_PASSWORD_SUCCESS')
				else
					TwitterShowError(source, 'Twitter Info', 'APP_TWITTER_NOTIF_NEW_PASSWORD_ERROR')
				end
			end)
		end
	end)
end)


RegisterServerEvent('gcPhone:twitter_createAccount')
AddEventHandler('gcPhone:twitter_createAccount', function(username, password, avatarUrl)
	local source = tonumber(source)
	if not avatarUrl then
		avatarUrl = nil
	end
	if string.isNullOrWhitespace(username) or string.isNullOrWhitespace(password) then
		TwitterShowError(source, 'Twitter Info', 'APP_TWITTER_NOTIF_ACCOUNT_CREATE_ERROR')
		return
	end
	TwitterCreateAccount(username, password, avatarUrl, function (id)
		if (id ~= 0) then
			TriggerClientEvent('gcPhone:twitter_setAccount', source, username, password, avatarUrl)
			TwitterShowSuccess(source, 'Twitter Info', 'APP_TWITTER_NOTIF_ACCOUNT_CREATE_SUCCESS')
		else
			TwitterShowError(source, 'Twitter Info', 'APP_TWITTER_NOTIF_ACCOUNT_CREATE_ERROR')
		end
	end)
end)

RegisterServerEvent('gcPhone:twitter_getTweets')
AddEventHandler('gcPhone:twitter_getTweets', function(username, password)
	local source = tonumber(source)
	if not string.isNullOrWhitespace(username) and not string.isNullOrWhitespace(password) then
		GetUser(source, username, password, function (user)
			local accountId = user and user.id
			TwitterGetTweets(accountId, function (tweets)
				TriggerClientEvent('gcPhone:twitter_getTweets', source, tweets)
			end)
		end)
	else
		TwitterGetTweets(nil, function (tweets)
			TriggerClientEvent('gcPhone:twitter_getTweets', source, tweets)
		end)
	end
end)

RegisterServerEvent('gcPhone:twitter_getFavoriteTweets')
AddEventHandler('gcPhone:twitter_getFavoriteTweets', function(username, password)
	local source = tonumber(source)
	if not string.isNullOrWhitespace(username) and not string.isNullOrWhitespace(password) then
		GetUser(source, username, password, function (user)
			local accountId = user and user.id
			TwitterGetFavotireTweets(accountId, function (tweets)
				TriggerClientEvent('gcPhone:twitter_getFavoriteTweets', source, tweets)
			end)
		end)
	else
		TwitterGetFavotireTweets(nil, function (tweets)
			TriggerClientEvent('gcPhone:twitter_getFavoriteTweets', source, tweets)
		end)
	end
end)

RegisterServerEvent('gcPhone:twitter_postTweets')
AddEventHandler('gcPhone:twitter_postTweets', function(username, password, message, key)
	local source = source
	if not message or not username or not password then
		return
	end

	if key ~= `gcPhone:twitter_postTweets` then
		TriggerEvent("AntiCheese:KeyFlag", source, { hook = "gcPhone:twitter_postTweets", key = key, resource = GetCurrentResourceName() })
		return
	end

	local source = tonumber(source)
	local srcIdentifier = getPlayerID(source)
	TwitterPostTweet(username, password, message, source, srcIdentifier)
end)

RegisterServerEvent('gcPhone:twitter_toogleLikeTweet')
AddEventHandler('gcPhone:twitter_toogleLikeTweet', function(username, password, tweetId)
	local source = tonumber(source)
	TwitterToogleLike(username, password, tweetId, source)
end)

QueryCounter["gcPhone:twitter_setAvatarUrl"] = 0
RegisterServerEvent('gcPhone:twitter_setAvatarUrl')
AddEventHandler('gcPhone:twitter_setAvatarUrl', function(username, password, avatarUrl)
	local source = tonumber(source)
	GetUser(source, username, password, function (user)
		local accountId = user and user.id
		QueryCounter["gcPhone:twitter_setAvatarUrl"] = QueryCounter["gcPhone:twitter_setAvatarUrl"] + 1
		MySQL.Async.execute("UPDATE `twitter_accounts` SET `avatar_url`= @avatarUrl WHERE twitter_accounts.id = @id AND twitter_accounts.username = @username", {
			['id'] = accountId,
			['username'] = username,
			['avatarUrl'] = avatarUrl
		}, function (result)
			if (result == 1) then
				TriggerClientEvent('gcPhone:twitter_setAccount', source, username, password, avatarUrl)
				TwitterShowSuccess(source, 'Twitter Info', 'APP_TWITTER_NOTIF_AVATAR_SUCCESS')
			else
				TwitterShowError(source, 'Twitter Info', 'APP_TWITTER_NOTIF_LOGIN_ERROR')
			end
		end)
	end)
end)


--[[
Discord WebHook
set discord_webhook 'https//....' in config.cfg
--]]
AddEventHandler('gcPhone:twitter_newTweets', function (tweet)
	-- print(json.encode(tweet))
	local discord_webhook = GetConvar('discord_webhook', '')
	if discord_webhook == '' then
		return
	end
	local headers = {
		['Content-Type'] = 'application/json'
	}
	local data = {
		["username"] = tweet.author,
		["embeds"] = {{
			["thumbnail"] = {
				["url"] = tweet.authorIcon
			},
			["color"] = 1942002,
			["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ", tweet.time / 1000 )
		}}
	}
	local isHttp = string.sub(tweet.message, 0, 7) == 'http://' or string.sub(tweet.message, 0, 8) == 'https://'
	local ext = string.sub(tweet.message, -4)
	local isImg = ext == '.png' or ext == '.pjg' or ext == '.gif' or string.sub(tweet.message, -5) == '.jpeg'
	if (isHttp and isImg) and true then
		data['embeds'][1]['image'] = { ['url'] = tweet.message }
	else
		data['embeds'][1]['description'] = tweet.message
	end
	PerformHttpRequest(discord_webhook, function(err, text, headers) end, 'POST', json.encode(data), headers)
end)