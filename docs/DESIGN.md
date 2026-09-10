# Hyprscroll2D design

## Mental model

Each tiled window occupies an integer grid coordinate `(column, row)`. The
workspace camera also has a grid coordinate. Rendering translates every window
relative to that camera.

The largest window size is slightly smaller than the viewport. Columns and
rows are packed using the largest window in each band rather than a fixed
screen-sized pitch. This keeps neighboring edges visible even when individual
windows use smaller presets. With a 48px peek and a 12px inter-cell gap, at
least 36px of an adjacent maximum-sized row or column remains visible.

## Initial behavior

- New windows are placed in the first free cell to the right of the focused
  window.
- Directional focus prefers a window on the same row or column, then the
  nearest directional candidate.
- Moving into an occupied cell swaps the two windows.
- Moving into an empty cell preserves the hole and moves the window there.
- The camera follows focus unless the user explicitly pans it.
- Width and height use discrete presets to prevent accidental overlaps.

## Intended controls

| Action | Binding |
| --- | --- |
| Focus | `Super+Arrow` |
| Move window | `Super+Shift+Arrow` |
| Pan camera | `Super+Ctrl+Arrow` |
| Grow width | `Super+-` |
| Shrink width | `Super+=` |
| Grow height | `Super+Shift+=` |
| Shrink height | `Super+Shift+-` |

Bindings must delegate to Omarchy's original actions whenever another layout
is active.

## Overview

The Quickshell service owns a full-monitor layer-shell overlay with exclusive
keyboard focus. It displays still captures at the positions supplied by the Lua
layout and animates between normal scale and a 3×3 view. Selection and the overview
camera are separate from normal application focus and the saved camera.

`layout/overview.lua` implements selection, panning, and restoration without
Hyprland calls. The adapter exposes `__hyprscroll2d_overview` over Hyprland's REPL
socket. Each session has a token so delayed requests cannot dismiss a newer
overview. The shell serializes requests and renews a three-second restoration
lease while overview is open.

Hyprland 0.56's toplevel export skips windows outside their monitor. The adapter
therefore stages full-size windows beneath the opaque overlay, while retaining
their logical positions. Capture does not resize applications. Integer placement
boxes prevent fractional presets from producing one-pixel changes during staging.

Dismissal has two steps: restore normal placements beneath the overlay, then
unmap the overlay and focus the selected window. Focusing before the layer unmaps
can lose focus to Hyprland's layer cleanup. The overlay consumes held keys through
their release before unmapping. Escape restores the original camera, and the
watchdog cancels staging if the shell disappears.

## Roadmap

1. Validate off-screen placement and animation on Hyprland 0.56.2.
2. Add safe Omarchy bindings and an experimental workspace rule.
3. Add state persistence across Hyprland reloads.
4. Add mouse/touchpad camera panning.
5. Harden groups, fullscreen, multi-monitor moves and special workspaces.
