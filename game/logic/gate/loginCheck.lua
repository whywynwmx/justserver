local skynet = require "skynet"
require "skynet.manager"
require "lua_skynetex"
local server = require "server"
local httpc = require "http.httpc"

local function checkAccessTokenInGlobal(accountname, token, gameId, opid, serverid, cb)
	local ymaddr = server.cfgCenter.global.ywaddr or "10.0.0.65:9091"
	local host = ymaddr
	local gserverid = serverid 
	--force convert to global serverid...
	if gserverid < 10000 then	
		gserverid = gameId * 10000 + serverid
	end
	local url = string.format("http://%s/api/global_api/server_verify_token?token=%s&user_id=%s&game_id=%s&op_id=%s&zone_id=%s", 
						ymaddr, token, accountname, gameId, opid, gserverid)
	skynet.log_info("checkAccessTokenInGlobal: url=" .. url)	
    httpc.timeout = 1000	-- set timeout 10 second
    skynet.fork(function ()
        local code, body = httpc.get(host, url)
        code = code or -1
        body = body or ""
        skynet.log_info("LoginCheck checkAccessTokenInGlobal result: " .. url .. ": ret=" .. code .. " body = " .. (body or ""))
        if code == 200 then
            if cb then
                cb(true, body)
            end
        else
            if cb then
                cb(false)
            end
        end
    end)
	skynet.log_info("checkAccessTokenInGlobal finishd")
end

local function onCheckAccountResult(loginResult, uid, loginer, account, serverid, ip, channelId, gm_level, token, lid, osid, third_sdk_user, sdk_ban_time, rdata, deviceId)
	skynet.log_info("onCheckAccountResult: ", loginResult, uid, loginer, account, serverid, ip, channelId, gm_level, token, lid, osid, third_sdk_user, sdk_ban_time, rdata)
	if not loginResult then
		-- server.sendLoginer(loginer, "checkAccountRet", { result = uid })
		return { result = uid }
	end
	-- local loginning = server.loginerCenter:GetLogining(account)
	-- if loginning then
	-- 	if loginning == loginer then
	-- 		skynet.log_info("account:", account, "is loginning")
	-- 		return { result = 5 }
	-- 	else
	-- 		server.CloseSocket(loginning.socket)
	-- 	end
	-- end
	loginer.account = account
	loginer.serverid = serverid
	loginer.gm_level = gm_level
	loginer.ip = ip or loginer.ip
	loginer.uid = uid
	loginer.channelId = channelId
	loginer.lid = lid
	loginer.osid = osid
	loginer.third_sdk_user = third_sdk_user
	loginer.sdk_ban_time = sdk_ban_time
	loginer.referuser = rdata.cpid
	loginer.referserver = rdata.cpserver
	loginer.referdbid = rdata.cpdbid
	loginer.shareData = rdata
	loginer.deviceId = deviceId

	-- server.loginerCenter:AddLogining(account, loginer)
	-- server.loginerCenter:SetToken(loginer.socket, token .. "," .. serverid .. "," .. (lid or ""))

	return { result = 0 }
end

function server.checkAccount(id, msg)
    if true then
        return { result = 0, uid = 1 }
    end

	msg.serverid = msg.serverid % 10000
	skynet.log_info("LoginCheck checkAccount:", id, msg.token, msg.serverid)
	
	local token = msg.token
	if server.environment ~= "" then
		msg.serverid = server.serverid
		msg.lid = ""
	end

	local serverid = msg.serverid
	if not serverid then
		return { result = 4 }
	end

	local loginResult, uid, account, channelId, gm_level, ip, third_sdk_user, sdk_ban_time

    skynet.log_info("environment:", server.environment)

    if server.environment ~= "" then
        skynet.log_info("whitename:", server.cfgCenter.environment.whitename)
        if server.cfgCenter.environment.whitename then
            if not server.whitename:Check(token) then
                return {result = 2}
            end
        end
        
        account = token
        loginResult = (account and account ~= "" or false)
        if server.environment == "debug" then
            gm_level = 100
        else
            gm_level = 0
        end
        uid = loginResult and token or 2
        channelId = server.environment
        channelId = msg.opid
    else		-- 平台验证
        skynet.log_info(server.getTxt(62) .. id)

        local asyncresult = {result = 20}
        checkAccessTokenInGlobal(msg.lid, msg.token, msg.gameid, msg.opid, serverid, function(ret, data)
            if ret then
                skynet.log_info(server.getTxt(63) .. data)

                local data = json.decode(data)
                if data and data.code == 1 then
                    local gmLevel = 10
                    
                    if data.msg then
                        third_sdk_user = data.zsy_userid	--第三方sdk用户
                        sdk_ban_time = data.bannTime		--sdk禁言时间，-1是不禁言，0是永久禁言
                    end

                    loginResult =  true
                    uid = msg.lid
                    account = msg.lid
                    channelId = msg.opid
                    gm_level = gmLevel
                --	ip = ""
                    token = msg.token
                    asyncresult = onCheckAccountResult(loginResult, uid, loginer, account, serverid, ip, channelId, gm_level, token, msg.lid, msg.platformuid, third_sdk_user, sdk_ban_time, rdata, msg.deviceId)

                    local loginer = server.loginerCenter:GetLoginer(id)
                    if not loginer or loginer.protocol == 0 or not loginer.socket or loginer.socket == 0 then
                        return
                    end
                    server.sendToClient(loginer.protocol, loginer.socket, "sc_check_account_result", asyncresult)
                else
                    server.sendToClient(loginer.protocol, loginer.socket, "sc_check_account_result", {result = 20})
                end
            else
                server.sendToClient(loginer.protocol, loginer.socket, "sc_check_account_result", {result = 20})
            end
        end)
        return 

        -- local httppindex = tonumber(string.match(msg.lid or "", "^(.-)_")) or 1
        -- local logininfo, error_code = server.serverCenter:CallOneMod("httpp", httppindex, "loginCenter", "PlayerLogin", token, serverid, msg.lid)
        -- if not logininfo then
        -- 	loginResult, uid = false, error_code
        -- elseif not logininfo.username then
        -- 	loginResult, uid = false, 2
        -- else
        -- 	loginResult, uid, account, channelId, gm_level, ip = true, logininfo.uid, logininfo.username,
        -- 		logininfo.channelId, logininfo.gm_level, logininfo.ip
        -- end
    end

	return onCheckAccountResult(loginResult, uid, loginer, account, serverid, ip, channelId, gm_level, token, msg.lid, msg.platformuid, third_sdk_user, sdk_ban_time, rdata, msg.deviceId)
end