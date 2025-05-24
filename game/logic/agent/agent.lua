local skynet = require "skynet"
local socket = require "skynet.socket"
local websocket = require "http.websocket"
local sproto = require "sproto"
local sprotoloader = require "sprotoloader"

local server = require "server"
local lua_util = require "lua_util"

require "agent.login.login"

server.wholename = "agent_"

-- local REQUEST = {}
local client_fd
local player_uid

-- function REQUEST:get()
-- 	print("get", self.what)
-- 	local r = skynet.call("SIMPLEDB", "lua", "get", self.what)
-- 	return { result = r }
-- end

-- function REQUEST:set()
-- 	print("set", self.what, self.value)
-- 	local r = skynet.call("SIMPLEDB", "lua", "set", self.what, self.value)
-- end

-- function REQUEST:handshake()
-- 	return { msg = "Welcome to skynet, I will send heartbeat every 5 sec." }
-- end

-- function REQUEST:quit()
-- 	skynet.call(".wsgate", "lua", "close", client_fd)
-- end

local function request(name, args, response)
	-- local f = assert(REQUEST[name])
	-- local r = f(args)
	-- if response then
	-- 	return response(r)
	-- end

    if server[name] == nil then
        if name ~= "cs_send_heart_beat" then
            skynet.log_error("logic func name not exist:", name)
        end
        return
    end

    local startMem = collectgarbage("count")
    local r = server[name](client_fd, args, response)
    local overMem = collectgarbage("count")
    if overMem - startMem > 100 then
        skynet.log_info("Cost Mem Too Large", name, overMem - startMem)
    end
    if response and r then
        local res = response(r)
        -- local loginer = server.loginerCenter:GetLoginer(id)
        -- server.SendClient(loginer, ws.pack_binary(res))
        return res
    end
end

local function send_package(pack)
    skynet.log_info("send_package", lua_util.inspectex(client_fd, pack))

	-- local package = string.pack(">s2", pack)
	-- socket.write(fd, package)
    -- websocket.write(client_fd, pack, "binary")
    skynet.send(".wsgate", "lua", "push", player_uid, pack)
end

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = function (msg, sz)
		return server.protoHoster:dispatch(msg, sz)
	end,
	dispatch = function (fd, _, type, ...)
		assert(fd == client_fd)	-- You can use fd to reply message
		skynet.ignoreret()	-- session is fd, don't call skynet.ret
		skynet.trace()

        skynet.log_info("agent dispatch", lua_util.inspectex(type, ...))

		if type == "REQUEST" then
			local ok, result  = pcall(request, ...)
			if ok then
				if result then
					send_package(result)
				end
			else
				skynet.error(result)
			end
		else
			assert(type == "RESPONSE")
			error "This example doesn't support request client"
		end
	end
}

local function _RegSprotoSender()
    local sprotoloader = require "sprotoloader"
    local host = sprotoloader.load(1):host("package")
    local send = host:attach(sprotoloader.load(2))
    server.protoSender = send
    server.protoHoster = host
end

function server.start(conf)
    skynet.log_info("agent start", lua_util.inspectex(conf))

	local fd = conf.fd

	client_fd = fd
    player_uid = conf.uid

    server.wholename = "agent_" .. player_uid
    return true
end

function server.disconnect()
    skynet.log_info("disconnet")
	-- todo: do something before exit
	skynet.exit()
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		skynet.trace()
		local f = server[command]
		skynet.ret(skynet.pack(f(...)))
	end)

    _RegSprotoSender()
end)
