# Changelog

## v0.4.0 - 2026-09-10

- Add a full-screen 3×3 canvas overview with still window previews and a zoom transition.
- Navigate with arrow keys or H/J/K/L, then select with Enter or a click.
- Restore the original focus and camera with Escape.
- Capture application input while overview is open, and restore placements if the shell stops responding.
- Configure the activation shortcut through `overviewKeybind`.

## v0.3.0 - 2026-08-30

- Store plugin settings inline in `~/.config/omarchy/shell.json`.
- Apply layout setting changes without re-registering the layout.
- Make the target workspace configurable and remove `layout/config.lua`.
- Expose Hyprland's focus-follows-mouse behavior as `focusFollowsMouse`.

## v0.2.0 - 2026-08-24

- Add native installation through `omarchy plugin add`.
- Reload the layout automatically after a Hyprland configuration reload.
- Add an Omarchy marketplace-compatible service manifest.

## v0.1.0 - 2026-08-24

First experimental preview.

- Add an infinite two-dimensional grid and camera.
- Add horizontal and vertical focus, movement, swapping, and panning.
- Add independent width and height presets.
- Keep neighboring rows and columns visible with configurable edge peeks.
- Add conditional Omarchy integration for an isolated test workspace.
- Add safe Omarchy install and uninstall scripts with config backups.
- Add core, Hyprland adapter, and Omarchy integration tests.
