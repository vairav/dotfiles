-- Misc behavior overrides (loaded after ml4w's conf/misc.lua, so these win)

hl.config({
    misc = {
        -- A window opened over a fullscreen one: drop fullscreen, then tile.
        -- ml4w ships 1, which hands fullscreen to the new window.
        on_focus_under_fullscreen = 2,
    },
})
