# niriSKL ("smart keyboard layout")

niriSKL is a lua plugin for neovim that switches [niri](https://github.com/niri-wm/niri/) keyboard layout ensuring that you'll have:
* your latin layout of choice - when in NORMAL mode
* whatever layout you were using for actually writing - when in INSERT mode

Inspired by [vim-xkbswitch](https://github.com/lyokha/vim-xkbswitch). But _a lot_ more minimal and niri specific.

## Why?

`vim.o.langmap` **sucks**!

It has annoying edge cases where it fails, and if you add another layout to your compositor - congrats, now you need to write a new `langmap`!

It's much simpler to just switch to the correct layout in NORMAL mode, and restore whatever you were using in INSERT mode. And that's exactly what niriSKL does.


## Usage


> [!NOTE]
> This plugin was tested and works fine on niri and neovim from arch repos, so everything latest stable.
> It most likely will work on something older so long as it's not completely ancient, but that's what it's tested at, keep this in mind.

### Requirements

* Neovim v0.10.0+ - because `vim.system()` since it has a proper timeout parameter and can get an exit code, unlike `io.popen()`

### Install

With [lazy.nvim](https://github.com/folke/lazy.nvim) plugin manager:

```lua
{
    -- TODO: add url once posted
    "*this repo url*",

    -- you can omit any option,
    -- but you MUST at least have `opts = {}` unless you're calling setup() yourself,
    -- defaults are:
    opts = {
        latin_index = 0,
        -- DEBUG = false,
        -- HIDE_WARNINGS = false,
    },

    -- -- by the way, this is equivalent to
    -- config = function()
    --     local niriSKL = require("niriSKL")
    --     niriSKL.setup({
    --         latin_index = 0,
    --     })
    -- end,
},

```

And, because it makes sense, make layout tracking in niri _per window_:

```kdl
input {
    keyboard {
        xkb {
            layout "us,ru"
        }
        track-layout "window" // per window layout
    }
    //...
}
```

That way even when you switch layout in different window, it will still work as expected, with Normal mode still being in latin layout and usable.

### Options

Option  | default | meaning for the default values
------|---------|--------
`DEBUG` | false | don't show "layout saved/restored" notifications
`HIDE_WARNINGS` | false | notify if connection to niri socket is lost (stale env. detection)
`latin_index` | 0 | index of the layout that will be used for the NORMAL mode. E.g. if you have `us,ru` in niri's keyboard layout, 0 will use `us` in NORMAL mode. But if you have `de,us,ru`, to use `us` in NORMAL mode set `latin_index` to 1
