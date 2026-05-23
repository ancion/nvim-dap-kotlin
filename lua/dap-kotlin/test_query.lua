local tsq = require("vim.treesitter.query")
local parse_query = tsq.parse_query or tsq.parse or tsq.get

local M = {}

local function sanitised(test_name)
	local clean_test = test_name:gsub("`", "")
	return clean_test
end

function M.test_class()
	local query = [[
(class_declaration (type_identifier) @cname)
]]
	local parser = vim.treesitter.get_parser(0)
	local root = (parser:parse()[1]):root()

	local closest_name = nil

	local stop_row = vim.api.nvim_win_get_cursor(0)[1]
	local ft = vim.api.nvim_buf_get_option(0, "filetype")
	assert(ft == "kotlin", "dap-kotlin error: can only debug kotlin files, not " .. ft)

	local test_query = parse_query(ft, query)
	assert(test_query, "dap-kotlin error: could not parse test query")

	for _, match, _ in test_query:iter_matches(root, 0, 0, stop_row) do
		for id, nodes in pairs(match) do
			local capture = test_query.captures[id]
			if capture == "cname" and nodes and #nodes > 0 then
				closest_name = vim.treesitter.get_node_text(nodes[1], 0)
			end
		end
	end
	return closest_name
end

function M.closest_test()
	local tests_query = [[
    (function_declaration
    (modifiers)? @mod
    (simple_identifier) @fname)
]]

	local parser = vim.treesitter.get_parser(0)
	local root = (parser:parse()[1]):root()

	local test_name = ""

	local stop_row = vim.api.nvim_win_get_cursor(0)[1]
	local ft = vim.api.nvim_buf_get_option(0, "filetype")
	assert(ft == "kotlin", "dap-kotlin error: can only debug kotlin files, not " .. ft)

	local test_query = parse_query(ft, tests_query)
	assert(test_query, "dap-kotlin error: could not parse test query")

	for _, match, _ in test_query:iter_matches(root, 0, 0, stop_row) do
		local test_match = {}
		for id, nodes in pairs(match) do
			local capture = test_query.captures[id]
			if capture == "mod" and nodes and #nodes > 0 then
				test_match.modifier = vim.treesitter.get_node_text(nodes[1], 0)
			end
			if capture == "fname" and nodes and #nodes > 0 then
				test_match.function_name = vim.treesitter.get_node_text(nodes[1], 0)
			end
		end
		test_name = test_match.function_name or ""
	end
	return sanitised(test_name)
end

return M
