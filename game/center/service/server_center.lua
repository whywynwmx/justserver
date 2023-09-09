local skynet = require "skynet.manager"
local server = require "server"
local lua_util = require "lua_util"

local CMD = {}
local SOCKET = {}
local conf
local gate
local agent = {}

function SOCKET.open(fd, addr)
	skynet.error("New client from : " .. addr)
	agent[fd] = skynet.newservice(conf.agent or "service/server_agent")
	skynet.call(agent[fd], "lua", "start", { gate = gate, client = fd, watchdog = skynet.self() })
end

local function close_agent(fd)
	local a = agent[fd]
	agent[fd] = nil
	if a then
		skynet.call(gate, "lua", "kick", fd)
		-- disconnect never return
		skynet.send(a, "lua", "disconnect")
	end
end

function SOCKET.close(fd)
	print("socket close",fd)
	close_agent(fd)
end

function SOCKET.error(fd, msg)
	print("socket error",fd, msg)
	close_agent(fd)
end

function SOCKET.warning(fd, size)
	-- size K bytes havn't send out in fd
	print("socket warning", fd, size)
end

function SOCKET.data(fd, msg)
	
end

function server.start(_conf)
    conf = _conf
    skynet.error("center listen on " .. conf.port)
	return skynet.call(gate, "lua", "open" , conf)
end

function server.close(fd)
	close_agent(fd)
end

skynet.start(function()
    skynet.register(".center")

	skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
		if cmd == "socket" then
			local f = SOCKET[subcmd]
			f(...)
			-- socket api don't need return
		else
			if server[cmd] then
				skynet.ret(skynet.pack(server[cmd](subcmd, ...)))
			else
				skynet.error("no command:", lua_util.inspectex(cmd, subcmd, ...))
				skynet.ret()
			end
		end
	end)
    
	gate = skynet.newservice("gate")
end)
