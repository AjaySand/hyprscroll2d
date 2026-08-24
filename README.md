# Hyprscroll2D

Hyprscroll2D is an experimental two-dimensional scrolling layout for Hyprland.
It treats a workspace as an expandable grid and moves a camera across that grid
as focus changes.

Unlike column-only scrolling layouts, windows can live above, below, left and
right of each other. Configurable edge peeks keep neighboring rows and columns
visible so the canvas remains understandable.

## Current status

The first prototype provides:

- independent horizontal and vertical window placement;
- camera movement in both axes;
- directional focus;
- directional window movement with collision swapping;
- independent width and height presets;
- configurable horizontal and vertical edge peeks;
- per-workspace in-memory state;
- a pure-Lua test suite.

The project currently targets Hyprland 0.56.x and uses its custom Lua layout
API. The prototype has been live-tested on Hyprland 0.56.2, but it is not yet
ready for general installation.

## Development

Run the tests with:

```bash
make check
```

## Experimental Omarchy setup

Load the layout and its conditional bindings near the end of
`~/.config/hypr/hyprland.lua`:

```lua
dofile(os.getenv("HOME") .. "/Work/personal/hyprscroll2d/layout/init.lua")
dofile(os.getenv("HOME") .. "/Work/personal/hyprscroll2d/integration/omarchy.lua")
hl.workspace_rule({ workspace = "9", layout = "lua:hyprscroll2d" })
```

Workspace 9 is recommended while the layout is experimental. The integration
keeps Omarchy's normal focus, movement and resize behavior on other layouts.

See [docs/DESIGN.md](docs/DESIGN.md) for the behavioral model and roadmap.

## Contributors

- [kirollosatef](https://github.com/kirollosatef) — creator and initial contributor

Contributions and experiments are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT
