

if not ngx then
  ngx = {
    log = print,
    ERR = 0,
    INFO = 0,
    WARN = 0
  }
end


local log  = ngx.log
local ERR  = ngx.ERR
local INFO = ngx.INFO
local WARN = ngx.WARN

local _M = {}


local function file_exists(file)
  	local f = io.open(file, "rb")
  
  	if f then 
  		f:close()
  	end
  
  	return f ~= nil
end

function _M.file_get_lines(file)
  	if not file_exists(file) then
  		return nil, 'File does not exist'
  	end

  	local lines = {}
  
  	for line in io.lines(file) do 
    	lines[#lines + 1] = line
  	end

  	return lines
end

function _M.log_info(...)
    log(INFO, "imaging: ", ...)
end

function _M.log_warn(...)
    log(WARN, "imaging: ", ...)
end

function _M.log_error(...)
    log(ERR, "imaging: ", ...)
end

return _M