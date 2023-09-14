local skynet = require "skynet"
require "lua_skynetex"
local mysql = require "skynet.db.mysql"

local function get_table_real_count(t)
	local i = 0
	for k,v in pairs(t) do
		i = i + 1
	end
	return i
end

local api = {}

local client_api = {}
local client_meta =
{
	__index = client_api
}

function api.client(host, port, user, password, database, charset)
	skynet.log_debug("mysql client connect to %s:%d", host, port)

	host = host or "127.0.0.1"
	port = port or 3306
	charset = charset or "utf8mb4"
	local db = mysql.connect({
		host = host,
		port = port,
		user = user,
		password = password,
		database = database,
		charset = charset,
	})
	if not db then
		return
	end

	local client =
	{
		host = host,
		port = port,
		user = user,
		password = password,
		database = database,
		charset = charset,
		db = db,
		timer = 0,
		timer_2 = 0,
	}

	return setmetatable(client,client_meta)
end

function client_api:add_local_timer(delay_ms,func,...)
	return skynet.add_local_timer(delay_ms,func,self,...)
end

function client_api.del_local_timer(timer_id)
	skynet.remove_timeout(timer_id)
end

function client_api:check_connect()
	local id = self.id
	local database = self.database

	self.timer_2 = 0
	self.timer = self:add_local_timer(30 * 100,self.reconnect)
	self:call_execute("select 1;")
	self:del_local_timer(self.timer)
	if self.timer_2 <= 0 then
		self.timer_2 = self:add_local_timer(60 * 100,self.check_connect)
	end
end

function client_api:reconnect()
	lua_app.send(self.id,lua_app.MSG_TEXT,"quit")
	clib.kill(self.id)
	self.db = mysql.connect({
		host = self.host,
		port = self.port,
		user = self.user,
		password = self.password,
		database = self.database,
		charset = self.charset,
	})
	if not self.db then
		skynet.log_error("client_api:reconnect mysql failed:", self.database)
	end
	if self.timer_2 <= 0 then
		self.timer_2 = self:add_local_timer(60 * 100,self.check_connect)
	end
	skynet.log_error("client_api:reconnect mysql %d",self.id)
end

function client_api:call_execute(sql_str)
	skynet.log_debug("mysql call_execute:", sql_str)

	return self.db:query(sql_str)
end

function client_api:send_execute(sql_str)
	skynet.log_debug("mysql send_execute:", sql_str)

	return self.db:query(sql_str)
end

function client_api:close()
	if self.timer_2 > 0 then
		self:del_local_timer(self.timer_2)
	end

	if self.timer > 0 then
		self:del_local_timer(self.timer)
	end

	self.db:disconnect()
end

function client_api:wait_close()
	self:close()
end


client_api.escape_string = mysql.quote_sql_str
api.escape_string = mysql.quote_sql_str

function client_api:query_one(table_name,cond,fields)
	local fields_str = ""
	if get_table_real_count(fields or {}) <= 0 then
		fields_str = "*"
	else
		local field_values = {}
		for field ,_ in pairs(fields) do
			table.insert(field_values,field)
		end

		fields_str = table.concat(field_values,",")
	end

	local cond_str = ""

	for cond_key,cond_val in pairs(cond or {}) do
		if cond_str == "" then
			cond_str = " WHERE "
		else
			cond_str = cond_str .. " and "
		end
		cond_str = cond_str..cond_key.." = "..cond_val
	end

	local select_sql_str = "SELECT "..fields_str.." FROM "..table_name..cond_str..";"

	local try_num = 10

	local result,effect_rows,datas = self:call_execute(select_sql_str)

	while result == false and try_num > 0 do
		skynet.sleep(1 * 100)
		try_num = try_num - 1
		result,effect_rows,datas = self.call_execute(select_sql_str)
	end

	local data = {}

	for _ ,v in pairs(datas or {}) do
		data = v
	end

	return data,result
end

