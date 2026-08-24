# Hyprscroll2D

[![Tests](https://github.com/kirollosatef/hyprscroll2d/actions/workflows/tests.yml/badge.svg)](https://github.com/kirollosatef/hyprscroll2d/actions/workflows/tests.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Hyprscroll2D is an experimental two-dimensional scrolling layout for Hyprland.
It turns a workspace into an expandable grid and lets you move through it in
every direction.

Unlike column-only scrolling layouts, windows can live above, below, left and
right of each other. Configurable edge peeks keep nearby rows and columns
visible, so you never lose the shape of your workspace.

## What works

- Infinite two-dimensional window placement
- Focus and camera movement on both axes
- Directional window movement with collision swapping
- Independent width and height presets
- Visible edge peeks for neighboring rows and columns
- Per-workspace in-memory layout state
- Omarchy bindings that fall back to the normal action outside Hyprscroll2D

## Status

`v0.1.0` is an experimental preview for Hyprland `0.56.x`. It has been
live-tested on Hyprland `0.56.2` and is intentionally enabled on only one
workspace during evaluation.

The layout uses Hyprland's Lua custom-layout API, so it does not require a
compiled Hyprland plugin. The included binding integration currently targets
Omarchy. Other Lua-configured Hyprland installations can load the layout, but
must provide their own bindings.

## Install on Omarchy

Requirements:

- Omarchy with Hyprland `0.56.x`
- Git

Clone the project into your local data directory:

```bash
git clone https://github.com/kirollosatef/hyprscroll2d.git \
  ~/.local/share/hyprscroll2d
```

Add the following near the end of `~/.config/hypr/hyprland.lua`, after the
Omarchy defaults and your normal `require("hypr.*")` lines:

```lua
local hyprscroll2d = os.getenv("HOME") .. "/.local/share/hyprscroll2d"
dofile(hyprscroll2d .. "/layout/init.lua")
dofile(hyprscroll2d .. "/integration/omarchy.lua")

-- Start safely on one experimental workspace.
hl.workspace_rule({ workspace = "9", layout = "lua:hyprscroll2d" })
```

Reload and validate the configuration:

```bash
hyprctl reload
hyprctl configerrors
```

If `hyprctl configerrors` prints nothing, press `Super+9`, open a few windows,
and try the controls below.

## Controls

| Action | Binding |
| --- | --- |
| Focus a window | `Super+Arrow` |
| Move or swap a window | `Super+Shift+Arrow` |
| Pan the camera | `Super+Ctrl+Arrow` |
| Grow window width | `Super+-` |
| Shrink window width | `Super+=` |
| Grow window height | `Super+Shift+=` |
| Shrink window height | `Super+Shift+-` |

These keys retain Omarchy's normal behavior whenever the active window is not
using Hyprscroll2D.

## Customize the layout

Edit [`layout/config.lua`](layout/config.lua) to change:

- `peek_x` and `peek_y`: visible pixels from neighboring columns and rows
- `gap_x` and `gap_y`: spacing between cells
- `width_steps` and `height_steps`: available size presets
- `default_width_step` and `default_height_step`: initial window dimensions

Reload Hyprland after changing the values.

## Update

```bash
git -C ~/.local/share/hyprscroll2d pull --ff-only
hyprctl reload
hyprctl configerrors
```

## Uninstall

Remove the Hyprscroll2D block from `~/.config/hypr/hyprland.lua`, then reload:

```bash
hyprctl reload
hyprctl configerrors
```

Once the config is clean, remove the cloned repository:

```bash
rm -rf ~/.local/share/hyprscroll2d
```

## Known limitations

- State is reset when Hyprland reloads.
- Fullscreen, groups, multi-monitor moves, and special workspaces need more
  testing.
- The bundled conditional keybinding integration currently supports Omarchy.
- Compatibility outside Hyprland `0.56.x` is not yet guaranteed.

Please report issues with your Hyprland version, monitor geometry, relevant
configuration, and exact reproduction steps.

## Development

Run the full test and syntax suite:

```bash
make check
```

The geometry and navigation engine is isolated from Hyprland APIs so it can be
tested with plain Lua. See [`docs/DESIGN.md`](docs/DESIGN.md) for the behavioral
model and roadmap, and [`docs/RESEARCH.md`](docs/RESEARCH.md) for related
projects and technical background.

## Contributing

Contributions and real-world testing are welcome. Read
[`CONTRIBUTING.md`](CONTRIBUTING.md) before opening a pull request.

Created by [kirollosatef](https://github.com/kirollosatef).

## License

MIT
