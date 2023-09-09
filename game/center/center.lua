local server = require "server"
local skynet = require "skynet.manager"

server.name = "center"
local platformid = ...
server.index = 0
server.platformid = tonumber(platformid)
server.wholename = server.GetWholeName(server.name, server.index, server.platformid)
skynet.error("~~~center", server.name, server.index, server.platformid, server.wholename)
math.randomseed(tostring(os.time()):reverse():sub(1, 7))

--加载模块代码
-- require "include"

server.Start = function(source, ...)
    skynet.error("~~~center Start", source, ...)
end


server.HotFix = function(source, ...)
    skynet.error("~~~center HotFix", source, ...)
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

    local watchdog = skynet.newservice("service/server_center")
	local addr,port = skynet.call(watchdog, "lua", "start", {
		port = 8888,
		maxclient = max_client,
		nodelay = true,
	})
end)
