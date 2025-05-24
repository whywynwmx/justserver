local skynet = require "skynet.manager"
local cluster = require "skynet.cluster"
local server = require "server" 

require "config.psproto"

local function startServers()
	local addr,port = skynet.call(server.loginService, "lua", "start", {
        zone_id = skynet.getenv("zone_id") or 1,
        port = tonumber(skynet.getenv("port")),
        maxclient = skynet.getenv("maxclient") or 10000,
	})
end

skynet.start(function()
    skynet.error("game Server start")

    if not skynet.getenv "daemon" then
        local console = skynet.newservice("console")
    end
    skynet.newservice("service/debug_consolec", skynet.getenv("debug_port"))

    server.loginService = skynet.uniqueservice("gate/wsgate")
    -- server.logicService = skynet.newservice("logic/logic", 1)
    -- server.worldService = skynet.newservice("world/world", 1)

    --start center
    -- server.Start()

    cluster.open("game_1")

    startServers()

    skynet.exit()
end)