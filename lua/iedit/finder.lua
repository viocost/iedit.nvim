local M = {}
local util = require("iedit.util")

function M.find_next(buf, pos, text, lock_to_keyword)
	lock_to_keyword = lock_to_keyword ~= false -- true by default

	local function is_keyword_match(line, start_col, end_col)
		if not lock_to_keyword then
			return true
		end
		local expanded = util.expand(line, 0, start_col)

		if expanded == nil then
			error("Could not expand the keyword")
		end

		return expanded[2] == start_col - 1 and expanded[4] == end_col
	end

	if #text == 1 then
		for row, line in ipairs(vim.api.nvim_buf_get_lines(buf, pos[1], -1, true)) do
			local start_col, end_col
			if row == 1 then
				start_col, end_col = vim.fn.getline(pos[1] + 1):find(text[1], pos[2] + 1, true)
			else
				start_col, end_col = line:find(text[1], 1, true)
			end

			if start_col and is_keyword_match(line, start_col, end_col) then
				return { row + pos[1] - 1, start_col - 1, row + pos[1] - 1, end_col }
			end
		end
		return
	end

	local lines = vim.api.nvim_buf_get_lines(buf, pos[1], -1, true)
	for row, _ in ipairs(lines) do
		local flag = true
		for trow, tline in ipairs(text) do
			tline = vim.pesc(tline)
			if trow ~= 1 then
				tline = "^" .. tline
			end
			if trow ~= #text then
				tline = tline .. "$"
			end
			local current_line = lines[row + trow - 1]
			if not current_line then
				flag = false
				break
			end
			local start_col, end_col = current_line:find(tline, trow == 1 and pos[2] + 1 or 1)
			if not start_col or (trow == 1 and not is_keyword_match(current_line, start_col, end_col)) then
				flag = false
				break
			end
		end
		if flag then
			return { row + pos[1] - 1, #lines[row] - #text[1], row + pos[1] + #text - 2, #text[#text] }
		end
	end
end

function M.find_all_ocurances(buf, text, curpos)
	local pos = { 0, 0 }
	local ranges = {}
	local closest_index = 1
	local min_distance = math.huge

	local lock_to_keyword = vim.fn.mode() ~= "v" and vim.fn.mode() ~= "V"

	while true do
		local range = M.find_next(buf, pos, text, lock_to_keyword)
		if range == nil then
			break
		end

		table.insert(ranges, range)

		if curpos then
			local distance = math.abs(range[1] - curpos[1]) * 1000 + math.abs(range[2] - curpos[2])
			if distance < min_distance then
				min_distance = distance
				closest_index = #ranges
			end
		end

		pos = { range[3], range[4] }
	end

	return ranges, closest_index
end
return M
