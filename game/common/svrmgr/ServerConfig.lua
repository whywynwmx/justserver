local server = require "server"

local ServerConfig = {}

ServerConfig.svrNameToNodeName = {
	world		= "cross",
	war			= "cross",
	op			= "cross",			--和运维通信
	httpp		= "plat",
	mainplat	= "plat",
	httpr		= "record",
	mainrecord	= "record",
}

ServerConfig.moduleToSvr = {
	senluodian	= "war",
}

server.SetCenter(ServerConfig, "serverConfig")
return ServerConfig