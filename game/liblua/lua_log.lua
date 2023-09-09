local skynet = require "skynet"
local inspect = require "inspect"
local server = require "server"

local M = {}
local levels = {
	debug = 1,
	info = 2,
	warn = 3,
	error = 4,
}
local level = skynet.getenv("log_level") or "debug"
local loglevel = levels[level]

function M.is_debug()
	if levels.debug < loglevel then return end
	return true
end

function M.debug(...)
	if levels.debug < loglevel then return end
	local tbl = {}
	for i = 1, select('#', ...) do
		local v = select(i, ...)
		tbl[i] = table.inspect(v)
	end
	local tag = "[" .. (server.wholename or "") .. ":DEBUG]"
	skynet.error(tag, table.concat(tbl, " "))
end

function M.info(...)
	if levels.info < loglevel then return end
	local tag = "[" .. (server.wholename or "") .. ":INFO]"
	skynet.error(tag, ...)
end

function M.warn(...)
	if levels.warn < loglevel then return end
	local tag = "[" .. (server.wholename or "") .. ":WARN]"
	skynet.error(tag, ...)
end

function M.error(...)
	if levels.error < loglevel then return end
	local tag = "[" .. (server.wholename or "") .. ":ERROR]"
	skynet.error(tag, ...)
	skynet.error(tag, debug.traceback())
end

function M.log(...)
	skynet.error(...)
end

skynet.log_info = M.info
skynet.log_warn = M.warn
skynet.log_error = M.error
skynet.log_debug = M.debug

return M
