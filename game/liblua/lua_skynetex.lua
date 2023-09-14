local skynet = require "skynet"
require "lua_log"

--获取当前时间戳，不要小数
function skynet.timeI()
    return math.floor(skynet.time())
end

--获取当前毫秒时间
function skynet.time_ms()
    return math.floor(skynet.time() * 1000)
end

function skynet.add_update_timer(delay, obj, func, ...)
    local args = {...}
    -- table.insert(args, 1, func)
    table.insert(args, 1, obj)

    local _func = function()
        obj[func](table.unpack(args))
    end
    local session = skynet.timeout(delay, _func)
    return session
end

function skynet.add_local_timer(delay, func, obj, ...)
    local args = {...}
    -- table.insert(args, 1, func)
    table.insert(args, 1, obj)

    local _func = function()
        func(table.unpack(args))
    end
    local session = skynet.timeout(delay, _func)
    return session
end

function skynet.waitmultrun(func, list, ...)
	if not next(list) then return {} end
	local args = {...}
	local tmp, ret = 0, {}
	local co = coroutine.running()
	for i, v in pairs(list) do
		tmp = tmp + 1
		skynet.timeout(0, function()
				ret[i] = func(i, v, table.unpack(args))
				tmp = tmp - 1
				if tmp == 0 then
					lua_app.wake(co)
				end
			end)
	end
	lua_app.wait()
	return ret
end

return skynet