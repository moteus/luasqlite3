local sqlite3 = require "lsqlite3.core"
local table = require "table"

local sqlite3_db
local sqlite3_stmt

do  -- get mt
local db = sqlite3:open_memory()
local stmt = db:prepare("select 1")
sqlite3_db = getmetatable(db)
sqlite3_stmt = getmetatable(stmt)
stmt:finalize()
db:close()
end

local function pack_res(...) return {...}, select('#', ...) end

local unpack = unpack or table.unpack

local function first_row(stmt, get_row_func, autoclose)

  local status = stmt:step()

  if status == sqlite3.ROW then
    local argv, argc = pack_res( get_row_func(stmt) )
    if autoclose then stmt:finalize() else stmt:reset() end
    return unpack(argv, argc)
  end

  if status == sqlite3.DONE then
    if autoclose then stmt:finalize() else stmt:reset() end
    return nil, "No row returned."
  end

  if status == sqlite3.ERROR then
    local errmsg = db:error_message()
    if autoclose then stmt:finalize() else stmt:reset() end
    return nil, errmsg
  end

  if (status == sqlite3.BUSY) or (status == sqlite3.MISUSE) then
    if autoclose then stmt:finalize() else stmt:reset() end
    return nil, status
  end

  if autoclose then stmt:finalize() else stmt:reset() end
  return nil, "stmt:first_row: Internal error!"
end

local function get_nrow(stmt)
  local row, err = stmt:get_values()
  if not row then return nil, err end
  local names, err = stmt:get_names()
  if not names then return nil, err end
  local res = {}
  for i,name in ipairs(names) do 
    res[name] = row[i]
  end
  return res
end

function sqlite3_db:first_row(sql)
  local stmt, err = db:prepare(sql)
  if not stmt then return nil, err end
  return first_row(stmt, stmt.get_values, true)
end

function sqlite3_db:first_urow(sql)
  local stmt, err = db:prepare(sql)
  if not stmt then return nil, err end
  return first_row(stmt, stmt.get_uvalues, true)
end

function sqlite3_db:first_nrow(sql)
  local stmt, err = db:prepare(sql)
  if not stmt then return nil, err end
  return first_row(stmt, get_nrow, true)
end

function sqlite3_stmt:first_row()
  self:reset()
  return first_row(self, self.get_values, false)
end

function sqlite3_stmt:first_urow()
  self:reset()
  return first_row(self, self.get_uvalues, false)
end

function sqlite3_stmt:first_nrow()
  self:reset()
  return first_row(self, get_nrow, false)
end

return sqlite3