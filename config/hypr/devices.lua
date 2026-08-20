-- Disable phantom VGA output
hl.monitor({ output = "VGA-1", disabled = true })

-- Laptop display - no fractional scaling (ignored on machines without eDP-1)
hl.monitor({ output = "eDP-1", mode = "1920x1200@60", position = "0x0", scale = 1 })

-- Input device settings
hl.config({
    input = {
        sensitivity = 0,
        accel_profile = "adaptive",
        natural_scroll = true,

        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
            scroll_factor = 0.8,
        },
    },
})
