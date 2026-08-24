# Research notes

Research was performed against Hyprland 0.56.2 on 2026-08-24.

## Existing projects

- Hyprland's built-in scrolling layout is an infinitely growing one-axis tape.
- `dawsers/hyprscroller` is feature-rich but one-axis and archived.
- `kuroiko0429/hyprscroller-ng` is maintained but remains column-based.
- `outfoxxed/hy3` provides mature manual two-dimensional tiling without an
  infinite scrolling viewport.
- `shawnmurali/hyprortholayout` provides orthogonal stacks without scrolling.
- `ForgeDuSavoir/fit-scroller-layout` is the strongest Lua reference. Its
  spatial mode supports directional geometry but deliberately allows overflow
  on only one configured axis.

No maintained public project found during the search implemented an infinite
two-axis window canvas for Hyprland.

## Technical choice

Hyprland 0.56.2 exposes `hl.layout.register`, layout messages, target window
metadata and `target:place({ x, y, w, h })`. The implementation forwards those
coordinates to global target positioning without clamping them to one axis.

This makes an independent X/Y camera feasible in a Lua custom layout. Lua is
preferred over a compiled plugin because compiled Hyprland plugins must closely
match the running compositor ABI and can reduce compositor stability.

## References

- https://wiki.hypr.land/Configuring/Layouts/Custom-Layouts/
- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
- https://github.com/hyprwm/Hyprland/tree/v0.56.2/example/layouts
- https://github.com/ForgeDuSavoir/fit-scroller-layout
- https://github.com/dawsers/hyprscroller
- https://github.com/kuroiko0429/hyprscroller-ng
- https://github.com/outfoxxed/hy3
- https://github.com/shawnmurali/hyprortholayout
