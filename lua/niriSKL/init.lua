local req = require("niriSKL.env_requirements")

if not req.are_we_good() then
    -- guards automatic setup() etc calls in env. not meeting requirements
    return req.mock
end

-- state vars
vim.g._niriSKL_is_running = false
vim.b._niriSKL_insert_mode_layout = nil

local M = {}

local config = {}

config.DEBUG = false
config.HIDE_WARNINGS = false
config.latin_index = 0

config._ipc_timeout_ms = 200 -- if it doesn't respond after 0.2s it's probably broken anyway
config._augroup = "niriSKL" -- but if you run several setup() and launch()/stop() with different group names that's on you lol

local _who = "[niriSKL]: "

local function print_info(...)
    if config.DEBUG then
        vim.notify(_who .. table.concat({ ... }, " "), vim.log.levels.INFO)
    end
end

local function print_warn(...)
    if not config.HIDE_WARNINGS then
        vim.notify_once(_who .. table.concat({ ... }, " "), vim.log.levels.WARN)
    end
end

local function run_legacy(cmd)
    if vim.fn.executable("timeout") == 1 then
        cmd = vim.list_extend({ "timeout", string.format("%.3fs", config._ipc_timeout_ms / 1000) }, cmd)
    end

    -- print_info(vim.inspect(cmd))
    local out = vim.fn.system(cmd)
    local result = { stdout = out, stderr = "", code = vim.v.shell_error }

    if result.code ~= 0 then
        print_warn(("'%s' exited with code %d\nOUTPUT:\n%s"):format(table.concat(cmd, " "), result.code, result.stdout))
        return
    end

    return result
end

local function run(cmd)
    if vim.system == nil then
        return run_legacy(cmd)
    end

    local result = vim.system(cmd, { text = true }):wait(config._ipc_timeout_ms)

    if result.code == 124 then
        print_warn(("'%s' timed out after %d ms"):format(table.concat(cmd, " "), config._ipc_timeout_ms))
        return
    elseif result.code ~= 0 then
        print_warn(("'%s' exited with code %d\nstderr:\n%s"):format(table.concat(cmd, " "), result.code, result.stderr))
        return
    end

    return result
end

local function still_alive()
    if vim.env.NIRI_SOCKET == nil then
        return false
    end

    local niri_stat = vim.uv.fs_stat(vim.env.NIRI_SOCKET)
    if not niri_stat then
        print_warn(("$NIRI_SOCKET='%s',\na file which doesn't exist"):format(vim.env.NIRI_SOCKET))
        return false
    end

    if niri_stat.type ~= "socket" then
        print_warn(("$NIRI_SOCKET='%s',\nwhich isn't a unix socket it should be"):format(vim.env.NIRI_SOCKET))
        return false
    end

    -- NOTE: this is more precise, but slower; the functions after will check `niri msg` results anyway

    -- local result = run({ "niri", "msg", "--json", "version" })
    -- if result == nil then
    --     return false
    -- end
    --
    -- local ok, _ = pcall(vim.json.decode, result.stdout)
    -- if not ok then
    --     print_warn("can't decode json from niri msg")
    -- end
    -- return ok

    -- (probably)
    return true
end

-- NOTE: this is 10-15ms, other niri msg calls are much faster
local function set_layout(i)
    -- local _t1 = os.clock()

    -- first insert
    if i == nil then
        return
    end

    local result = run({ "niri", "msg", "action", "switch-layout", i })
    if result == nil then
        return
    end

    print_info("switched layout to", i)

    -- local _t2 = os.clock()
    -- print_info(("set_layout (new): %g ms"):format( (_t2 - _t1) * 1000 ))
end

local function save_layout()
    local cmd = { "niri", "msg", "--json", "keyboard-layouts" }
    local result = run(cmd)
    if result == nil then
        return
    end

    local j = vim.json.decode(result.stdout)
    if j.current_idx == nil then
        print_warn(("%s\nreturned\n%s\n\nwhich doesn't have .current_idx field we need"):format(table.concat(cmd, " "), vim.inspect(j)))
    end
    vim.b._niriSKL_insert_mode_layout = j.current_idx
end

-- XXX: this assumes that setup(your_options) already happened at some point
-- (manually or via your plugin manager). If it didn't - it will run at defaults.
function M.launch()
    if M.is_running() then
        return
    end

    vim.b._niriSKL_insert_mode_layout = nil

    local niri_augroup = vim.api.nvim_create_augroup(config._augroup, { clear = true })

    vim.api.nvim_create_autocmd({ "InsertEnter" }, {
        -- switch to whatever layout we were using
        callback = function()
            local t1 = os.clock()

            if not still_alive() then
                return
            end

            set_layout(vim.b._niriSKL_insert_mode_layout)

            local t2 = os.clock()
            print_info(("restored layout: %g ms"):format((t2 - t1) * 1000))
        end,
        group = niri_augroup,
        desc = "Restore niri keyboard to whatever we were using in Inser mode",
    })

    vim.api.nvim_create_autocmd({ "InsertLeave" }, {
        -- store current layout
        callback = function()
            local t1 = os.clock()

            if not still_alive() then
                return
            end

            -- we don't know if the user switched to some other window, changed layout,
            -- and switched back, have to query it every time
            save_layout()

            if vim.b._niriSKL_insert_mode_layout == config.latin_index then
                return
            end

            set_layout(config.latin_index)

            local t2 = os.clock()
            print_info(("saved layout: %g ms"):format((t2 - t1) * 1000))
        end,
        group = niri_augroup,
        desc = "Change niri keyboard to latin for Normal mode",
    })

    vim.g._niriSKL_is_running = true
end

function M.is_running()
    return vim.g._niriSKL_is_running
end

-- for :NiriSKL commands
function M.stop()
    if not M.is_running() then
        return
    end
    vim.api.nvim_del_augroup_by_name(config._augroup)
    vim.g._niriSKL_is_running = false
    vim.notify("plugin disabled", vim.log.levels.INFO)
end

-- for :NiriSKL commands
function M.start()
    if M.is_running() then
        return
    end
    M.launch()
    vim.notify("plugin enabled", vim.log.levels.INFO)
end

function M.setup(opts)
    opts = opts or {}
    config = vim.tbl_deep_extend("force", config, opts)

    -- M.launch()
end

function M._dump_state()
    print("[DEBUG STUFF] niriSKL's internal variables:\n\n")
    print("$NIRI_SOCKET =", vim.env.NIRI_SOCKET)
    print("config =", vim.inspect(config))
    print("vim.b._niriSKL_insert_mode_layout =", vim.inspect(vim.b._niriSKL_insert_mode_layout))
    print("vim.g._niriSKL_is_running =", vim.inspect(vim.g._niriSKL_is_running))
    if vim.system == nil then
        print("Using legacy vim.fn.system() instead of modern vim.system()")
        if vim.fn.executable("timeout") == 1 then
            print("...✅together with the coreutils 'timeout' to compensate for the lack of :wait()")
        else
            print("...❗without timeout capability, if anything goes wrong")
        end
    end
    print("\n")
end

return M
