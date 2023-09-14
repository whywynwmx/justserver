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

	"svrmgr.ServerConfig",
	"dispatch.NodeDispatch",
	"dispatch.DispatchFunc",
	"dispatch.DispatchCenter",

	"svrmgr.ServerCenter",
	"svrmgr.NodeCenter",
}
oo.require_module(modules)

local handlers =
{
}

oo.require_handler(handlers)
