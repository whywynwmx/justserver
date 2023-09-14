local server = require "server"
local skynet = require "skynet"
local socket = require "skynet.socket"
local lua_util = require "lua_util"


local CMD = {}
local client_fd

server.HotFix = function()
    
end

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = skynet.unpack,
	dispatch = function (fd, _, type, ...)
		local ret
	    if server[type] then
            ret = server[type](...)
        else
			ret = skynet.send(server.centerSource, "lua", type, ...)
            -- skynet.error("unknown message type: ", table.inspectex(type, ...))
        end

		skynet.ignoreret()	-- session is fd, don't call skynet.ret
	end
}

function CMD.start(conf)
	local fd = conf.client
	local gate = conf.gate
	server.centerSource = conf.watchdog

	client_fd = fd
	skynet.call(gate, "lua", "forward", fd)	
end

function CMD.disconnect()
	-- todo: do something before exit
	skynet.exit()
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		skynet.error("agenet lua", command, ...)
		-- skynet.trace()
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)
end)
