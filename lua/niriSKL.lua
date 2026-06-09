if vim.env.XDG_CURRENT_DESKTOP ~= "niri" or vim.env.SSH_TTY ~= nil then
    return
end

-- if vim.fn.has("nvim-0.10") ~= 1 then
if vim.system == nil then
    -- We use vim.system() instead of io.popen() because you can set timeout for
    -- the execution, which is useful if the command fails but hangs instead
    -- throwing an error.

    -- Commit 04feb63 and earlier had full io.popen() implementation, if you need it
    return
end

local M = {}

local config = {}

config.DEBUG = false
config.HIDE_WARNINGS = false
config.latin_index = 0

local _who = "[niriSKL]: "
local _ipc_timeout_ms = 1000

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

local function run(cmd)
    local result = vim.system(cmd, { text = true }):wait(_ipc_timeout_ms)

    if result.code == 124 then
        print_warn(("%s timed out after %d ms"):format(table.concat(cmd, " "), _ipc_timeout_ms))
        return
    elseif result.code ~= 0 then
        print_warn(("%s exited with code %d\nstderr:\n%s"):format(table.concat(cmd, " "), result.code, result.stderr))
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

    local result = run({ "niri", "msg", "action", "switch-layout", i })
    if result == nil then
        return
    end

    print_info("switched layout to", i)

    -- local _t2 = os.clock()
    -- print_info(("set_layout (new): %g ms"):format( (_t2 - _t1) * 1000 ))
end

local function save_layout()
    local result = run({ "niri", "msg", "--json", "keyboard-layouts" })
    if result == nil then
        return
    end

    local j = vim.json.decode(result.stdout)
    vim.b._niriSKL_prev_layout = j.current_idx
end

function M.setup(opts)
    opts = opts or {}
    config = vim.tbl_deep_extend("force", config, opts)

    vim.b._niriSKL_prev_layout = nil

    local niri_augroup = vim.api.nvim_create_augroup("niriSKL", { clear = true })

    vim.api.nvim_create_autocmd({ "InsertEnter" }, {
        -- switch to whatever layout we were using
        callback = function()
            local t1 = os.clock()

            if vim.b._niriSKL_prev_layout == nil then
                -- first insert
                return
            end

            if not still_alive() then
                return
            end

            set_layout(vim.b._niriSKL_prev_layout)

            local t2 = os.clock()
            print_info(("restored layout: %g ms"):format((t2 - t1) * 1000))
        end,
        group = niri_augroup,
        desc = "Restore niri keyboard to whatever we were using in Inser mode",
    })

    vim.api.nvim_create_autocmd({ "InsertLeave" }, {
        -- store current layout
        -- XXX: this is like 20ms total in the worst case, because `niri msg` is slow; improve
        callback = function()
            local t1 = os.clock()

            if not still_alive() then
                return
            end

            -- we don't know if the user switched to some other window, changed layout,
            -- and switched back, have to query it every time
            save_layout()

            if vim.b._niriSKL_prev_layout == config.latin_index then
                return
            end

            set_layout(config.latin_index)

            local t2 = os.clock()
            print_info(("saved layout: %g ms"):format((t2 - t1) * 1000))
        end,
        group = niri_augroup,
        desc = "Change niri keyboard to latin for Normal mode",
    })
end

-- Debug stuff; plugin must be required as global to access
-- e.g.
-- config = function ()
--             niriSKL = require("niriSKL")
--             niriSKL.setup({
--                 DEBUG = false
--             })
--         end

function M._show_state()
    print(vim.inspect(config))
    print("vim.b._niriSKL_prev_layout =", vim.inspect(vim.b._niriSKL_prev_layout))
end

return M
