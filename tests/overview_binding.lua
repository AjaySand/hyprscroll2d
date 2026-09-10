local source = debug.getinfo(1, "S").source:sub(2)
local root = source:match("^(.*)/tests/[^/]+$") or "."
local bindings, removed, commands = {}, {}, {}
_G.hl = {
    bind = function(key, callback) bindings[key] = callback end,
    unbind = function(key) removed[#removed + 1] = key; bindings[key] = nil end,
    exec_cmd = function(command) commands[#commands + 1] = command end,
}
local configure = dofile(root .. "/integration/overview.lua")
configure("SUPER + CTRL + SHIFT + O")
bindings["SUPER + CTRL + SHIFT + O"]()
assert(commands[1] == "omarchy-shell io.github.kirollosatef.hyprscroll2d open")
configure("SUPER + CTRL + SHIFT + O")
assert(#removed == 0, "unchanged shortcut was unnecessarily rebound")
configure("SUPER + F8")
assert(removed[1] == "SUPER + CTRL + SHIFT + O" and bindings["SUPER + F8"])
print("ok - configurable overview binding")
