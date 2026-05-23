local util = require("dap-kotlin.util")
local test_query = require("dap-kotlin.test_query")

local M = {}
M.dap_configurations = {
	dap_command = "kotlin-debug-adapter",
	project_root = "${workspaceFolder}",
	enable_logging = false,
	log_file_path = "",
}

local function load_module(module_name)
	local ok, module = pcall(require, module_name)
	assert(ok, string.format("dap-kotlin dependency error: %s not installed", module_name))
	return module
end

local function setup_adapters(dap)
	dap.adapters.kotlin = {
		type = "executable",
		command = M.dap_configurations.dap_command,
		options = {
			initialize_timeout_sec = 15,
			disconnect_timeout_sec = 15,
			auto_continue_if_many_stopped = false,
		},
	}

	dap.adapters.kotlin_attach = function(callback, config)
		vim.ui.input({
			prompt = "JDWP host (leave empty for 127.0.0.1)",
			default = "127.0.0.1",
		}, function(host)
			host = host or "127.0.0.1"
			vim.ui.input({
				prompt = "JDWP port (leave empty for 5005)",
				default = "5005",
			}, function(port)
				port = tonumber(port) or 5005
				config.hostName = host
				config.port = port

				vim.notify("Waiting for JDWP at " .. host .. ":" .. port .. " ...", vim.log.levels.INFO)
				util.wait_for_port(host, port, 5000, function()
					vim.notify("Attaching to " .. host .. ":" .. port, vim.log.levels.INFO)
					callback({
						type = "executable",
						command = M.dap_configurations.dap_command,
						options = {
							initialize_timeout_sec = 15,
							disconnect_timeout_sec = 15,
						},
					})
				end)
			end)
		end)
	end
end

local function config_kotlin_adapter(dap)
	local function build_tool()
		return util.detect_build_tool(vim.fn.getcwd())
	end

	local shared = {
		projectRoot = M.dap_configurations.project_root,
		jsonLogFile = M.dap_configurations.log_file_path,
		enableJsonLogging = M.dap_configurations.enable_logging,
	}

	local existing = dap.configurations.kotlin or {}
	dap.configurations.kotlin = vim.list_extend(existing, {
		{
			type = "kotlin",
			request = "launch",
			name = "Launch current Main",
			mainClass = function()
				local class = test_query.test_class() or vim.fn.expand("%:t:r")
				return util.get_package() .. "." .. class .. "Kt"
			end,
			projectRoot = shared.projectRoot,
			buildTool = build_tool,
			jsonLogFile = shared.jsonLogFile,
			enableJsonLogging = shared.enableJsonLogging,
		},
		{
			type = "kotlin_attach",
			request = "attach",
			name = "Attach Debug Server",
			projectRoot = shared.projectRoot,
			timeout = 5000,
		},
	})
end

function M.setup(opts)
	opts = opts or {}
	for k, v in pairs(opts) do
		M.dap_configurations[k] = v
	end

	local dap = load_module("dap")

	dap.defaults.kotlin = dap.defaults.kotlin or {}
	dap.defaults.kotlin.auto_continue_if_many_stopped = false
	dap.set_log_level("DEBUG")

	setup_adapters(dap)
	config_kotlin_adapter(dap)
end

return M
