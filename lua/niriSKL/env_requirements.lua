M = {}

local function a(_) end

local function b(_)
    local msg = "[niriSKL] not running, state:\n"

    msg = msg .. ("$XDG_CURRENT_DESKTOP = %s, (should be niri)\n"):format(vim.env.XDG_CURRENT_DESKTOP)
    msg = msg .. ("$SSH_TTY = %s, (shouldn't be defined, nil)\n"):format(vim.env.SSH_TTY)
    msg = msg .. ("vim.system() is %s, (should be a function, not nil)\n"):format(vim.inspect(vim.system))

    vim.notify(msg, vim.log.levels.WARN)
end

M.mock = { setup = a, launch = a, stop = a, _dump_state = b }

function M.are_we_good()
    if vim.env.XDG_CURRENT_DESKTOP ~= "niri" or vim.env.SSH_TTY ~= nil or vim.system == nil then
        return false
    end
    return true
end

return M
