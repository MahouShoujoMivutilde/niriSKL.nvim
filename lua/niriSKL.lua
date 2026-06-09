if vim.env.XDG_CURRENT_DESKTOP ~= "niri" or vim.env.SSH_TTY ~= nil then
    return
end

local M = {}

local config = {}

config.DEBUG = false
config.HIDE_WARNINGS = false
config.latin_index = 0

local _who = "[niriSKL]: "

local function iprint(...)
    if config.DEBUG then
        vim.notify(_who .. table.concat({ ... }, " "), vim.log.levels.INFO)
    end
end

local function wprint(...)
    if not config.HIDE_WARNINGS then
        vim.notify_once(_who .. table.concat({ ... }, " "), vim.log.levels.WARN)
    end
end

local function still_alive()
    if vim.env.NIRI_SOCKET == nil then
        -- wprint("env. var. $NIRI_SOCKET is undefined")
        return false
    end

    if not vim.uv.fs_stat(vim.env.NIRI_SOCKET) then
        wprint("env. var. $NIRI_SOCKET is refers to file\n'" .. vim.env.NIRI_SOCKET .. "'\nwhich doesn't exist")
        return false
    end

    -- local pipe = io.popen("echo '\"Version\"' | socat - UNIX-CONNECT:$NIRI_SOCKET 2>&1")

    local pipe = io.popen("niri msg --json version 2>&1")
    if pipe == nil then
        return false
    end

    local ok, _ = pcall(vim.json.decode, pipe:read("*a"))

    -- TODO: handle if it's just a dead socket that exists, accepts
    -- connection and command, but doesn't return anything; popen apparently
    -- doesn't have timeout lol.
    -- Relevant if e.g. something else is squatting in place of NIRI_SOCKET
    pipe:close()
    if not ok then
        wprint(
            "can't connect to $NIRI_SOCKET, but socket file exists;\n"
                .. "is $NIRI_SOCKET out of date (e.g. old tmux session)?"
        )
    end
    return ok
end

-- NOTE: this is 10-15ms, other niri msg calls are much faster
local function set_layout(layout_index)
    -- local _t1 = os.clock()
    local pipe = io.popen(("niri msg action switch-layout %d"):format(layout_index))

    if pipe ~= nil then
        pipe:close()
    end
    iprint("switched layout to", layout_index)
    -- local _t2 = os.clock()
    -- iprint(("set_layout (new): %g ms"):format( (_t2 - _t1) * 1000 ))
end

local function save_layout()
    local pipe = io.popen("niri msg --json keyboard-layouts")
    if pipe == nil then
        return nil
    end

    local j = vim.json.decode(pipe:read("*a"))
    pipe:close()
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
            iprint(("restored layout: %g ms"):format((t2 - t1) * 1000))
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
            iprint(("saved layout: %g ms"):format((t2 - t1) * 1000))
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
