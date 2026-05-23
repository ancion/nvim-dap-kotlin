local M = {}

local path_sep = vim.uv.os_uname().sysname == "Windows" and "\\" or "/"

function M.path_join(...)
    return table.concat(vim.tbl_flatten({ ... }), path_sep)
end

local function mysplit(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        table.insert(t, str)
    end
    return t
end

local function indexOf(array, value)
    for i, v in ipairs(array) do
        if v == value then
            return i
        end
    end
    return nil
end

function M.get_package()
    local x = vim.fn.fnamemodify(vim.fn.expand("%"), ":p:h")
    local pathTable = mysplit(x, "/")

    local cutof = indexOf(pathTable, "kotlin")
    if cutof then
        for i = cutof, 1, -1 do
            table.remove(pathTable, 1)
        end
    end

    return table.concat(pathTable, ".")
end

local function path_exists(p)
    return vim.fn.filereadable(p) == 1
end

function M.detect_build_tool(project_root)
    project_root = project_root or vim.fn.getcwd()
    if path_exists(project_root .. "/gradlew") or path_exists(project_root .. "/build.gradle.kts") or path_exists(project_root .. "/build.gradle") then
        return "gradle"
    end
    if path_exists(project_root .. "/mvnw") or path_exists(project_root .. "/pom.xml") then
        return "maven"
    end
    return nil
end

local JDWP_ARGS = "-agentlib:jdwp=transport=dt_socket,server=y,suspend=y"

function M.wait_for_port(host, port, timeout_ms, callback)
    local start = vim.loop.now()
    local function poll()
        local ok, chan = pcall(vim.fn.sockconnect, "tcp", host .. ":" .. port, { rpc = true })
        if ok then
            vim.fn.chanclose(chan)
            callback()
        elseif vim.loop.now() - start > timeout_ms then
            local addr = host == "127.0.0.1" and port or host .. ":" .. port
            vim.notify(
                "---- JDWP not ready ----\n"
                .. "Could not connect to " .. host .. ":" .. port .. "\n\n"
                .. "Start your app with JDWP enabled, e.g.:\n\n"
                .. "  java " .. JDWP_ARGS .. ",address=" .. addr .. " <main-class>\n\n"
                .. "  ./gradlew run --debug-jvm\n\n"
                .. "  mvn exec:java -Dexec.mainClass=\"<main-class>\"\n"
                .. "    -Dexec.jvmArgs=\"" .. JDWP_ARGS .. ",address=*:" .. port .. "\"\n\n"
                .. "Then select Attach again.",
                vim.log.levels.ERROR
            )
        else
            vim.defer_fn(poll, 300)
        end
    end
    poll()
end

return M
