local server = require "server"
server.name = "mysql"
local platformid, include = ...
server.index = 0
server.platformid = tonumber(platformid)
server.wholename = server.GetWholeName(server.name, server.index, server.platformid)

math.randomseed(tostring(os.time()):reverse():sub(1, 7))
local skynet = require "skynet.manager"

require "mysql.include"

local count = 0
function server.Start(source, cfg)
	count = count + 1
	if count <= 1 then
		server.cfgCenter = cfg
		server.onevent(server.event.init, cfg)
		skynet.log_info(server.wholename, "Start")
	end
	return true
end

local hotfixcount = 0
function server.HotFix()
	hotfixcount = hotfixcount + 1
	if hotfixcount % count ~= 0 then return end

	package.loaded["mysql.include"] = nil
	require "mysql.include"
	server.onevent(server.event.hotfix)
	skynet.log_info(server.wholename, "HotFix")
end

function server.Stop()
	count = count - 1
	if count <= 0 then
		server.onevent(server.event.release)
		skynet.log_info(server.wholename, "Stop")
	end
	skynet.ret(true)
end

local function collect()
	local collect_tick = 0
	while true do
		skynet.sleep(100)	-- sleep 1s
		if collect_tick <= 0 then
			collect_tick = 888	-- reset tick count to 600 sec
			-- local startMem = collectgarbage("count")
			if server.mysqlPool then
				server.mysqlPool:CheckClearCache(9999)
			end
			collectgarbage()
			-- local overMem = collectgarbage("count")
			-- skynet.log_info("collect memory:", startMem, overMem)
		else
			collect_tick = collect_tick - 1
		end
	end
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, ...)
		skynet.log_info(server.wholename, "command:", cmd, ...)
		if not server[cmd] then
			skynet.log_error("no command:", cmd,...)
			return
		end
		skynet.ret(skynet.pack(server[cmd](source,...)))
    end)

	skynet.register(server.wholename)
	skynet.fork(collect)
end)
