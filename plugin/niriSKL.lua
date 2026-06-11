local niriSKL_cmd_sub = {
    disable = {
        impl = function()
            require("niriSKL").stop()
            vim.notify("plugin disabled", vim.log.levels.INFO)
        end,
    },
    enable = {
        impl = function()
            require("niriSKL").launch()
            vim.notify("plugin enabled", vim.log.levels.INFO)
        end,
    },
    toggle = {
        impl = function()
            if not vim.g._niriSKL_is_running then
                require("niriSKL").launch()
                vim.notify("plugin enabled", vim.log.levels.INFO)
            else
                require("niriSKL").stop()
                vim.notify("plugin disabled", vim.log.levels.INFO)
            end
        end,
    },
    _dump_state = {
        impl = function ()
            require("niriSKL")._dump_state()
        end
    }
}

local function niriSKL_cmd(opts)
    local fargs = opts.fargs
    local subcommand_key = fargs[1]
    local subcommand = niriSKL_cmd_sub[subcommand_key]
    if not subcommand then
        vim.notify("NiriSKL: Unknown command: " .. subcommand_key, vim.log.levels.ERROR)
        return
    end
    subcommand.impl()
end

vim.api.nvim_create_user_command("NiriSKL", niriSKL_cmd, {
    nargs = 1,
    complete = function(subcmd_arg_lead)
        local args = {
            "toggle",
            "disable",
            "enable",
            "_dump_state"
        }
        return vim.iter(args)
            :filter(function(arg)
                return arg:find(subcmd_arg_lead) ~= nil
            end)
            :totable()
    end,
})

-- start with defaults as _apparently_ you can call setup() later and it'll still redefine the config just fine
require("niriSKL").launch()
