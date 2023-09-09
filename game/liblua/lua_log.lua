local skynet = require "skynet"
local inspect = require "inspect"

local M = {}
local levels = {
	debug = 1,
	info = 2,
	warn = 3,
	error = 4,
}
local level = skynet.gete("log_level") or "debug"
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
	skynet.error("[DEBUG]", table.concat(tbl, " "))
end

function M.info(...)
	if levels.info < loglevel then return end
	skynet.error("[INFO]", ...)
end

function M.warn(...)
	if levels.warn < loglevel then return end
	skynet.error("[WARN]", ...)
end

function M.error(...)
	if levels.error < loglevel then return end
	skynet.error("[ERROR]", ...)
	skynet.error("[ERROR]", debug.traceback())
end

function M.log(...)
	skynet.error(...)
end

return M