function client_api:get_query(table_name,cond,fields,skip,number)
	local limit_str = ""

	if skip and number then
		limit_str = " limit "..skip..","..number
	end

	local field_str = ""
	if get_table_real_count(fields or {}) <= 0 then
		field_str = "*"
	else
		local field_values = {}
		for field,_ in pairs(fields) do
			table.insert(field_values,"`"..field.."`")
		end
		field_str = table.concat(field_values,",")
	end

	local cond_str = ""

	for cond_key,cond_val in pairs(cond or {}) do
		if cond_str == "" then
			cond_str = " WHERE "
		else
			cond_str = cond_str .. " and "
		end
		if type(cond_val) == "string" then
			cond_str = cond_str.."`"..cond_key.."`='"..cond_val.."'"
		else
			cond_str = cond_str.."`"..cond_key.."`="..cond_val
		end
	end

	local select_sql_str = "SELECT "..field_str.. " FROM `"..table_name.."`"..cond_str..limit_str..";"
	return select_sql_str
end

function client_api:query(table_name,cond,fields,skip,number)
	local select_sql_str = self:get_query(table_name,cond,fields,skip,number)
	local result,effect_rows,datas = self:call_execute(select_sql_str)
	return datas or {}
end

function client_api:batch_get(table_name,cond,fields)
	local fields_str = "*"
	if get_table_real_count(fields or {}) > 0 then
		local field_values = {}
		for field,_ in pairs(fields) do
			table.insert(field_values,field)
		end
		fields_str = table.concat(field_values,",")
	end

	local cond_str = ""

	for cond_key,cond_vals in pairs(cond or {}) do
		if cond_str == "" then
			cond_str = " where "
		else
			cond_str = cond_str .. " or "
		end

		local values_str = table.concat(cond_vals or {},",")
		cond_str = cond_str .. cond_key .. "in("..values_str..")"
	end

	local select_sql_str = "select "..fields_str .. " from " .. table_name .. cond_str .. ";"
	local result,effect_rows,datas = self:call_execute(select_sql_str)

	return datas or {}
end

function client_api:get_insert_m(table_name,table_data)
	local data_fields = {}
	local update_fields = {}

	local ar = {}
	assert(table_data[1], table_name)
	for field_name, _ in pairs(table_data[1]) do
		table.insert(ar, field_name)
		field_name="`"..field_name.."`"
		table.insert(data_fields, field_name)
		table.insert(update_fields, field_name.."=VALUES("..field_name..")")
	end

	local data_values = {}
	for _, datas in ipairs(table_data) do
		local data_value = {}
		for _, field_name in ipairs(ar) do
			local field_value = datas[field_name]
			local ttype = type(field_value)
			if ttype == "table" then
				local table_to_str = mysql_driver.pack_table(field_value)
				table.insert(data_value, "'"..table_to_str.."'")
			elseif ttype == "string" then
				field_value = self:escape_string(field_value)
				table.insert(data_value, "'"..field_value.."'")
			else
				table.insert(data_value, field_value)
			end
		end
		local str_values = "("..table.concat(data_value,",")..")"
		table.insert(data_values, str_values)
	end

	local str_values = table.concat(data_values,",")
	local str_update = table.concat(update_fields,",")..";"
	local insert_sql_str = "INSERT INTO `"..table_name .."` ("..table.concat(data_fields,",")..") VALUES "..str_values;
	insert_sql_str = insert_sql_str .. "ON DUPLICATE KEY UPDATE "..str_update;
	return insert_sql_str
end

function client_api:insert_m(table_name,table_data)
	local insert_sql_str = self:get_insert_m(table_name,table_data)
	local result,rows,data,insertId = self:call_execute(insert_sql_str)
	return result
end

function client_api:insert_ms(table_name,table_data)
	local insert_sql_str = self:get_insert_m(table_name,table_data)
	self:send_execute(insert_sql_str)
end

