local FILE_HANDLER  = {
	PATH = "",
	MODE = "",
	FILE_OBJECT, 
	close = function(self)
		self.FILE_OBJECT:close()
	end,
}

local function replace() -- current line, current line and after, current line and before
local function insert() -- at line, after line, before line

return {
	ENUMS = {
		FILE_HANDLER_MODES = {
			READ_ONLY = "r",
			APPEND_ONLY = "a",
			READ_WRITE = "r+",	
		}
	}
	instanceFileHandler = function(HANDLER_MODE_ENUM, PATH) -- full explicit PATH allows Lua to interpret successfuly from anywhere on the system
		if ({"r", "a", "r+"})[HANDLER_MODE_ENUM] then
			
		else -- HANDLER_MODE argument is non-vaild 
			error("HANDLER_MODE is unknown (not an ENUM of FILE_HANDLER_MODES)")
		end
	end,
}