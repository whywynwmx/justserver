local skynet = require "skynet"


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
    table.insert(args, 1, func)
    table.insert(args, 1, obj)

    local _func = function()
        obj[func](table.unpack(args))
    end
    local session = skynet.timeout(delay, _func)
    return session
end

function skynet.add_update_timer(delay, func, obj, ...)
    local args = {...}
    table.insert(args, 1, func)
    table.insert(args, 1, obj)

    local _func = function()
        func(table.unpack(args))
    end
    local session = skynet.timeout(delay, _func)
    return session
end
