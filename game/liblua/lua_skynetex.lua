local skynet = require "skynet"

--移除定时器补充
function skynet.remove_timeout(session, func)
    local cb = function()
        if func then
            func()
        end
    end
    skynet.timeout(session, cb)
end

--获取当前时间戳，不要小数
function skynet.timeI()
    return math.floor(skynet.time())
end

--获取当前毫秒时间
function skynet.time_ms()
    return math.floor(skynet.time() * 1000)
end

