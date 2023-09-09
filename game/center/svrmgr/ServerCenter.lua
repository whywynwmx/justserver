local server = require "server"
local skynet = require "skynet"
local lua_app = require "lua_app"

local ServerCenter = ()

function ServerCenter:Init()
	self.svrlist = {}			--[name][index] = src
	self.srcToInfo = {}			--src = {name, index, time}
    self.checktimer = lua_app.add_update_timer(30000, self, "CheckHeartBeat")
end

function ServerCenter:Release()
    if self.checktimer then
		lua_app.del_local_timer(self.checktimer)
		self.checktimer = nil
	end
end

function ServerCenter:ServerRegist(src, name, index)
	skynet.error("~~~~~~~~~~~~ServerCenter:ServerRegist", src, name, index)

	if not self.svrlist[name] then
		self.svrlist[name] = {}
	end
	local isreconnect, info, dsrc = false
	if self.svrlist[name][index] then
		dsrc = self.svrlist[name][index]
		info = self.srcToInfo[dsrc]
		if info.name ~= name or info.index ~= index then
			skynet.error("ServerCenter:ServerRegist:: exist error name, index", name, index, src, info.name, info.index, dsrc)
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
			skynet.error("ServerCenter:ServerRegist:: exist error src", name, index, src, info.name, info.index, dsrc)
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
		time = lua_app.now(),
	}

	if name == "logic" then
		self:Send(src, "UpdateConnList", server.nodeCenter:GetNodeToAddr())
--		server.dispatchCenter:ToAddMatch(nil, nil)			--后台登录服， record，plat

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

server.SetCenter(ServerCenter, "serverCenter")
return ServerCenter
