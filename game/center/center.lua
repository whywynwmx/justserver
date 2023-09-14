local server = require "server"
local skynet = require "skynet.manager"

server.name = "center"
local platformid = ...
server.index = 0
server.platformid = tonumber(platformid)
server.wholename = server.GetWholeName(server.name, server.index, server.platformid)
skynet.error("~~~center", server.name, server.index, server.platformid, server.wholename)
math.randomseed(tostring(os.time()):reverse():sub(1, 7))

server.centerSource = nil

server.Start = function(source, ...)
    skynet.error("~~~center Start", source, ...)
end


server.HotFix = function(source, ...)
    skynet.error("~~~center HotFix", source, server.centerSource, ...)
    local cache = require "skynet.codecache"
    cache.clear()

    skynet.call(server.centerSource, "lua", "HotFix")
end

-- local t1, t2 = skynet.pack(1, {hh=4}, 5)
-- skynet.error("~~pack:", t1, t2)
-- skynet.error("~~unpack", skynet.unpack(t1, t2))

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, ...)
        if not server[cmd] then
            skynet.error("no cmd:", cmd, ...)
            return
        end
        skynet.ret(server[cmd](source, ...))
    end)

    server.centerSource = skynet.newservice("service/server_center")
	local addr,port = skynet.call(server.centerSource, "lua", "Start", {
		port = 8888,
		maxclient = max_client,
		nodelay = true,
	})
end)
