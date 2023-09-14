local skynet = require "skynet"
local server = require "server"

local NodeCenter = {}

function NodeCenter:Init()
	self.svrlist = {}			--[name][node] = src
	self.srcToInfo = {}			--src = {name, node, addr, time}
	self.checktimer = skynet.add_update_timer(30 * 100, self, "CheckHeartBeat")
end

function NodeCenter:Release()
	if self.checktimer then
		skynet.remove_timeout(self.checktimer)
		self.checktimer = nil
	end
end

function NodeCenter:Send(name, node, ...)
	local srcs = self.svrlist[name]
	if not srcs or not srcs[node] then
		skynet.log_error("NodeCenter:Send:: no node:", name, node, ...)
		return
	end
	skynet.send(srcs[node], lua_app.MSG_LUA, ...)
end

function NodeCenter:Call(name, node, ...)
	local srcs = self.svrlist[name]
	if not srcs or not srcs[node] then
		lua_app.log_error("NodeCenter:Call:: no node:", name, node, ...)
		return
	end
	return lua_app.supercall(30000, srcs[node], lua_app.MSG_LUA, ...)
end

function NodeCenter:Broadcast(...)
	for src, _ in pairs(self.srcToInfo) do
		lua_app.send(src, lua_app.MSG_LUA, ...)
	end
end

function NodeCenter:BroadcastEscape(escapsrc, ...)
	for src, _ in pairs(self.srcToInfo) do
		if src ~= escapsrc then
			lua_app.send(src, lua_app.MSG_LUA, ...)
		end
	end
end

function NodeCenter:NodeRegist(src, name, node, addr)
	skynet.log_info("~~~~~~~NodeCenter:NodeRegist", src, name, node, addr)
	local isreconnect, info, dsrc = false
	if not self.svrlist[name] then
		self.svrlist[name] = {}
	end
	if self.svrlist[name][node] then
		dsrc = self.svrlist[name][node]
		info = self.srcToInfo[dsrc]
		if info.node ~= node then
			skynet.log_error("NodeCenter:NodeRegist:: exist error node", name, node, src, info.node, dsrc)
			return
		end
		self.srcToInfo[dsrc] = nil
		self.svrlist[name][node] = nil
		isreconnect = true
	end
	if self.srcToInfo[src] then
		info = self.srcToInfo[src]
		dsrc = self.svrlist[info.name][info.node]
		if dsrc ~= src then
			skynet.log_error("NodeCenter:NodeRegist:: exist error src", name, node, src, info.node, dsrc)
			return
		end
		self.svrlist[info.name][info.node] = nil
		self.srcToInfo[src] = nil
		isreconnect = true
	end
	self.svrlist[name][node] = src
	self.srcToInfo[src] = {
		name = name,
		node = node,
		addr = addr,
		time = skynet.timeI(),
	}
	server.nodeDispatch:NodeConnect(name, node)
	self:BroadcastConnList(name, src)

	lua_app.send(src, lua_app.MSG_LUA, "UpdateServerSource", server.serverCenter.svrlist)
	
    if isreconnect then
		skynet.log_info("NodeCenter::reconnect", addr, name, node, src, info.node, dsrc)
	else
		skynet.log_info("NodeCenter::connect", addr, name, node, src)
	end
end

function NodeCenter:NodeDisconnect(src, reason)
	local info = self.srcToInfo[src]
	if not info then return end
	self.svrlist[info.name][info.node] = nil
	self.srcToInfo[src] = nil
	skynet.log_info("NodeDisconnect::", reason, info.name, info.node, src)
end

function NodeCenter:HeartBeat(src, name, node, addr)
	local info = self.srcToInfo[src]
	if not info or info.name ~= name or info.node ~= node or info.addr ~= addr then return false end
	info.time = skynet.timeI()
	return true
end

function NodeCenter:CheckHeartBeat()
	self.checktimer = skynet.add_update_timer(30 * 100, self, "CheckHeartBeat")
	local outtime = skynet.timeI() - 60
	local removes = {}
	for src, info in pairs(self.srcToInfo) do
		if info.time < outtime then
			removes[src] = info
		end
	end
	for src, _ in pairs(removes) do
		self:NodeDisconnect(src, "timeout")
	end
	local notconnlist = {}
	for name, info in pairs(server.nodeDispatch.nodelist) do
		local nname = server.serverConfig.svrNameToNodeName[name]
		for node, _ in pairs(info) do
			if not self.svrlist[nname] or not self.svrlist[nname][node] then
				if not notconnlist[nname] then
					notconnlist[nname] = {}
				end
				if not notconnlist[nname][node] then
					notconnlist[nname][node] = true
					if server.nodeDispatch.nodes[nname] then
						skynet.log_info("NodeCenter:CheckHeartBeat:: error! node not connect!", nname, node)
					end
				end
			end
		end
	end
end

function NodeCenter:BroadcastConnList(name, newsrc)
	local nodeToAddr = self:GetNodeToAddr(name)
	server.serverCenter:BroadcastName("logic", "UpdateConnList", nodeToAddr)
	self:BroadcastEscape(newsrc, "UpdateConnList", nodeToAddr)
	lua_app.send(newsrc, lua_app.MSG_LUA, "UpdateConnList", self:GetNodeToAddr())
end

function NodeCenter:GetNodeToAddr(name)
	local nodeToAddr = {}
	for _, info in pairs(self.srcToInfo) do
		if not name or name == info.name then
			if not nodeToAddr[info.name] then
				nodeToAddr[info.name] = {}
			end
			nodeToAddr[info.name][info.node] = info.addr
		end
	end
	return nodeToAddr
end


function server.NodeRegist(src, ...)
	server.nodeCenter:NodeRegist(src, ...)
end

function server.NodeDisconnect(src)
	server.nodeCenter:NodeDisconnect(src, "normal")
end

function server.NodeHeartBeat(src, ...)
	server.nodeCenter:HeartBeat(src, ...)
end

server.SetCenter(NodeCenter, "nodeCenter")
return NodeCenter
