local oo = require "class"

local modules =
{
	"lua_util",
	
	"modules.Event",
	"modules.BaseCenter",

	"mysql.MysqlCenter",
	"mysql.config",
	"mysql.update",
	"mysql.MysqlBlob",

	"dispatch.DispatchCenter",

	"svrmgr.ServerCenter",
	"svrmgr.NodeCenter",
}
oo.require_module(modules)

local handlers =
{
}

oo.require_handler(handlers)
