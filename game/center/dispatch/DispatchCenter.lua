local skynet = require "lua_skynetex"
local server = require "server"
local DispatchFunc = require "dispatch.DispatchFunc"
local tbname = "dispatchlist"

local DispatchCenter = {}

function DispatchCenter:Init()
	self.svrdtb = {}		--[name][src] = index	:node index
	self.dtblist = {}
	self.addMatchTimer = {}
	local values = server.mysqlCenter:query(tbname)
	skynet.log_info("------------- DispatchCenter:Init start -------------")
	for _, value in ipairs(values) do
		self:SetSvrdtb(value.name, value.serverid, value.area)
		skynet.log_info("	", value.name, "	", value.serverid, "	", value.area)
	end
	skynet.log_info("============== DispatchCenter:Init end ==============")
end

function DispatchCenter:Release()
end

function DispatchCenter:SetSvrdtb(name, serverid, index)
	if not self.svrdtb[name] then
		self.svrdtb[name] = {}
	end
	if not self.dtblist[name] then
		self.dtblist[name] = {}
	end
	if index then
		assert(type(index) == "number", index .. "(" .. type(index) .. ")")
		local info = self.svrdtb[name][serverid]
		if info and self.dtblist[name][info.index] then
			self.dtblist[name][info.index][serverid] = nil
			if not next(self.dtblist[name][info.index]) then
				self.dtblist[name][info.index] = nil
			end
		end
		if not self.dtblist[name][index] then
			self.dtblist[name][index] = {}
		end
		self.svrdtb[name][serverid] = {
			index = index,
		}
		self.dtblist[name][index][serverid] = true
	else
		local info = self.svrdtb[name][serverid]
		self.svrdtb[name][serverid] = nil
		if info and self.dtblist[name][info.index] then
			self.dtblist[name][info.index][serverid] = nil
			if not next(self.dtblist[name][info.index]) then
				self.dtblist[name][info.index] = nil
			end
		end
	end
end

function DispatchCenter:ClearDtb(name)
	self.svrdtb[name] = {}
	self.dtblist[name] = {}
	server.mysqlCenter:delete(tbname, { name = name })
end

function DispatchCenter:ReInitSvrdtb(svrdtb, isreset)
	skynet.log_info("------------- ReInitSvrdtb start -------------", isreset)
	table.ptable(svrdtb, 5, nil, skynet.log_info)
	local sqldatas = {}
	for name, v in pairs(svrdtb) do
		if isreset then self:ClearDtb(name) end
		for serverid, index in pairs(v) do
			self:SetSvrdtb(name, serverid, index)
			table.insert(sqldatas, { name = name, serverid = serverid, area = index })
		end
	end
	if next(sqldatas) then
		server.mysqlCenter:insert_ms(tbname, sqldatas)
	end
	skynet.log_info("============== ReInitSvrdtb end ==============", isreset)
end

function DispatchCenter:SendDtbinfo(src)
	server.serverCenter:Send(src, "UpdateServerDtb", self.svrdtb, true)
end

function DispatchCenter:BroadcastDtbinfo(newsvrdtb, isreset)
	if newsvrdtb then
		local svrdtb = {}
		for name, v in pairs(newsvrdtb) do
			svrdtb[name] = {}
			for serverid, index in pairs(v) do
				svrdtb[name][serverid] = {
					index = index,
				}
			end
		end
		server.serverCenter:Broadcast("UpdateServerDtb", svrdtb, isreset)
		return
	end
	server.serverCenter:Broadcast("UpdateServerDtb", self.svrdtb, true)
end

function DispatchCenter:Match(dispatchfunc, param)
	dispatchfunc = dispatchfunc and DispatchFunc[dispatchfunc] or DispatchFunc.DtbByServerid2
	local svrdtb = dispatchfunc(server.serverCenter.svrlist.logic, param)
	self:ReInitSvrdtb(svrdtb, true)
	server.nodeDispatch:CheckNodeEnough()
	self:BroadcastDtbinfo(svrdtb, true)
	return true
end
-- 暂时只支持 DispatchFunc.AutoDtbAdd、DtbOneByOne
function DispatchCenter:AddMatch(dispatchfunc, param)
	dispatchfunc = dispatchfunc and DispatchFunc[dispatchfunc] or DispatchFunc.AutoDtbAdd
	local svrdtb = dispatchfunc(server.serverCenter.svrlist.logic, param, self.svrdtb)
	self:ReInitSvrdtb(svrdtb)
	server.nodeDispatch:CheckNodeEnough(nil, true)
	self:BroadcastDtbinfo(svrdtb)
	return true
end

function DispatchCenter:ToAddMatch(dispatchfunc, param)
	dispatchfunc = dispatchfunc and DispatchFunc[dispatchfunc] or DispatchFunc.AutoDtbAdd
	if self.addMatchTimer[dispatchfunc] then return end
	self.addMatchTimer[dispatchfunc] = skynet.timeout(5 * 100, function()
			self.addMatchTimer[dispatchfunc] = nil
			self:AddMatch(dispatchfunc, param)
		end)
end

-- 自动分配新的服务器到cross
function DispatchCenter:AddOneMatch(newserverid, dispatchfunc, param)
	dispatchfunc = dispatchfunc and DispatchFunc[dispatchfunc] or DispatchFunc.AutoDtbAddOne
	local svrdtb, same = dispatchfunc(server.serverCenter.svrlist.logic, newserverid, self.svrdtb)
	if same ~= true then
		skynet.log_info("~ReInitSvrdtb")
		self:ReInitSvrdtb(svrdtb, true)
		server.nodeDispatch:CheckNodeEnough()
		self:BroadcastDtbinfo(svrdtb, true)
	end
	return true
end

server.SetCenter(DispatchCenter, "dispatchCenter")
return DispatchCenter