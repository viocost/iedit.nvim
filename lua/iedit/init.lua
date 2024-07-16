local M = {}
local util = require("iedit.util")

M.original_keymaps = {}

local function setup_highlights()
	vim.api.nvim_set_hl(0, "IeditSelect", {

		link = "IncSearch", -- Link to the Visual highlight group
	})

	vim.api.nvim_set_hl(0, "IeditCurrent", {
		fg = "#000000",
		bg = "#dd63ff",
	})
end

setup_highlights()

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
	highlight = "IeditSelect",
	current_highlight = "IeditCurrent",
}

M.config = vim.deepcopy(M.default_config)

function M.set_iedit_keymaps(buf)
	-- Store original mappings for specific keys
	M.original_keymaps = {}
	local keys_to_override = { "n", "N", "t" }
	for _, key in ipairs(keys_to_override) do
		local existing_keymap = vim.api.nvim_buf_get_keymap(buf, "n")[key]
		if existing_keymap and #existing_keymap > 0 then
			M.original_keymaps[key] = existing_keymap[1]
		end
	end

	-- Set new mappings for 'n' and 'N'
	vim.api.nvim_buf_set_keymap(
		buf,
		"n",
		"n",
		[[<cmd>lua require'iedit'.step()<CR>]],
		{ noremap = true, silent = true }
	)
	vim.api.nvim_buf_set_keymap(
		buf,
		"n",
		"N",
		[[<cmd>lua require'iedit'.step({back=true})<CR>]],
		{ noremap = true, silent = true }
	)
	vim.api.nvim_buf_set_keymap(
		buf,
		"n",
		"t",
		[[<cmd>lua require'iedit'.toggle_single()<CR>]],
		{ noremap = true, silent = true }
	)
end

function M.restore_original_keymaps(buf)
	-- Clear iedit-specific mappings
	vim.api.nvim_buf_del_keymap(buf, "n", "n")
	vim.api.nvim_buf_del_keymap(buf, "n", "N")

	-- Restore original mappings for specific keys
	for key, keymap in pairs(M.original_keymaps) do
		vim.api.nvim_buf_set_keymap(buf, "n", key, keymap.rhs or "", {
			silent = keymap.silent == 1,
			noremap = keymap.noremap == 1,
			expr = keymap.expr == 1,
			nowait = keymap.nowait == 1,
		})
	end

	-- Clear the stored original keymaps
	M.original_keymaps = {}
end

function M.step(args)
	args = args or {}
	local back = args.back or false

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
	if back then
		M.current_index = ((M.current_index - 2 + #marks) % #marks) + 1
	else
		M.current_index = (M.current_index % #marks) + 1
	end

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

local function merge_config(origin, new, _not_table, _opt_path)
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
		ret[k] = merge_config(v[1], v[2], (getmetatable(origin[k]) or {}).__t, _opt_path .. "." .. k)
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
	merge_config(M.default_config, config)
end

function M.select(_opts)
	_opts = _opts or {}
	M.stop()

	local cursor_pos

	local line = vim.fn.getline(".") -- content of the current line
	local col = vim.fn.col(".") -- number of current column where cursor is
	local row = vim.fn.line(".") - 1 -- number of current row where cursor is
	cursor_pos = { row, col - 1 } -- Store cursor position

	local range

	if vim.fn.mode() == "n" then
		range = util.expand(line, row, col)
	elseif vim.fn.mode() == "v" or vim.fn.mode() == "V" then
		range = util.get_visual_selection()
	else
		error(("mode `%s` not supported"):format(vim.fn.mode()))
	end

	if range == nil then
		error("Could not obtain range")
	end

	local ranges, initial_index

	if _opts.all then
		local text = vim.api.nvim_buf_get_text(0, range[1], range[2], range[3], range[4], {})
		if #text == 1 and text[1] == "" then
			vim.notify("No text selected", vim.log.levels.WARN)

			vim.cmd.norm({ "\x1b", bang = true })
			return
		end
		ranges, initial_index = require("iedit.finder").find_all_ocurances(0, text, cursor_pos)
	else
		ranges, initial_index = require("iedit.selector").start(range, M.config.select, cursor_pos)
	end

	vim.cmd.norm({ "\x1b", bang = true })
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

function M.toggle_single()
	local buf = vim.api.nvim_get_current_buf()
	local cursor_pos = vim.api.nvim_win_get_cursor(0)
	local cursor_row, cursor_col = cursor_pos[1] - 1, cursor_pos[2]
	local line = vim.api.nvim_buf_get_lines(buf, cursor_row, cursor_row + 1, false)[1]

	if vim.b[buf].iedit_mode then
		-- We're in iedit mode
		local iedit_module = require("iedit.iedit")
		local marks = vim.b[buf].iedit_data[tostring(iedit_module.id - 1)]

		if not marks or #marks == 0 then
			return
		end

		local matching_mark_index = nil
		for i, mark_id in ipairs(marks) do
			local pos = iedit_module.mark_id_to_range(buf, mark_id)
			if cursor_row == pos[1] and cursor_col >= pos[2] and cursor_col < pos[4] then
				matching_mark_index = i
				break
			end
		end

		if matching_mark_index then
			-- Deselect the occurrence
			local mark_id = table.remove(marks, matching_mark_index)
			iedit_module.remove_extmark(buf, mark_id)
			if M.current_index > matching_mark_index then
				M.current_index = M.current_index - 1
			elseif M.current_index == matching_mark_index then
				M.current_index = math.min(M.current_index, #marks)
			end
		else
			-- Check if cursor is on a matching occurrence and select it
			local word_start, word_end = line:find(M.current_word, cursor_col + 1)
			if word_start and word_start > 0 then
				local new_mark_id =
					iedit_module.create_extmark(buf, { cursor_row, word_start - 1, cursor_row, word_end })
				table.insert(marks, new_mark_id)
				iedit_module.update_extmark_highlight(buf, new_mark_id, "IeditSelect")
				M.current_index = #marks
			end
		end

		-- Update highlights
		for i, mark_id in ipairs(marks) do
			local highlight = i == M.current_index and "IeditCurrent" or "IeditSelect"
			iedit_module.update_extmark_highlight(buf, mark_id, highlight)
		end

		-- If no marks left, exit iedit mode
		if #marks == 0 then
			M.stop()
		end
	else
		-- We're not in iedit mode
		local word_start, word_end = line:find("%w+", cursor_col + 1)
		if word_start and word_start > 0 then
			local word = line:sub(word_start, word_end)
			local ranges = { { cursor_row, word_start - 1, cursor_row, word_end } }
			M.enter_iedit_mode(buf, ranges, 1)
		end
	end
end

return M
