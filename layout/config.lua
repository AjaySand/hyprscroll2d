return {
    -- Keep a visible strip of neighboring cells around the focused window.
    peek_x = 48,
    peek_y = 48,
    gap_x = 12,
    gap_y = 12,
    focus_follows_mouse = true,

    -- Window dimensions are fractions of one grid cell. The largest preset
    -- still preserves the configured edge peeks.
    width_steps = { 0.50, 0.67, 0.85, 1.00 },
    height_steps = { 0.50, 0.67, 0.85, 1.00 },
    default_width_step = 2,
    default_height_step = 3,
}
