M = {}

local function noop(_) end

local function explain(_)
    local msg = "[niriSKL] not running, state:\n\n"

    if vim.env.XDG_CURRENT_DESKTOP ~= "niri" then
        msg = msg .. ("$XDG_CURRENT_DESKTOP = %s, but should be niri.\n"):format(vim.env.XDG_CURRENT_DESKTOP)
    end

    if vim.env.SSH_TTY ~= nil then
        msg = msg .. ("$SSH_TTY = %s, but shouldn't be defined. Are we running from ssh session?\n"):format(vim.env.SSH_TTY)
    end

    if vim.system == nil then
        msg = msg .. ("vim.system() is %s, but should be a function. Is neovim pre v0.10.0?\n"):format(vim.inspect(vim.system))
    end

    if M.are_we_good() then
        return
    end

    vim.notify(msg, vim.log.levels.WARN)
end

M.mock = { setup = noop, launch = noop, stop = noop, _dump_state = explain }

function M.are_we_good()
    if vim.env.XDG_CURRENT_DESKTOP ~= "niri" or vim.env.SSH_TTY ~= nil or vim.system == nil then
        return false
    end
    return true
end

return M
