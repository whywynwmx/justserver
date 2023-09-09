local oo = require "class"

local modules =
{
	"lua_util",

	"svrmgr.ServerCenter",
	"svrmgr.NodeCenter",
}
oo.require_module(modules)

local handlers =
{
}

oo.require_handler(handlers)
