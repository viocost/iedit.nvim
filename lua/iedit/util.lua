local M = {}

function M.get_visual_selection()
	local range = {}
	local pos1 = vim.fn.getpos("v")
	local pos2 = vim.fn.getpos(".")
	if pos1[2] > pos2[2] or (pos1[2] == pos2[2] and pos1[3] > pos2[3]) then
		pos1, pos2 = pos2, pos1
	end
	range = { pos1[2] - 1, pos1[3] - 1, pos2[2] - 1, pos2[3] }

	return range
end

function M.get_keyword_range(line, row, col)
	local range = {}

	local regex = vim.regex([[\k]])
	range = { row, nil, row, nil }

	-- when we are at empty space or non-keyword char -> skip forward until find somthing or until we reach end of the line
	while not regex:match_str(line:sub(col, col)) do
		col = col + 1
		if #line < col then
			vim.notify("No word under or after cursor", vim.log.levels.WARN)
			return
		end
	end

	-- capturing the keyword foward til it ends
	while regex:match_str(line:sub(col + 1, col + 1)) do
		col = col + 1
	end
	range[4] = col

	-- capturing the keyword backward until we get to the beginnning of the keyword
	while regex:match_str(line:sub(col, col)) do
		col = col - 1
	end

	range[2] = col

	return range
end

return M
