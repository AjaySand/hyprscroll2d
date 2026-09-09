local source = debug and debug.getinfo(1, "S").source
if type(source) ~= "string" or source:sub(1, 1) ~= "@" then
    error("hyprscroll2d: unable to resolve plugin directory")
end

local integration_dir = source:sub(2):match("^(.*)/[^/]*$")
local root_dir = integration_dir and integration_dir:match("^(.*)/integration$")
if not root_dir then error("hyprscroll2d: invalid plugin directory") end

return function(config)
    if type(config) ~= "table" then error("hyprscroll2d: configuration table required") end

    dofile(root_dir .. "/layout/init.lua")(config)
    if not rawget(_G, "__hyprscroll2d_omarchy_integrated") then
        dofile(root_dir .. "/integration/omarchy.lua")
    end
    hl.workspace_rule({ workspace = tostring(config.workspace), layout = "lua:hyprscroll2d" })
    return true
end
