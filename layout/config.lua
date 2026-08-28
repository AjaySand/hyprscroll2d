return {
    -- Keep a visible strip of neighboring cells around the focused window.
    peek_x = 24,
    peek_y = 24,
    gap_x = 6,
    gap_y = 6,

    -- Window dimensions are fractions of one grid cell. The largest preset
    -- still preserves the configured edge peeks.
    width_steps = { 0.33, 0.50, 0.75, 0.85, 0.90, 1.00 },
    height_steps = { 0.33, 0.50, 0.75, 0.85, 0.90, 1.00 },
    default_width_step = 5,
    default_height_step = 6,
}
