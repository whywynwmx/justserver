local skynet = require "skynet.manager"
local server = require "server"

local socket = require "client.socket"

local cluster = require "skynet.cluster"

local fd

local CMD = {}
CMD.test = function(...)
	skynet.error("~~~~~~~~~debug node: test")
end

function send_request(type, ...)
    local msg, sz = skynet.pack(type, ...)
    local str = skynet.tostring(msg, sz)
    
    local package = string.pack(">s2", str)
	socket.send(fd, package)
end

function clientloop()
    while true do
        -- send_package("heartbeat")
        local t = cluster.call("center", ".center", "Test")
        print("~~~~~~~~~~~~~debug node:", t)
        skynet.sleep(2000)
    end
end

skynet.start(function()
	skynet.register(".debug_server_node")

	skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            log.error("Invalid cmd. cmd:", cmd)
        end
    end)

    -- fd = assert(socket.connect("127.0.0.1", 8888))
    -- send_request("justtest", {t=333}, "endshit")
    skynet.fork(clientloop)
end)
