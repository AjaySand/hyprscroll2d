if rawget(_G, "__hyprscroll2d_plugin_loaded") then return true end

local source = debug and debug.getinfo(1, "S").source
if type(source) ~= "string" or source:sub(1, 1) ~= "@" then
    error("hyprscroll2d: unable to resolve plugin directory")
end

local integration_dir = source:sub(2):match("^(.*)/[^/]*$")
local root_dir = integration_dir and integration_dir:match("^(.*)/integration$")
if not root_dir then error("hyprscroll2d: invalid plugin directory") end

dofile(root_dir .. "/layout/init.lua")
dofile(root_dir .. "/integration/omarchy.lua")
hl.workspace_rule({ workspace = "9", layout = "lua:hyprscroll2d" })

_G.__hyprscroll2d_plugin_loaded = true
return true