function client_api:get_insert(table_name,table_data)
	local data_fields = {}
	local data_values = {}

	for field_name,field_value in pairs(table_data) do
		table.insert(data_fields,"`"..field_name.."`")
		if type(field_value) == "table" then
			local table_to_str = mysql_driver.pack_table(field_value)
			table.insert(data_values,"'"..table_to_str.."'")
		elseif type(field_value) == "string" then
			field_value = self:escape_string(field_value)
			table.insert(data_values,"'"..field_value.."'")
		elseif type(field_value) == "boolean" then
			table.insert(data_values,(field_value and 1 or 0))
		else
			table.insert(data_values,field_value)
		end
	end

	local insert_sql_str = "INSERT INTO `"..table_name .."` ("..table.concat(data_fields,",")..") VALUES ("..table.concat(data_values,",") ..");"
	return insert_sql_str
end

function client_api:insert(table_name,table_data)
	local insert_sql_str = self:get_insert(table_name,table_data)
	local result,rows,data,insertId = self:call_execute(insert_sql_str)

	return result,insertId and math.floor(insertId) or 0
end

function client_api:insert_s(table_name,table_data)
	local insert_sql_str = self:get_insert(table_name,table_data)
	self:send_execute(insert_sql_str)
end

function client_api:get_delete(table_name,cond,only_one)
	local limit_str = ""

	local cond_str = ""

	if type(cond) == "string" then
		cond_str = " WHERE " .. cond
	else
		for cond_key,cond_val in pairs(cond or {}) do
			if cond_str == "" then
				cond_str = " WHERE "
			else
				cond_str = cond_str .. " and "
			end

			cond_str = cond_str.."`"..cond_key.."`='"..cond_val.."'"
		end
	end

	local delete_sql_str = "DELETE FROM `"..table_name.."`"..cond_str..limit_str..";"
	return delete_sql_str
end
function client_api:delete(table_name,cond,only_one)
	local delete_sql_str = self:get_delete(table_name,cond,only_one)
	self:send_execute(delete_sql_str)
end


function client_api:get_update(table_name,cond,data,upsert,ret)
	local limit_str = ""

	local cond_str = ""

	for cond_key,cond_val in pairs(cond or {}) do
		if cond_str == "" then
			cond_str = " WHERE "
		else
			cond_str = cond_str .. " and "
		end
		if type(cond_val) == "string" then
			cond_str = cond_str .. "`" .. cond_key .."`='" .. cond_val .. "'"
		else
			cond_str = cond_str .. "`" .. cond_key .."`=" .. cond_val
		end
	end

	local update_values = {}

	for field_name,field_value in pairs(data) do
		if type(field_value) == "table" then
			local table_to_str = mysql_driver.pack_table(field_value)
			table.insert(update_values, "`" .. field_name .. "`='"..table_to_str.."'")
		elseif type(field_value) == "string" then
			field_value = self:escape_string(field_value)
			table.insert(update_values, "`" .. field_name .. "`='"..field_value.."'")
		elseif type(field_value) == "boolean" then
			table.insert(update_values, "`" .. field_name .. "`=" .. (field_value and 1 or 0))
		else
			table.insert(update_values, "`" .. field_name .. "`=" .. field_value)
		end
	end

	local update_sql_str = "UPDATE `"..table_name.."` SET "..table.concat(update_values,",")..cond_str..limit_str..";"
	return update_sql_str
end

function client_api:update(table_name,cond,data,upsert,ret)
	local update_sql_str = self:get_update(table_name,cond,data,upsert,ret)
	if upsert == true then
		local result,effect_rows,datas = self:call_execute(update_sql_str)
		if effect_rows <= 0 then
			for field,value in pairs(cond) do
				data[field] = value
			end

			self:insert(table_name,data)
		end
	else
		if ret then
			self:call_execute(update_sql_str)
		else
			self:send_execute(update_sql_str)
		end
	end
end

function client_api:set(table_name,cond,data,upsert,multi)
	self:update(table_name,cond,data,upsert,multi)
end

return api
