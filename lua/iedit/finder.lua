local M = {}
local util = require("iedit.util")

function M.find_next(buf, pos, text, lock_to_keyword)
	lock_to_keyword = lock_to_keyword ~= false -- true by default

	local function is_keyword_match(line, start_col, end_col)
		if not lock_to_keyword then
			return true
		end
		local expanded = util.get_keyword_range(line, start_col, start_col) or {}
		return expanded[2] == start_col - 1 and expanded[4] == end_col
	end

	if #text == 1 then
		for row, line in ipairs(vim.api.nvim_buf_get_lines(buf, pos[1], -1, true)) do
			local search_start = row == 1 and pos[2] + 1 or 1
			while true do
				local start_col, end_col = line:find(text[1], search_start, true)
				if not start_col then
					break
				end
				if is_keyword_match(line, start_col, end_col) then
					return { row + pos[1] - 1, start_col - 1, row + pos[1] - 1, end_col }
				end
				search_start = end_col + 1
			end
		end
		return
	end

	local lines = vim.api.nvim_buf_get_lines(buf, pos[1], -1, true)
	for row, _ in ipairs(lines) do
		local search_start = row == 1 and pos[2] + 1 or 1
		while true do
			local flag = true
			local match_start, match_end

			for trow, tline in ipairs(text) do
				local current_line = lines[row + trow - 1]
				if not current_line then
					flag = false
					break
				end

				local tline_pattern = vim.pesc(tline)
				if trow ~= 1 then
					tline_pattern = "^" .. tline_pattern
				end
				if trow ~= #text then
					tline_pattern = tline_pattern .. "$"
				end

				local start_col, end_col = current_line:find(tline_pattern, trow == 1 and search_start or 1)
				if not start_col or (trow == 1 and not is_keyword_match(current_line, start_col, end_col)) then
					flag = false
					break
				end

				if trow == 1 then
					match_start, match_end = start_col, end_col
				end
			end

			if flag then
				return { row + pos[1] - 1, match_start - 1, row + pos[1] + #text - 2, #text[#text] }
			end

			if not match_start then
				break
			end
			search_start = match_end + 1
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
		print("Found range: ", vim.inspect(range))
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
