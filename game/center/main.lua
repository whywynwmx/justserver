local skynet = require "skynet.manager"
local server = require "server"

server.getenv = skynet.getenv

local platid = skynet.getenv("platid") or 0

local CMD = {}
CMD.HotFix = function(...)
	skynet.error("~~~~~~~~~to HotFix")
	server.HotFix(...)
end


function server.Start()
	skynet.call(server.centerSource, "lua", "Start")
end

function server.HotFix(...)
	skynet.call(server.centerSource, "lua", "HotFix", ...)
end

skynet.start(function()
	skynet.error("center Server start")
	skynet.register(".main")

	if not skynet.getenv "daemon" then
		local console = skynet.newservice("console")
	end
	skynet.newservice("service/debug_consolec", skynet.getenv("debug_port"))

	-- local watchdog = skynet.newservice("watchdog")
	-- local addr,port = skynet.call(watchdog, "lua", "start", {
	-- 	port = 8888,
	-- 	maxclient = max_client,
	-- 	nodelay = true,
	-- })
	-- skynet.error("Watchdog listen on " .. addr .. ":" .. port)
	-- skynet.exit()

	server.centerSource = skynet.newservice("center/center", platid)

	skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            log.error("Invalid cmd. cmd:", cmd)
        end
    end)

	--start center
	server.Start()
end)
