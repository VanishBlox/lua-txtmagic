local TXTMAGIC = {
	ENUMS = {
		FILE_HANDLER_MODES = {
			READ = "r",
			APPEND = "a",
			OVERWRITE_AND_REPLACE = "w",	
		}
		READ_RESULT_FORMAT = {
			LINES = "l",
			STRING = "s",
		}
	}
}

local function errorHandler(name, error_string, method)
	method = method or ""
	error('Handler ("'..name..'") ran into an error on '..method..'\nError: '..error_string)
end

local FILE_HANDLER_TEMPLATE  = {
	NAME = "",
	PATH = "",
	MODE = "",
	FILE_READ_OBJECT,
	FILE_OBJECT, 
	IS_HANDLER_ACTIVE = false
	close = function(self)
		if not IS_HANDLER_ACTIVE then errorHandler(self.NAME, "Handler inactivated", ":close()") end

		if self.MODE ~= TXTMAGIC.ENUMS.FILE_HANDLER_MODES.READ then
			self.FILE_OBJECT:close()
		end
		self.FILE_READ_OBJECT:close()
		self.IS_HANDLER_ACTIVE = false
	end,
	read = function(self, instruction_expression, read_result_type)
		if not IS_HANDLER_ACTIVE then errorHandler(self.NAME, "Handler inactivated", ':read("'..instruction_expression..'")') end
		if not instruction_expression or type(instruction_expression) ~= "string" then 
			errorHandler(self.NAME, "instruction_expression can not be nil or is not a string", ':read("'..instruction_expression..'")')
		elseif instruction_expression == "" then
			errorHandler(self.NAME, "instruction_expression can not be an empty string", ':read("'..instruction_expression..'")')
		elseif instruction_expression:find("[^%d%.L%[%]%-%+%*]") then
			errorHandler(self.NAME, "instruction_expression contains illegal character at "..instruction_expression:find("[^%d%.L%[%]%-%+%*]"), ':read("'..instruction_expression..'")')
		end
		if not IS_HANDLER_ACTIVE then errorHandler(self.NAME, "Handler inactivated", ':read("'..instruction_expression..'")') end

		local ReturnResult;
		local IsIEaSequence = ({["nil"] = true})[tostring(instruction_expression:find("[%[%]]"))] or false
		local function readRange(range_expression)
			if range_expression == "" then errorHandler(self.NAME,'Empty Range Expression! -> "'..instruction_expression..'"', ':read("'..instruction_expression..'")') end
			
			local ReturnRangeRead = ""
			local RangeStart, RangeEnd = 0,0
			local function grabLine(new_line_index) end
			local CompleteFileRead do
				if range_expression:find("[L%.%+%-]") then
					self.FILE_READ_OBJECT:seek("set", 0)
					CompleteFileRead = self.FILE_READ_OBJECT:read("*a")
					grabLine = function(new_line_index)
						local Start, End = 0,0
						local IndexTracker = 0
						for match in CompleteFileRead:gmatch(".+\n?")
							IndexTracker = IndexTracker + 1
							if IndexTracker == new_line_index then
								Start, End = CompleteFileRead:find(match)
								break
							end
						end
						return Start, End
					end
				end
			end

			self.FILE_READ_OBJECT:seek("set", 0) -- reset seeker in case of a complete file read before (or just generally)
			if range_expression:find("%.") then
				ReturnRangeRead = CompleteFileRead
			elseif range_expression:find("%d") then
				local Matches = {}
				for Match in range_expression:gmatch("L?%d+[%*%-%+]?[%*%-%+]?") do -- Tokenize the Range
					table.insert( Matches, Match)
				end
				if #Matches > 1 and not Matches[1]:find("[%-%+]") then
					errorHandler(self.NAME, 'Range Scope defintion illegal! Weird */L in between your digits. -> "['..range_expression..']"', ':read("'..instruction_expression..'")')
				end
				if range_expression:match("%d+L?") then
					errorHandler(self.NAME, 'Line identifier always comes before the Refrence Number. -> "'..range_expression:match("%d+L?")..'" in "['..range_expression..']"', ':read("'..instruction_expression..'")')
				end
				if Match[1]:find("%-") and Match[1]:find("%+") then
					errorHandler(self.NAME, 'You can\'t have a (-) combined with (+) in a Range expression. -> "['..range_expression..']"', ':read("'..instruction_expression..'")') 
				end

				local Cache = {
					IsFirstMatchALine = ({["nil"] = true})[tostring(Matches[1]:find("L"))] or false,
					IsSecondMatchALine = nil,
					DigitsOfFirstMatch = tonumber(Matches[1]:match("%d+"))
					DigitsOfSecondMatch = nil,
				}

				if #Matches == 1 then
					local Match = Matches[1]
					if Cache.IsFirstMatchALine then
						local LineStart, LineEnd = grabLine(Cache.DigitsOfFirstMatch)
						
						if not Match:find("[%-%+%*]") then
							RangeStart, RangeEnd = LineStart, LineEnd
						elseif Match:find("%+") then
							if Match:find("%*") then 
								RangeStart = LineStart
							else
								RangeStart = LineEnd+1
							end
							RangeEnd = #CompleteFileRead
						elseif Match:find("%-") then
							if Match:find("%*") then 
								RangeEnd = LineEnd
							else
								RangeEnd = LineStart-1
							end
						end
					else -- Character refrence as Range pin
						local CharacterIndex = Cache.DigitsOfFirstMatch
						if not Match:find("[%-%+%*]") then
							RangeStart, RangeEnd = CharacterIndex, CharacterIndex
						elseif Match:find("%+") then
							if Match:find("%*") then 
								RangeStart = CharacterIndex
							else
								RangeStart = CharacterIndex+1 
							end
							RangeEnd = #CompleteFileRead
						elseif Match:find("%-") then
							if Match:find("%*") then 
								RangeEnd = CharacterIndex
							else
								RangeEnd = CharacterIndex-1
							end
						end
					end
				else
					local RangeHeadRefrence, RangeTailRefrence = Matches[1], Matches[2]
					Cache.IsSecondMatchALine = ({["nil"] = true})[tostring(Matches[2]:find("L"))] or false
					Cache.DigitsOfSecondMatch = tonumber(Matches[2]:find("%d+"))
					Cache.IsSecondMatchAnchored = ({["nil"] = true})[tostring(Matches[2]:find("%*"))] or false

					if RangeHeadRefrence:find("%+") then
						if Cache.IsFirstMatchALine or Cache.IsSecondMatchALine then
							if Cache.IsFirstMatchALine then
								local LineEnd, LineStart = grabLine(Cache.DigitsOfFirstMatch)
								if RangeHeadRefrence:find("%*") then
									RangeStart = LineStart
								else
									RangeStart = LineEnd+1
								end
							elseif not Cache.IsFirstMatchALine then
								RangeStart = Cache.DigitsOfFirstMatch
								if not RangeHeadRefrence:find("%*") then
									RangeStart = RangeStart+1
								end
							end
							if Cache.IsSecondMatchALine then
								local LineEnd, LineStart = grabLine(Cache.DigitsOfSecondMatch)
								if RangeTailRefrence:find("%*") then
									RangeEnd = LineEnd
								else
									RangeEnd = LineStart-1
								end
							elseif not Cache.IsSecondMatchALine then
								RangeEnd = Cache.DigitsOfSecondMatch
								if not RangeTailRefrence:find("%*") then
									RangeStart = RangeStart-1
								end
							end
						else -- Both are Character refrences
							RangeStart = Cache.DigitsOfFirstMatch
							if not RangeHeadRefrence:find("%*") then
								RangeStart = RangeStart+1
							end
							RangeEnd = Cache.DigitsOfSecondMatch
							if not RangeTailRefrence:find("%*") then
								RangeStart = RangeStart-1
							end
						end
					elseif RangeHeadRefrence:find("%-") then
						if Cache.IsFirstMatchALine or Cache.IsSecondMatchALine then
							if Cache.IsFirstMatchALine then
								local LineEnd, LineStart = grabLine(Cache.DigitsOfFirstMatch)
								if RangeHeadRefrence:find("%*") then
									RangeEnd = LineEnd
								else
									RangeEnd = LineStart-1
								end
							elseif not Cache.IsFirstMatchALine then
								RangeEnd = Cache.DigitsOfFirstMatch
								if not RangeHeadRefrence:find("%*") then
									RangeEnd = RangeEnd-1
								end
							end
							if Cache.IsSecondMatchALine then
								local LineEnd, LineStart = grabLine(Cache.DigitsOfSecondMatch)
								if RangeTailRefrence:find("%*") then
									RangeStart = LineStart
								else
									RangeStart = LineEnd+1
								end
							elseif not Cache.IsSecondMatchALine then 
								RangeStart = Cache.DigitsOfSecondMatch
								if not RangeTailRefrence:find("%*") then
									RangeStart = RangeStart+1
								end
							end
						else -- Both are Character refrences
							RangeStart = Cache.DigitsOfSecondMatch
							if not RangeTailRefrence:find("%*") then
								RangeStart = RangeStart+1
							end
							RangeEnd = Cache.DigitsOfFirstMatch
							if not RangeHeadRefrence:find("%*") then
								RangeEnd = RangeEnd-1
							end
						end
					end	
				end

				if RangeEnd < 0 then RangeEnd = 0 end 
				if RangeStart < RangeEnd then
					errorHandler(self.NAME, 'You broke the ranges, I can\'t read backwards:( -> "['..range_expression..']" -> RangeStart: '..tostring(RangeStart)..", RangeEnd: "..tostring(RangeEnd), ':read("'..instruction_expression..'")')
				end
				-- implement reader
				if CompleteFileRead == nil then
					local SeekSet = RangeStart
					if SeekSet > 0 then SeekSet = SeekSet - 1 end
					self.FILE_READ_OBJECT:seek("set", SeekSet)
					CompleteFileRead = self.FILE_READ_OBJECT:read("*a")
				end
				ReturnRangeRead = CompleteFileRead:sub(RangeStart, RangeEnd)
			else
				errorHandler('Range Scope defintion illegal! -> "['..range_expression..']"')
			end
			
			return ReturnRangeRead
		end

		local StringifiedResult do 
			if IsIEaSequence then
				local Ranges = {}
				StringifiedResult = ""
				for range in instruction_expression:gmatch("%[.+%]") then
					table.insert(Ranges, range)
				end
				if #Ranges == 0 then errorHandler(self.NAME, "No valid range(s) found", ':read("'..instruction_expression'")')
				for range in ipairs(Ranges) do
					StringifiedResult..readRange(range)
				end
			else
				ReturnResult = readRange(instruction_expression:match("L?%d+[%*%-%+]?[%*%-%+]?"))
			end
		end

		if read_result_type == TXTMAGIC.ENUMS.READ_RESULT_FORMAT.LINES then
			ReturnResult = {}
			for line in StringifiedResult:gmatch(".+\n?") do
				table.insert( ReturnResult, line)
			end
		end

		return ReturnResult
	end,
}

TXTMAGIC.instanceFileHandler = function(HANDLER_MODE_ENUM, PATH, NAME) -- full explicit PATH allows Lua to interpret successfuly from anywhere on the system
	if ENUMS.FILE_HANDLER_MODES[HANDLER_MODE_ENUM] then
		
	else -- HANDLER_MODE argument is non-vaild 
		error("HANDLER_MODE is unknown (not an ENUM of FILE_HANDLER_MODES)")
	end
end

return TXTMAGIC