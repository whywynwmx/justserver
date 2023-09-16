local server = require "server"
local skynet = require "skynet"
local socket = require "skynet.socket"
local lua_util = require "lua_util"


local CMD = {}
local client_fd

server.request_sessions = {

}

server.HotFix = function()
    
end

local function _response(session, ..)
	local msg, sz = skynet.pack("RESPONSE", session, ...)
	local str = skynet.tostring(msg, sz)
	
	local package = string.pack(">s2", str)
	socket.send(fd, package)
end

local function _request(session, ...)
	local msg, sz = skynet.pack("REQUEST", session, ...)
	local str = skynet.tostring(msg, sz)
	
	local package = string.pack(">s2", str)
	socket.send(fd, package)
end

local function _on_response(session, ...)
	if not session or session <= 0 then
		return
	end

	local t = server.request_sessions[session]
	if not t or not t.co then
		skynet.log_warn("no response data:", session, ...)
		return
	end

	t.ret = table.pack(...)
	skynet.wakeup(t.co)
end

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = skynet.unpack,
	dispatch = function (fd, _, type, request_session, ...)
		local ret
	    if server[type] then
            ret = server[type](...)
        else
			if type == "REQUEST" then
				_response(request_session, skynet.send(server.centerSource, "lua", ...))
			elseif type == "RESPONSE" then
				_on_response(request_session, ...)
			else
				skynet.log_error("invalid socket request:", type, ...)
			end
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

function CMD.CallRequest(...)
	local _session = (server.request_session or 0) + 1
	if _session < 0 then
		_session = 1
	end
	server.request_session = _session
	_request(_session, ...)
	server.request_sessions[_session] = {
		co = coroutine.running(),
	}
	skynet.wait()
	if server.request_sessions[_session] then
		skynet.log_error("bad result for request:", _session, type)
	end
	local ret = server.request_sessions[_session].ret
	return ret
end
function CMD.SendRequest(...)
	_request(-1, ...)
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		skynet.error("agenet lua", command, ...)
		-- skynet.trace()
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)
end)
