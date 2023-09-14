local skynet = require "skynet"
local server = require "server"

local DispatchFunc = {}

local num_one_group = 9999999

local cross_module_group = {
--	senluodian		= 16,
}

local function _GetNodeDtb(nnames, onesvrdtb)
	local svrdtb = {}
	for svrname, nodename in pairs(server.serverConfig.svrNameToNodeName) do
		if nnames[nodename] then
			svrdtb[svrname] = table.wcopy(onesvrdtb) or true
		end
	end
	return svrdtb
end
-- 测试用的
function DispatchFunc.DtbByTest(svrlist)
	local onesvrdtb = {}
	local i = 0
	for serverid, _ in pairs(svrlist) do
		i = i + 1
		onesvrdtb[serverid] = math.ceil(i/num_one_group)
	end
	return _GetNodeDtb({ cross = true }, onesvrdtb)
end
-- 根据服务器ID判断
function DispatchFunc.DtbByServerid(svrlist)
	local onesvrdtb = {}
	local maxserverid = 0
	for serverid, _ in pairs(svrlist) do
		maxserverid = math.max(maxserverid, serverid)
	end
	for i = 1, maxserverid do
		onesvrdtb[i] = math.ceil(i/num_one_group)
	end
	return _GetNodeDtb({ cross = true }, onesvrdtb)
end
function DispatchFunc.DtbByServerid2(svrlist)
	local onesvrdtb = {}
	local newlist = {}
	for serverid, _ in pairs(svrlist) do
		if serverid > 0 then
			table.insert(newlist, serverid)
		end
	end
	table.sort(newlist)
	for i = 1, #newlist do
		onesvrdtb[newlist[i]] = math.ceil(i/num_one_group)
	end
	local ret = _GetNodeDtb({ cross = true }, onesvrdtb)

	--其他特殊分组模块
	for crossmodule, grpmax in pairs(cross_module_group) do
		local dtb = {}
		for i = 1, #newlist do
			dtb[newlist[i]] = math.ceil(i/grpmax)
		end
		ret[crossmodule] = table.wcopy(dtb)
	end
	return ret
end
-- 手动分配跨服
function DispatchFunc.DtbOneByOne(svrlist, onesvrdtb)
	return _GetNodeDtb({ cross = true }, onesvrdtb)
end

--自动分配cross服
function DispatchFunc.AutoDtbAddOne__(svrlist, newid, onesvrdtb, grp_max)
	grp_max = grp_max or num_one_group
	local newsvrdtb = {}
	local maxgrpid = 1
	local numinmaxgrp = 0
	local dispatched = false
	if onesvrdtb then
		for serverid, v in pairs(onesvrdtb) do
			newsvrdtb[serverid] = v.index
			if serverid == newid then
--				return onesvrdtb, true
				dispatched = true
			end
			if v.index > maxgrpid then
				maxgrpid = v.index
				numinmaxgrp = 1
			elseif v.index == maxgrpid then
				numinmaxgrp = numinmaxgrp + 1
			end
		end
	end

	if dispatched ~= true then
		if numinmaxgrp < grp_max then
			newsvrdtb[newid] = maxgrpid
		else
			newsvrdtb[newid] = maxgrpid + 1
		end
	end

	return newsvrdtb, dispatched
end

function DispatchFunc.AutoDtbAddOne(svrlist, newid, svrdtb, grp_max)
	local newsvrdtb, same = DispatchFunc.AutoDtbAddOne__(svrlist, newid, svrdtb["war"], grp_max)

	skynet.log_info("~~DispatchFunc.AutoDtbAddOne", newid, newsvrdtb[newid])

	local ret = _GetNodeDtb({ cross = true }, newsvrdtb)

	--其他特殊分组模块
	for crossmodule, grpmax in pairs(cross_module_group) do
		local dtb, msame = DispatchFunc.AutoDtbAddOne__(svrlist, newid, svrdtb[crossmodule], grpmax)
		ret[crossmodule] = table.wcopy(dtb)

		same = same and msame
	end

	return ret, same
end

--------------------------- 自动分配登录服和后台的 ---------------------------
local _autoDtbNames = {
	plat 		= true,
	record 		= true,
}
function DispatchFunc.AutoDtbByNum(svrlist, count)
	local cc = 0
	local onesvrdtb = {}
	for serverid, _ in pairs(svrlist) do
		cc = cc % count + 1
		onesvrdtb[serverid] = cc
	end
	return _GetNodeDtb(_autoDtbNames, onesvrdtb)
end
-- 增加服务器的分配
function DispatchFunc.AutoDtbAdd(svrlist, count, svrdtb)
	count = count or 1
	assert(count > 0, count)
	local function _GetMin(list)
		local min, minid = math.huge
		for id, count in pairs(list) do
			if min > count then
				minid = id
				min = count
			end
		end
		return minid
	end
	local newsvrdtb = {}
	for name, _ in pairs(_GetNodeDtb(_autoDtbNames)) do
		local onesvrdtb = svrdtb[name] or {}
		newsvrdtb[name] = {}
		local cc = {}
		local limitcount = server.GetServerNum()[name]
		for i = 1, limitcount or count do
			cc[i] = 0
		end
		for serverid, info in pairs(onesvrdtb) do
			cc[info.index] = cc[info.index] + 1
		end
		for serverid, _ in pairs(svrlist) do
			if not onesvrdtb[serverid] then
				local minid = _GetMin(cc)
				newsvrdtb[name][serverid] = minid
				cc[minid] = cc[minid] + 1
			end
		end
	end
	return newsvrdtb
end

return DispatchFunc