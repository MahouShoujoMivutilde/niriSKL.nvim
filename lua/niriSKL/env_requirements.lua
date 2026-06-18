M = {}

function M.are_we_good()
    if vim.env.XDG_CURRENT_DESKTOP ~= "niri" or vim.env.SSH_TTY ~= nil or vim.system == nil then
        return false
    end
    return true
end

local function noop(_) end

local function explain(_)
    if M.are_we_good() then
        return
    end

    local msg = "[niriSKL] is not running, why:\n\n"

    if vim.env.XDG_CURRENT_DESKTOP ~= "niri" then
        msg = msg .. ("$XDG_CURRENT_DESKTOP = %s, but should be niri.\n"):format(vim.env.XDG_CURRENT_DESKTOP)
    end

    if vim.env.SSH_TTY ~= nil then
        msg = msg
            .. ("$SSH_TTY = %s, but shouldn't be defined. Are we running inside ssh session?\n"):format(vim.env.SSH_TTY)
    end

    if vim.system == nil then
        msg = msg
            .. ("vim.system() is %s, but should be a function. Is neovim pre v0.10.0?\n"):format(
                vim.inspect(vim.system)
            )
    end

    vim.notify(msg, vim.log.levels.WARN)
end

-- XXX: .mock should contain the same function names the main niriSKL module M does
M.mock = {
    setup = noop,
    launch = noop,
    stop = noop,
    start = noop,
    _dump_state = explain,
    is_running = function() return false end,
}


return M
