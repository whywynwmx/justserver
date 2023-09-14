local server = require "server"
local skynet = require "skynet"

local ServerCenter = {}

function ServerCenter:Init()
	self.svrlist = {}			--[name][index] = src
	self.srcToInfo = {}			--src = {name, index, time}
    self.checktimer = skynet.add_update_timer(30 * 100, self, "CheckHeartBeat")	--每30s
end

function ServerCenter:Release()
    if self.checktimer then
		skynet.remove_timeout(self.checktimer)
		self.checktimer = nil
	end
end

function ServerCenter:HotFix()
	skynet.log_info("~~~~~~~~~~~~ServerCenter:HotFix")
end

function ServerCenter:ServerRegist(src, name, index)
	skynet.log_info("~~~~~~~~~~~~ServerCenter:ServerRegist", src, name, index)

	if not self.svrlist[name] then
		self.svrlist[name] = {}
	end
	local isreconnect, info, dsrc = false
	if self.svrlist[name][index] then
		dsrc = self.svrlist[name][index]
		info = self.srcToInfo[dsrc]
		if info.name ~= name or info.index ~= index then
			skynet.log_error("ServerCenter:ServerRegist:: exist error name, index", name, index, src, info.name, info.index, dsrc)
			return
		end
		self.srcToInfo[dsrc] = nil
		self.svrlist[name][index] = nil
		isreconnect = true
	end
	if self.srcToInfo[src] then
		info = self.srcToInfo[src]
		dsrc = self.svrlist[info.name][info.index]
		if dsrc ~= src then
			skynet.log_error("ServerCenter:ServerRegist:: exist error src", name, index, src, info.name, info.index, dsrc)
			return
		end
		self.svrlist[info.name][info.index] = nil
		self.srcToInfo[src] = nil
		isreconnect = true
	end
	server.dispatchCenter:SendDtbinfo(src)
	self:Broadcast("SetServerSource", src, name, index)
	server.nodeCenter:Broadcast("SetServerSource", src, name, index)
	self.svrlist[name][index] = src
	self.srcToInfo[src] = {
		name = name,
		index = index,
		time = skynet.timeI(),
	}

	if name == "logic" then
		self:Send(src, "UpdateConnList", server.nodeCenter:GetNodeToAddr())

		--尝试分配Cross服务器
		server.dispatchCenter:AddOneMatch(index)
	end
	self:Send(src, "UpdateServerSource", self.svrlist)
	if isreconnect then
		lua_app.log_info("ServerRegist:: reconnect", name, index, src, info.name, info.index, dsrc)
	else
		lua_app.log_info("ServerRegist:: connect", name, index, src)
	end
end

function ServerCenter:ServerDisconnect(src, reason)
	local info = self.srcToInfo[src]
	if not info then return end
	self.svrlist[info.name][info.index] = nil
	self.srcToInfo[src] = nil
	self:Broadcast("SetServerSource", nil, info.name, info.index, reason)
	server.nodeCenter:Broadcast("SetServerSource", nil, info.name, info.index, reason)
	skynet.log_info("ServerDisconnect::", reason, info.name, info.index, src)
end

function ServerCenter:HeartBeat(src, name, index)
	local info = self.srcToInfo[src]
	if not info or info.name ~= name or info.index ~= index then return false end
	info.time = skynet.timeI()
	return true
end

function ServerCenter:CheckHeartBeat()
	self.checktimer = skynet.add_update_timer(30000, self, "CheckHeartBeat")
	local outtime = skynet.timeI() - 60
	local removes = {}
	for src, info in pairs(self.srcToInfo) do
		if info.time < outtime then
			removes[src] = info
		end
	end
	for src, _ in pairs(removes) do
		self:ServerDisconnect(src, "timeout")
	end
end

function server.ServerRegist(src, name, index)
	server.serverCenter:ServerRegist(src, name, index)
end

function server.ServerDisconnect(src)
	server.serverCenter:ServerDisconnect(src, "normal")
end


function server.SendRunModFun(src, modname, funcname, ...)
	local mod = server[modname]
	mod[funcname](mod, ...)
end
function server.CallRunModFun(src, modname, funcname, ...)
	local mod = server[modname]
	mod[funcname](mod, ...)
end


server.SetCenter(ServerCenter, "serverCenter")
return ServerCenter
