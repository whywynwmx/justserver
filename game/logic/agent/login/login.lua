local skynet = require "skynet"
require "skynet.manager"
require "lua_skynetex"
local server = require "server"

function server.QueryList(id, msg)
    return { code = false, actorid = 0, }
end