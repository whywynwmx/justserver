local server = require "server"
local lua_log = require "lua_log"
local skynet = require "skynet"
local oo = require "class"
require "modules.Event"

local _EventFunc = {
	Main			= { server.event.main },
	Init			= { server.event.init },
	ServerOpen		= { server.event.open },
	HotFix			= { server.event.hotfix },
	Release			= { server.event.release, true },
	onBeforeLogin	= { server.event.beforelogin },
	onLogin			= { server.event.login },
	onInitClient	= { server.event.clientinit },
	onBeforeLogout	= { server.event.beforelogout, true },
	onLogout		= { server.event.logout, true },
	onDayTimer		= { server.event.daytimer },
	onHalfHour		= { server.event.halfhourtimer },
	onLeaveMap		= { server.event.leavemap },
	onEnterMap		= { server.event.entermap },
	ResetServer		= { server.event.resetserver },
}

function server.UpdateCenter(ct, name)
	if not server[name] then
		skynet.log_info("server.UpdateCenter not exist", name)
		return
	end
	for funcname, v in pairs(_EventFunc) do
		if ct[funcname] and not server.isreglocalfunc(v[1], name, funcname) then
			skynet.log_info("server.UpdateCenter", v[1], v[2], name, funcname)
			server.reglocalfunc(v[1], name, funcname, v[2])
		end
	end
end

function server.SetCenter(ct, name)
	if server[name] then
		server.UpdateCenter(ct, name)
		-- skynet.log_info("server.SetCenter exist", name)
		return
	end
	server[name] = ct
	for funcname, v in pairs(_EventFunc) do
		if server[name][funcname] then
			-- print("server.SetCenter", v[1], v[2], name, funcname)
			server.reglocalfunc(v[1], name, funcname, v[2])
		end
	end
end

function server.NewCenter(ct, name)
	if server[name] then
		server.UpdateCenter(ct, name)
		-- skynet.log_info("server.NewCenter exist", name)
		return
	end
	server[name] = ct.new()
	for funcname, v in pairs(_EventFunc) do
		if server[name][funcname] then
			-- print("server.NewCenter", v[1], v[2], name, funcname)
			server.reglocalfunc(v[1], name, funcname, v[2])
		end
	end
end

server.__unique_id = server.__unique_id or 0
function server.GetUID()
	server.__unique_id = server.__unique_id + 1
	return server.__unique_id
end
---------------------- 调用模块函数 ---------------------------
function server.SendRunModFun(src, modname, funcname, ...)
	local mod = server[modname]
	if mod == nil then
		skynet.log_error("call invalid mod", modname)
		return
	end

	if mod[funcname] == nil then
		skynet.log_error("call invalid function", funcname)
		return
	end

	mod[funcname](mod, ...)
end
function server.CallRunModFun(src, modname, funcname, ...)
	local mod = server[modname]
	if mod == nil then
		skynet.log_error("call invalid mod", modname)
	elseif mod[funcname] == nil then
		skynet.log_error("call invalid function", funcname)
	else
		return mod[funcname](mod, ...)
	end
end