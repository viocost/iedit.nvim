local M = {}
function M.find_next(buf, pos, text)
	if #text == 1 then
		for row, line in ipairs(vim.api.nvim_buf_get_lines(buf, pos[1], -1, true)) do
			local start_col, end_col
			if row == 1 then
				start_col, end_col = vim.fn.getline(pos[1] + 1):find(text[1], pos[2] + 1, true)
			else
				start_col, end_col = line:find(text[1], 1, true)
			end
			if start_col then
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
			if not lines[row + trow - 1] or not lines[row + trow - 1]:find(tline, trow == 1 and pos[2] + 1 or 1) then
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

	while true do
		local range = M.find_next(buf, pos, text)
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
