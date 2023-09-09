local lua_util = {}
local lua_app = require "lua_app"
local server = require "server"
local inspect = require "inspect"
local skynet = require "skynet"

local print = print
local tconcat = table.concat
local tinsert = table.insert
local srep = string.rep
local type = type
local pairs = pairs
local tostring = tostring
local next = next
function lua_util.print(root)
	if root == nil then
		return
	end
	local cache = {  [root] = "." }
	local function _dump(t,space,name)
		local temp = {}
		for k,v in pairs(t) do
			local key = tostring(k)
			if cache[v] then
				tinsert(temp,"+" .. key .. " {" .. cache[v].."}")
			elseif type(v) == "table" then
				local new_key = name .. "." .. key
				cache[v] = new_key
				tinsert(temp,"+" .. key .. _dump(v,space .. (next(t,k) and "|" or " " ).. srep(" ",#key),new_key))
			else
				tinsert(temp,"+" .. key .. " [" .. tostring(v).."]")
			end
		end
		return tconcat(temp,"\n"..space)
	end
	skynet.error(_dump(root, "",""))
end

-- 在表中寻找某个值的引用
function lua_util.findRef(findObj, value)
	local caches = {}
	setmetatable(caches, {__mode = "k"})
	local function foreachTbl(obj, key)	
		key = key or ""	
		if caches[obj] then
			return
		end
			
		caches[obj] = true
		local tbl, weakKey, weakValue
		if type(obj) == "table" then
			tbl = obj
			local mt = getmetatable(obj)	
			if mt then
				if mt.__mode then
					weakKey = string.find(mt.__mode, "k")
					weakValue = string.find(mt.__mode, "v")
				end

				foreachTbl(mt, key .. ".metatable")				
			end
		elseif type(obj) == "function" then
			tbl = lua_util.getUpvalues(obj)
		elseif type(obj) == "thread" then	
			tbl = lua_util.getLocalValues(obj)
		else
			return
		end

		for k, v in pairs(tbl) do				
			if not weakKey and (type(k) == "table" or type(k) == "function") and tostring(k) == value or 
			   not weakValue and (type(v) == "table" or type(v) == "function") and tostring(v) == value then
				table.print(server.lastFuncInfos, "server.lastFuncInfo")
				table.print(server.lastStackInfos, "server.lastStackInfo")
				local selfKey = tostring(k)				
				if type(v) == "table" and v._fileinfo_ then
					selfKey = selfKey .. "_" .. v._fileinfo_
				end
				print("~~~~~~~~~~~~~find value", value, key .. "." .. selfKey)
			else
				if not weakKey then
					foreachTbl(k, key .. "." .. tostring(k))
				end

				if not weakValue then
					foreachTbl(v, key .. "." .. tostring(k))
				end
			end
		end
	end

	foreachTbl(findObj)
end

function lua_util.addLastCoStack(co)
	server.lastStackInfos = server.lastStackInfos or {}
	table.insert(server.lastStackInfos, lua_app.coStacks[co])
	if #server.lastStackInfos > 3 then
		table.remove(server.lastStackInfos, 1)
	end
end

function lua_util.addLastFuncInfo(tag, info)
	server.lastFuncInfos = server.lastFuncInfos or {}
	table.insert(server.lastFuncInfos, string.format("%s-%s-%d", tag, info.short_src, info.linedefined))
	if #server.lastFuncInfos > 5 then
		table.remove(server.lastFuncInfos, 1)
	end
end

-- 获取指定协程的所有堆栈上的临时变量
function lua_util.getLocalValues(co)
	if type(co) ~= "thread" then
		return
	end
	local tbl = {}

	-- 获取协程的钩子信息
	local hookFunc = debug.gethook(co)
	tbl["hookFunc"] = hookFunc

	local stackIdx = 1
	while true do
		local info = debug.getinfo(co, stackIdx)
		if info == nil then
			break
		end

		tbl[string.format("coinfo-%d", stackIdx)] = info
		lua_util.addLastCoStack(co)
		lua_util.addLastFuncInfo("local", info)		
			
		local valueIdx = -50	--负索引表示变参，10个应该够用了
		while true do
			local k, v = debug.getlocal(co, stackIdx, valueIdx)
			if k == nil and valueIdx > 0 then
				break
			end		
			
			if k and v then
				local name = info.source:match(".+%/(.+)$")
				local line = info.currentline
				local func = info.name
				local content = string.format("%s-%d-%s: ",name,line, func)
					
				local kk = string.format("[local-%d-%d-%s]", stackIdx, valueIdx, k)
				if type(k) == "table" or type(k) == "function" or type(k) == "thread" then
					skynet.error("kk", kk)
				end

				tbl[kk] = v
				--print(content, kk, v)
			end
			valueIdx = valueIdx + 1		
		end
		
		stackIdx = stackIdx + 1
	end

	return tbl
end

-- 获取一个函数所有的upvalue
function lua_util.getUpvalues(func)
	if type(func) ~= "function" then
		return
	end

	local info = debug.getinfo(func)	
	lua_util.addLastFuncInfo("upv", info)

	local tbl = {}
	local idx = 1
	while true do
		local k, v = debug.getupvalue(func, idx)
		if k == nil then
			break
		end

		local kk = string.format("[upv-%d-%s]", idx, k)
		tbl[kk] = v
		--print("upvalue", kk, v)
		if type(k) == "table" or type(k) == "function" or type(k) == "thread" then
			skynet.error("getUpvalues kk", kk)
		end
		idx = idx + 1
	end

	return tbl
end

function lua_util.dumpTable(root, dumpUpvalue)	
	local cacheTable = {  [root] = "/." }
	local function _dump(prikey, key, tb, level)
		local space = ""		
		for i = 1, level do 
			space = space .. "    "
		end 
        local space2 = space .. "    "

        local outstr = ""
		if #key > 0 then 
			outstr = outstr .. string.format("%s%s = {\n", space, key)  -- key = {
		else 
			outstr = outstr .. string.format("%s{\n", space) -- {
		end 

        local cache = ""
        local cache2 = ""
        local cache3 = ""
		for k, v in pairs(tb) do 	
			if type(k) == "table" then
				if cacheTable[k] then
					cache2 = cache2 .. string.format("%s%s = { \"%s\" },\n", space2, "key", cacheTable[k])
				else
					local new_key = prikey .. ".key." .. tostring(k)
					cacheTable[k] = new_key				
					cache2 = cache2 .. _dump(new_key, key .. " .. tostring(k)", k, level + 1)	
				end
			else			
				local tp = type(v)	
				local kk = tostring(k)
				if type(k) == "number" then 
					kk = string.format("[%s]", tostring(k)) 
				end 			
				if cacheTable[v] then
					cache = cache .. string.format("%s%s = { \"%s\" },\n", space2, kk, cacheTable[v])
				elseif tp == "table" then 				
					local new_key = prikey .. "." .. k
					cacheTable[v] = new_key				
					cache2 = cache2 .. _dump(new_key, kk, v, level + 1)						

				elseif tp == "string" then 
					cache = cache .. string.format("%s%s = \"%s\",\n", space2, kk, v) -- [key] = "string"
				elseif tp == "number" or tp == "boolean" then 
					cache = cache .. string.format("%s%s = %s,\n", space2, kk, tostring(v)) -- [key] = number
				elseif tp == "function" and dumpUpvalue then
					local upvalues = lua_util.getUpvalues(v)
					local new_key = prikey .. "." .. k
					cacheTable[v] = new_key	
					cache = cache .. _dump(new_key, "upvalues", upvalues, level + 1)	
				else 
					cache = cache .. string.format("%s%s = \"%s\",\n", space2, kk, tostring(v)) -- [key] = nil/function/....
				end 
			end
		end 

		local mt = getmetatable(tb)	
		if mt then
			if cacheTable[mt] then
				cache3 = cache3 .. string.format("%s%s = { \"%s\" },\n", space2, "metatable", cacheTable[mt])
			else
				local new_key = prikey .. ".metatable" 
				cacheTable[mt] = new_key				
				cache3 = cache3 .. _dump(new_key, "metatable_" .. tostring(mt), mt, level + 1)			
			end
		end

		outstr = outstr .. cache
		outstr = outstr .. cache2
		outstr = outstr .. cache3
		outstr = outstr .. string.format("%s},\n", space ) -- }
		
		return outstr
	end 

	return _dump("/", "", root, 0)
end

function lua_util.print2(root, msg)
	msg = msg or ""
	if type(root) ~= "table" then 
		skynet.error(string.format("%s =========table:[%s].print table=========", info, msg))
		skynet.error(root)
		skynet.error(string.format("%s =========table:[%s].print table=========", info, msg))
		return 
	end 
	
	skynet.error(string.format("%s =========table:[%s].print begin=========", info, msg))
	skynet.error(lua_util.dumpTable(root))	
	skynet.error(string.format("%s =========table:[%s].print end===========", info, msg))
end 

table.print = lua_util.print2
table.inspect = inspect

function lua_util.info(root)
	if root == nil then
		return
	end
	local cache = {  [root] = "." }
	local function _dump(t,space,name)
		local temp = {}
		for k,v in pairs(t) do
			local key = tostring(k)
			if cache[v] then
				tinsert(temp,"+" .. key .. " {" .. cache[v].."}")
			elseif type(v) == "table" then
				local new_key = name .. "." .. key
				cache[v] = new_key
				tinsert(temp,"+" .. key .. _dump(v,space .. (next(t,k) and "|" or " " ).. srep(" ",#key),new_key))
			else
				tinsert(temp,"+" .. key .. " [" .. tostring(v).."]")
			end
		end
		return tconcat(temp,"\n"..space)
	end
	skynet.error(_dump(root, "",""))
end

table.info = lua_util.info

local max_deep_for_ptable = 9
-- ptable(tablename, deepnumber) 只写到屏幕，并输出总结果个数
local function ptable(t, h, d, printfunc)
	printfunc = printfunc or print
	if d and d > max_deep_for_ptable then
		printfunc("max_deep_for_ptable is " .. max_deep_for_ptable .. "got " .. d)
		d = max_deep_for_ptable
	end
	local num = 0
	local function _ptable(_t, _h, _d)
		for i,v in pairs(_t) do
			-- print("-+-+-+-", _d, i, v, type(i), type(v))
			printfunc(string.rep("	", _d) .. (tostring(i) or "ERROR") .. "	" .. (tostring(v) or "ERROR"))
			num = num + 1
			if type(v) == "table" and _h > _d then
				_ptable(v, _h, _d+1)
			end
		end
	end
	printfunc(tostring(t))
	if type(t) == "table" then
		_ptable(t, h or 0, d or 0)
	end
	printfunc("all value number: " .. num)
end
table.ptable = ptable

function lua_util.split(str,sep,jump)
	if str == nil or str == "" or sep == nil then
		return {}
	end
	jump = jump or 0
	local fields = {}
	local pattern = string.format("([^%s]+)", sep)  
	str:gsub(pattern, function (c)
		if jump > 0 then
			jump = jump - 1
		else
			fields[#fields + 1] = c 
		end
	end)
	return fields
end

string.split = lua_util.split

function lua_util.gsplit(str)
	local str_tb = {}
	
	if string.len(str) == 0 then
		return {}
	end

	for i = 1,string.len(str) do
		local new_str = string.sub(str,i,i)
		local new_bit = string.byte(new_str)
		if (new_bit >= 48 and new_bit <= 57) or (new_bit >= 65 and new_bit <= 90) or (new_bit >= 97 and new_bit <=122) then
			table.insert(str_tb,string.sub(str,i,i))
		else
			print("error string")
			return {}
		end
	end
	return str_tb
end

string.gsplit = lua_util.gsplit

function lua_util.stack()
    local startLevel = 2
    local maxLevel = 2 
 
    for level = startLevel, maxLevel do
        local info = debug.getinfo( level, "nSl") 
        if info == nil then break end
        print( string.format("[ line : %-4d]  %-20s :: %s", info.currentline, info.name or "", info.source or "" ) )
 
        local index = 1 
        while true do
            local name, value = debug.getlocal( level, index )
            if name == nil then break end
 
            local valueType = type( value )
            local valueStr
            if valueType == 'string' then
                valueStr = value
            elseif valueType == "number" then
                valueStr = string.format("%.2f", value)
            end
            if valueStr ~= nil then
                print( string.format( "\t%s = %s\n", name, value ) )
            end
            index = index + 1
        end
    end
end

function lua_util.randomRange(min, max)
	return math.random(max - min) + min
end

function lua_util.merge(t1,t2)
	for k,v in pairs(t2) do
		t1[k] = v
	end
	return t1
end
table.merge = lua_util.merge

function lua_util.mergeAr(...)
	local tb = {...}
	local ar = {}
	for i = 1,#tb do
		if type(tb[i]) == "table" then
			for k,v in pairs(tb[i]) do
				table.insert(ar,v)
			end
		end
	end
	return ar
end
table.mergeAr = lua_util.mergeAr

function lua_util.diff2(t1,t2)
	for k,v in pairs(t1) do
		if t2[k] ~= v then
			return true
		end
	end
	return false
end

function lua_util.diff(t1,t2)
	local t3 = {}
	for k,v in pairs(t1) do
		if t2[k] == nil then
			t3[k] = v
		end
	end
	return t3
end
table.diff = lua_util.diff

-- 两个table k/v 是否全相同 只比较一级
function lua_util.same(t1,t2)
	
	for k,v in pairs(t1) do
		if t2[k] ~= v then
			return false
		end
	end

	for k,v in pairs(t2) do
		if t1[k] ~= v then
			return false
		end
	end

	return true 
end 
table.same = lua_util.same 

function lua_util.contains(list, element)
	for k, v in pairs(list) do
		if v == element then
			return k
		end
	end
end

-- 在顺序表中添加一个元素，如果已存在则返回
function lua_util.AddElement(arr, element)
	if table.contains(arr, element) then
		return
	end

	table.insert(arr, element)
end

table.contains = lua_util.contains
table.add = lua_util.AddElement

function lua_util.between(range, value)
	return range[1] <= value and range[2] >= value
end
table.between = lua_util.between

function lua_util.empty(t)
	return _G.next(t) == nil
end

table.empty = lua_util.empty

function lua_util.tableMax(tbl)
	if type(tbl) ~= "table" then
		return
	end

	local maxk, maxv
	for k, v in pairs(tbl) do
		if maxv == nil or maxv < v then
			maxk = k
			maxv = v
		end
	end

	return maxk, maxv
end

table.max = lua_util.tableMax

function lua_util.length(t)
	if t == nil then
		return 0
	end

	local cnt = 0
	local key = nil
	while true do
		key = _G.next(t,key)
		if key ~= nil then
			cnt = cnt + 1
		else
			break
		end
	end
	return cnt
end

table.length = lua_util.length

function lua_util.strToTable(str)
    if str == nil or type(str) ~= "string" then
        return
    end
    return load("return " .. str)()
end
table.fromString = lua_util.strToTable

function lua_util.copy(tb)
	local ret_tb = {}
	local function func(obj)
		if type(obj) ~= "table" then
			return obj
		end
		local new_tb = {}
		ret_tb[obj] = new_tb
		for k,v in pairs(obj) do
			new_tb[func(k)] = func(v)
		end
		return setmetatable(new_tb,getmetatable(obj))
	end
	return func(tb)
end
table.copy = lua_util.copy

function lua_util.packKey(tb)
	local ar = {}
	for k,v in pairs(tb) do
		table.insert(ar,k)
	end
	return table.concat(ar,",")
end
table.packKey = lua_util.packKey

function lua_util.packKeyArray(tb)
	local ar = {}
	for k,v in pairs(tb) do
		table.insert(ar,k)
	end
	return ar
end
table.packKeyArray = lua_util.packKeyArray

function lua_util.packValue(tb)
	local ar = {}
	for k,v in pairs(tb) do
		table.insert(ar,v)
	end
	return table.concat(ar,",")
end
table.packValue = lua_util.packValue

function lua_util.matchValue(tb, condfunc, default)
	local index = default
	local diffvalue = math.huge
	local quit = false
	local hunt = false
	for id, data in ipairs(tb) do
		local val = condfunc(data)
		hunt = true
		if diffvalue > val and val >= 0 then
			index = id
			diffvalue = val
			hunt = false
			quit = true
		end
		if quit and hunt then break end
	end
	return index and tb[index]
end
table.matchValue = lua_util.matchValue

function lua_util.randTB(tb,num,handler)
	local ar = {}
	local len = 0
	for k,v in pairs(tb) do
		table.insert(ar,k)
		len = len + 1
	end

	local retb = {}
	local cnt = 0
	for i = 1, len do
		if cnt >= num then
			break
		end
		local tail = len - i + 1
		local randValue = math.random(1, tail)
		if handler then
			if handler(tb[ar[randValue]]) then
				retb[ar[randValue]] = tb[ar[randValue]]
				cnt = cnt + 1
			end
		else
			retb[ar[randValue]] = tb[ar[randValue]]
			cnt = cnt + 1
		end
		
		ar[randValue] = ar[tail]
	end
	return retb
end

-- 所有表全部重新创建，不能有循环表，不然会无限循环
function _wcopy(tvalue)
	if type(tvalue) ~= "table" then return tvalue end
	local tb = {}
	for k, v in pairs(tvalue) do
		if type(k) == "table" then
			k = _wcopy(k)
		end
		if type(v) == "table" then
			v = _wcopy(v)
		end
		tb[k] = v
	end
	return tb
end
lua_util.wcopy = _wcopy
table.wcopy = _wcopy
-- 同上，不过key会尽量转换为number类型
local function _numkeywcopy(tvalue)
	if type(tvalue) ~= "table" then return tvalue end
	local tb = {}
	for k, v in pairs(tvalue) do
		if type(k) == "table" then
			k = _numkeywcopy(k)
		end
		if type(v) == "table" then
			v = _numkeywcopy(v)
		end
		tb[tonumber(k) or k] = v
	end
	return tb
end
lua_util.nkcopy = _numkeywcopy
table.nkcopy = _numkeywcopy

function lua_util.weakCopy(tvalue)
	local tb = {}
	for k, v in pairs(tvalue) do
		tb[k] = v
	end
	return tb
end
table.weakCopy = lua_util.weakCopy

function lua_util.randArray(ar,num)
	local tb = {}
	local result = {}
	if #ar <= num then
		return ar
	end
	for i = 1,#ar do
		table.insert(tb,i)
	end
	for i = 1,num do
		local key = math.random(1,#tb)
		table.insert(result,ar[tb[key]])
		table.remove(tb,key)
	end
	return result
end

function lua_util.randArray2(ar)
	local tb = {}
	local result = {}
	for i = 1,#ar do
		table.insert(tb,i)
	end
	for i = 1,#ar do
		local key = math.random(1,#tb)
		table.insert(result,ar[tb[key]])
		table.remove(tb,key)
	end
	return result
end

function lua_util.getarray(ar, num)
	local max = #ar
	if num >= max then 
		return lua_util.weakCopy(ar) 
	end

	local realmax = max + 1
	local indexs, ret = {}, {}
	for i = 1, num do
		local index = math.random(1, max)
		max = max - 1
		while indexs[index] do
			index = realmax - indexs[index]
		end
		indexs[index] = i
		table.insert(ret, ar[index])
	end
	return ret
end

function lua_util.randomGetOne(ar)
	return ar[math.random(1, #ar)]
end

-- 在数组ar中随机[min, max]个元素
function lua_util.getArrayRange(ar, min, max)
	local len = #ar
	if min >= len then 
		return lua_util.weakCopy(ar) 
	end

	max = max or min
	max = math.min(max, len)
	local indexs, ret = {}, {}
	for idx, _ in pairs(ar) do
		table.insert(indexs, idx)
	end

	local rtcount = math.random(min, max)	
	for i = 1, rtcount do
		local index = math.random(1, #indexs)
		table.insert(ret, ar[indexs[index]])
		table.remove(indexs, index)
	end

	return ret
end


function lua_util.DelArray(ar,num)
	if num <= 0 then
		return ar
	end
	if #ar <= num then
		return {}
	end
	local ar2 = {}
	for i = num+1,#ar do
		table.insert(ar2,ar[i])
	end
	return ar2
end

-- 转换数组对象
function lua_util.ConverToArray(data, startIndex, endIndex)
	local tmp = {}
	local insert = table.insert
	for i = startIndex, endIndex do
		insert(tmp, data[i])
	end
	return tmp
end

-- 转换数组对象
function lua_util.ConverToArray2(data, startIndex, endIndex, default)
	local tmp = {}
	local insert = table.insert
	for i = startIndex, endIndex do
		insert(tmp, data[i] or default)
	end
	return tmp
end

-- 删除数组中的某个元素
function lua_util.DelArrayElement(list, element)
	for k, v in pairs(list) do
		if element == v then
			table.remove(list, k)
			break
		end
	end
end

table.del = lua_util.DelArrayElement

-- 在数组1中排除数组2的对象
function lua_util.ArrayExclude(list1, list2)
	local tmp = {}
	for _, v in pairs(list1) do
		if not table.contains(list2, v) then
			table.insert(tmp, v)
		end
	end

	return tmp
end

local function _NewTable()
	return {}
end

function lua_util.CreateArray(length, fill)
	fill = fill or _NewTable
	local tmp = {}
	local insert = table.insert
	for i = 1, length do
		if type(fill) == "function" then
			insert(tmp, fill(i))
		else
			insert(tmp, fill)
		end
	end
	return tmp
end

function lua_util.bit_open(data, pos)
	return (data | 1 << pos - 1)
end

function lua_util.bit_shut(data, pos)
	return (data & ~(1 << pos - 1))
end

function lua_util.bit_status(data, pos)
	return ((data >> pos - 1 & 1) ~= 0)
end

function lua_util.GetArrayPlus(addKey)
	local pluskey = addKey
    local recordkey = {}

    local function _GetTick(tb)
    	local tick = {}
    	for k, v in pairs(tb) do
    		if k ~= pluskey then
    			table.insert(tick, v)
    		end
    	end
        return table.concat(tick, ".")
    end

    local function _Merger(sourceTb, newTb)
    	for __,v in pairs(newTb) do
    		if type(v) == "table" then
    			_Merger(sourceTb, v)
    		else
    			local tick = _GetTick(newTb) 
    			local index = recordkey[tick]
    			if index then
    				sourceTb[index][pluskey] = sourceTb[index][pluskey] + newTb[pluskey]
    			else
    				table.insert(sourceTb, table.wcopy(newTb))
    				recordkey[tick] = #sourceTb
    			end
    			break
    		end
    	end
    end

    local operateTb = setmetatable({}, {__add = function(sourceTb, addTb)
    	addTb = addTb or {}
    	_Merger(sourceTb, addTb)
    	return sourceTb
    end})

    return operateTb
end
table.GetTbPlus = lua_util.GetArrayPlus

function lua_util.ArraySet(tbl, idx, value, default)
	local len = #tbl
	if len < idx then
		for i = len +1, idx do
			tbl[i] = default or 0
		end
	end
	tbl[idx] = value
end
table.ArraySet = lua_util.ArraySet

function lua_util.shuffle(t)
    if type(t) ~= "table" then
        return
    end
	local len = #t
	for i = 1, len do
		local tar = math.random(len)
		local tmp = t[tar]
		t[tar] = t[i]
		t[i] = tmp
	end
	return t
end
table.shuffle = lua_util.shuffle

function lua_util.getFightEntityOnlyId(pos, num)
	num = num or 1
	return pos * 10 + num
end

function lua_util.fightEntityOnlyIdToPos(onlyId)
	local pos = math.floor(onlyId / 10)
	local num = onlyId - pos * 10
	return pos, num 
end

-- 仅支持单层的table, 成员类型只能是string或number
function lua_util.stringToTable(str, split1, split2)
	split1 = split1 or "&"
	split2 = split2 or "="

	local tbl = {}
	local arr = lua_util.split(str, split1)
	for _, data in pairs(arr) do
		local subdata = lua_util.split(data, split2)
		tbl[subdata[1]] = subdata[2]
	end

	return tbl
end

-- 仅支持单层的table, 成员类型只能是string或number
function lua_util.tableToString(tbl, split1, split2)
	split1 = split1 or "&"
	split2 = split2 or "="

	local str = ""
	for k, v in pairs(tbl) do
		if (type(k) == "string" or type(k) == "number") and (type(v) == "string" or type(v) == "number") then
			str = str .. split1 .. tostring(k) .. split2 .. tostring(v)
		end
	end
	return str
end

function lua_util.time_to_str(t, count)
	local TD = math.floor(t/86400)
	local TH = math.floor((t%86400)/3600)
	local TM = math.floor((t%3600)/60)
	local TS = t%60

	count = count or 3
	local str = ""
	if count >= 4 then
		str = str .. TD .. ":"
	end 
	if count >= 3 then
		str = str .. TH .. ":"
	end 
	if count >= 2 then
		str = str .. TM .. ":"
	end 
	if count >= 1 then
		str = str .. TS 
	end 
	return str 
end 

-- 通过dbid获取serverid 
function lua_util.getServeridByDbid(dbid)
	if dbid then 
		return dbid >> 34 
	end 
end

local callFuncTimes = {}
local function StatFuncCall()
	local tbl = debug.getinfo(2, "Snl")
	local name = tbl and tbl.name or ""
	local src = tbl and tbl.short_src or ""
	local line = tbl and tbl.currentline or ""
	local n = src .. " " .. line .. " " .. name
	callFuncTimes[n] = (callFuncTimes[n] or 0) + 1
end

function lua_util.startStatFuncCall()
	callFuncTimes = {}
	debug.sethook(StatFuncCall, 'c') 
end

function lua_util.stopStatFuncCall()
	debug.sethook() 
	local sorts = {}
	for k, v in pairs(callFuncTimes) do
		table.insert(sorts, {n=k, c=v})
	end

	table.sort(sorts, function(l, r) return l.c > r.c end)
	for k, v in ipairs(sorts) do
		print(v.n, v.c)
	end

	callFuncTimes = {}
end

function lua_util.bubble_sort(t, cmpfunc)
    local n = #t
    for j = 1, n - 1 do
        for i = 1, n - j do
            if cmpfunc(t[i + 1], t[i]) then
                t[i], t[i+1] = t[i+1], t[i];
            end
        end
    end
end
table.bubble_sort = lua_util.bubble_sort

--[[
	* 用参数 param 格式化字符串中的参数变量
	* 参数格式为: 
	*      {0}: 第1个参数
	*      {1}: 第2个参数
	*      {N}: 第N个参数
	*   参数可不连续
	* 尽量不要在文本中配置出现 花括号中包含花括号 的情况. 
	* 格式化后, 花括号中的要么替换成对应值, 要么就替换为空字符串
]]
function lua_util.formatText(str, ...)
	if not str then
		return "";
	end
	local param = {...};
	return string.gsub(str, "{%d}", function (s)
		local i = tonumber(string.sub(s, 2, #s - 1));
		return tostring(param[i] or "");
	end);
end

--如果是table，最多遍历5层
function lua_util.inspectex(...)
	local ret = ""
	for _, t in ipairs({...}) do
		ret = ret .. (t == nil and "nil" or inspect(t, {depth=5})) .. "  "
	end
	return ret
end
table.inspectex = lua_util.inspectex

return lua_util
