# niriSKL

niriSKL is a lua plugin for neovim that switches [niri](https://github.com/niri-wm/niri/) keyboard layout so that you have:
* a preconfigured latin layout when in the Normal mode
* whatever layout you were using in the Insert mode

Inspired by [vim-xkbswitch](https://github.com/lyokha/vim-xkbswitch). But _a lot_ more minimal and niri specific.

## Why?

`vim.o.langmap` **sucks**!

It has annoying edge cases where it fails, and if you add another layout to your compositor - congrats, now you need to write a new `langmap`!

It's much simpler to just switch to the correct layout in the Normal mode, and restore whatever you were using in the Insert mode. And that's exactly what niriSKL does.


## Usage

With [lazy.nvim](https://github.com/folke/lazy.nvim) plugin manager:

```lua
{
    -- TODO: add url once posted
    "*this repo url*",

    -- you can omit any option, defaults are shown here for your convenience
    opts = {
        DEBUG = false,
        HIDE_WARNINGS = false,
        latin_index = 0
    },
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

That way even when you switch layout in different window, it will still work as expected, with Normal mode still being on latin layout and usable.

### Options

Option  | default | meaning for defaults
------|---------|--------
`DEBUG` | false | don't show "layout saved/restored" notifications
`HIDE_WARNINGS` | false | notify if connection to niri socket is lost (stale env. detection)
`latin_index` | 0 | index of the layout that will be used for the Normal mode. E.g. if you have `us,ru` in niri's keyboard layout, 0 will use `us` in Normal mode. But if you have `de,us,ru`, to use `us` in Normal mode set `latin_index` to 1


#### NOTE

This plugin was tested and works fine on niri and neovim from arch repos, so everything latest stable.
It most likely will work on something older so long as it's not completely ancient, but that's what it's tested at, keep this in mind.
