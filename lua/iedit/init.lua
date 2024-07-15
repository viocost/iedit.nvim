local M = {}

M.original_keymaps = {}

M.default_config = {
	select = {
		map = setmetatable({
			q = { "done" },
			["<Esc>"] = { "select", "done" },
			["<CR>"] = { "toggle" },
			n = { "toggle", "next" },
			p = { "toggle", "prev" },
			N = { "next" },
			P = { "prev" },
			a = { "all" },
			--u={'unselect'},
		}, {
			__t = true --[[Don't merge subsequent tables]],
		}),
		highlight = {
			current = "CurSearch",
			selected = "Search",
		},
	},
	highlight = "IncSearch",
	current_highlight = "PmenuSel",
}

M.config = vim.deepcopy(M.default_config)

function M.set_iedit_keymaps(buf)
	-- Store original mappings
	M.original_keymaps["n"] = vim.api.nvim_buf_get_keymap(buf, "n")
	M.original_keymaps["v"] = vim.api.nvim_buf_get_keymap(buf, "v")

	-- Set new mappings for 'n', 'p', etc.
	vim.api.nvim_buf_set_keymap(
		buf,
		"n",
		"n",
		[[<cmd>lua require'iedit'.goto_next_occurrence()<CR>]],
		{ noremap = true, silent = true }
	)
	vim.api.nvim_buf_set_keymap(
		buf,
		"n",
		"N",
		[[<cmd>lua require'iedit'.goto_prev_occurrence()<CR>]],
		{ noremap = true, silent = true }
	)
	-- Add more mappings as needed
end
function M.restore_original_keymaps(buf)
	-- Clear iedit-specific mappings
	vim.api.nvim_buf_del_keymap(buf, "n", "n")
	vim.api.nvim_buf_del_keymap(buf, "n", "N")
	-- Add more as needed

	-- Restore original mappings
	for _, keymap in ipairs(M.original_keymaps["n"]) do
		vim.api.nvim_buf_set_keymap(buf, "n", keymap.lhs, keymap.rhs or "", {
			silent = keymap.silent == 1,
			noremap = keymap.noremap == 1,
			expr = keymap.expr == 1,
			nowait = keymap.nowait == 1,
		})
	end
	-- Do the same for 'v' mode if needed
end

function M.goto_next_occurrence()
	local iedit_module = require("iedit.iedit")
	local buf = vim.api.nvim_get_current_buf()
	if not vim.b[buf].iedit_mode then
		return
	end

	local marks = vim.b[buf].iedit_data[tostring(iedit_module.id - 1)]
	if not marks or #marks == 0 then
		return
	end

	-- Reset highlight of the previous current node
	if M.current_index then
		local prev_mark_id = marks[M.current_index]
		iedit_module.update_extmark_highlight(buf, prev_mark_id, M.config.highlight)
	end

	M.current_index = M.current_index or 1
	M.current_index = (M.current_index % #marks) + 1
	local mark_id = marks[M.current_index]

	-- Set highlight of the new current node
	iedit_module.update_extmark_highlight(buf, mark_id, M.config.current_highlight)

	local pos = iedit_module.mark_id_to_range(buf, mark_id)
	vim.api.nvim_win_set_cursor(0, { pos[1] + 1, pos[2] })
end

function M.goto_prev_occurrence()
	local iedit_module = require("iedit.iedit")
	local buf = vim.api.nvim_get_current_buf()
	if not vim.b[buf].iedit_mode then
		return
	end

	local marks = vim.b[buf].iedit_data[tostring(iedit_module.id - 1)]
	if not marks or #marks == 0 then
		return
	end

	-- Reset highlight of the previous current node
	if M.current_index then
		local prev_mark_id = marks[M.current_index]
		iedit_module.update_extmark_highlight(buf, prev_mark_id, M.config.highlight)
	end

	M.current_index = M.current_index or 1
	M.current_index = ((M.current_index - 2 + #marks) % #marks) + 1
	local mark_id = marks[M.current_index]

	-- Set highlight of the new current node
	iedit_module.update_extmark_highlight(buf, mark_id, M.config.current_highlight)

	local pos = iedit_module.mark_id_to_range(buf, mark_id)
	vim.api.nvim_win_set_cursor(0, { pos[1] + 1, pos[2] })
end

function M.exit_iedit_mode(buf)
	vim.b[buf].iedit_mode = false
	M.restore_original_keymaps(buf)
	M.current_index = nil
end

function M.enter_iedit_mode(buf, ranges, initial_index)
	vim.b[buf].iedit_mode = true
	M.set_iedit_keymaps(buf)
	M.current_index = initial_index or 1 -- Use the provided initial index or default to 1
	local iedit_module = require("iedit.iedit")
	iedit_module.start(ranges, M.config)

	-- Set highlight of the initial current node
	local marks = vim.b[buf].iedit_data[tostring(iedit_module.id - 1)]
	if marks and #marks > 0 then
		local mark_id = marks[M.current_index]
		iedit_module.update_extmark_highlight(buf, mark_id, M.config.current_highlight)

		-- Move cursor to the current occurrence
		local pos = iedit_module.mark_id_to_range(buf, mark_id)
		vim.api.nvim_win_set_cursor(0, { pos[1] + 1, pos[2] })
	end
end

local function merge(origin, new, _not_table, _opt_path)
	_opt_path = _opt_path or "config"
	if origin == nil and new ~= nil then
		error(("\n\n\n" .. [[
        Configuration for the plugin 'iedit' is incorrect.
        The option `%s` is set to `%s`, but it should be `nil` (e.g. not set).
        ]] .. "\n"):format(_opt_path, vim.inspect(new)))
	elseif new ~= nil and type(origin) ~= type(new) then
		error(("\n\n\n" .. [[
        Configuration for the plugin 'iedit' is incorrect.
        The option `%s` has the value `%s`, which has the type `%s`.
        However, that option should have the type `%s` (or `nil`).
        ]] .. "\n"):format(_opt_path, vim.inspect(new), type(new), type(origin)))
	end
	if _not_table or (type(origin) ~= "table" and type(new) ~= "table") then
		return vim.F.if_nil(new, origin)
	end
	if new == nil then
		return origin
	end
	if not origin or new.merge == false then
		return new
	end
	local keys = vim.defaulttable(function()
		return {}
	end)
	for k, v in pairs(origin) do
		keys[k][1] = v
	end
	for k, v in pairs(new) do
		keys[k][2] = v
	end
	local ret = {}
	for k, v in pairs(keys) do
		ret[k] = merge(v[1], v[2], (getmetatable(origin[k]) or {}).__t, _opt_path .. "." .. k)
	end
	return ret
end

function M.setup(config)
	if config ~= nil and type(config) ~= "table" then
		error(("\n\n\n" .. [[
        Configuration for the plugin 'iedit' is incorrect.
        The configuration is `%s`, which has the type `%s`.
        However, the configuration should be a table.
        ]] .. "\n"):format(vim.inspect(config), type(config)))
	end
	merge(M.default_config, config)
end

function M.select(_opts)
	_opts = _opts or {}
	M.stop()
	local range = {}
	local cursor_pos
	if vim.fn.mode() == "n" then
		local line = vim.fn.getline(".")
		local col = vim.fn.col(".")
		local row = vim.fn.line(".") - 1
		cursor_pos = { row, col - 1 } -- Store cursor position
		local regex = vim.regex([[\k]])
		range = { row, nil, row, nil }
		while not regex:match_str(line:sub(col, col)) do
			col = col + 1
			if #line < col then
				vim.notify("No word under (or after) cursor", vim.log.levels.WARN)
				return
			end
		end
		while regex:match_str(line:sub(col + 1, col + 1)) do
			col = col + 1
		end
		range[4] = col
		while regex:match_str(line:sub(col, col)) do
			col = col - 1
		end
		range[2] = col
	elseif vim.fn.mode() == "v" or vim.fn.mode() == "V" then
		local pos1 = vim.fn.getpos("v")
		local pos2 = vim.fn.getpos(".")
		if pos1[2] > pos2[2] or (pos1[2] == pos2[2] and pos1[3] > pos2[3]) then
			pos1, pos2 = pos2, pos1
		end
		range = { pos1[2] - 1, pos1[3] - 1, pos2[2] - 1, pos2[3] }
		cursor_pos = { pos2[2] - 1, pos2[3] - 1 } -- Store cursor position
		vim.cmd.norm({ "\x1b", bang = true })
	else
		error(("mode `%s` not supported"):format(vim.fn.mode()))
	end
	local ranges, initial_index
	if _opts.all then
		local text = vim.api.nvim_buf_get_text(0, range[1], range[2], range[3], range[4], {})
		if #text == 1 and text[1] == "" then
			vim.notify("No text selected", vim.log.levels.WARN)
			return
		end
		ranges, initial_index = require("iedit.finder").find_all_ocurances(0, text, cursor_pos)
	else
		ranges, initial_index = require("iedit.selector").start(range, M.config.select, cursor_pos)
	end

	local buf = vim.api.nvim_get_current_buf()
	M.enter_iedit_mode(buf, ranges, initial_index)
end

function M.select_all()
	M.select({ all = true })
end

function M.stop(id, buf)
	local ns = require("iedit.iedit").ns
	buf = buf or 0
	local data = vim.b[buf].iedit_data or {}
	local ids
	if id then
		ids = { [tostring(id)] = data[tostring(id)] }
	else
		ids = data
	end
	for key, marks in pairs(ids) do
		for _, mark_id in ipairs(marks ~= vim.NIL and marks or {}) do
			pcall(vim.api.nvim_buf_del_extmark, buf, ns, mark_id)
		end
		data[key] = nil
	end
	vim.b[buf].iedit_data = data
	-- Exit iedit mode
	if vim.b[buf].iedit_mode then
		M.exit_iedit_mode(buf)
	end
end

function M.toggle(_opts)
	if vim.tbl_isempty(vim.b.iedit_data or {}) then
		M.select(_opts)
	else
		M.stop()
	end
end

return M
