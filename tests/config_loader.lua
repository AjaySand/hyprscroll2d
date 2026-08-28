local source = debug.getinfo(1, "S").source:sub(2)
local tests_dir = source:match("^(.*)/[^/]+$") or "tests"
local root = tests_dir:match("^(.*)/tests$") or "."
local loader = assert(loadfile(root .. "/layout/config_loader.lua"))()
local defaults = assert(loadfile(root .. "/layout/config.lua"))()

local function equal(actual, expected, label)
    assert(actual == expected, string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
end

local function fake_options(overrides)
    return {
        path = "/config/hyprscroll2d/config.lua",
        exists = function() return overrides ~= nil end,
        loadfile = function()
            return function() return overrides end
        end,
    }
end

equal(loader.override_path(function(name)
    if name == "XDG_CONFIG_HOME" then return "/xdg" end
end), "/xdg/hyprscroll2d/config.lua", "XDG path")

equal(loader.override_path(function(name)
    if name == "HOME" then return "/home/test" end
end), "/home/test/.config/hyprscroll2d/config.lua", "home path")

equal(loader.load(defaults, fake_options(nil)), defaults, "missing override")

local config = loader.load(defaults, fake_options({ peek_x = 10 }))
equal(config.peek_x, 10, "overridden value")
equal(config.peek_y, defaults.peek_y, "default value")

config = loader.load(defaults, fake_options({ focus_follows_mouse = false }))
equal(config.focus_follows_mouse, false, "mouse focus override")

local steps = { 0.25, 0.50, 1.00 }
config = loader.load(defaults, fake_options({ width_steps = steps, default_width_step = 2 }))
equal(config.width_steps, steps, "step array replacement")
equal(config.default_width_step, 2, "step default override")

local ok, err = pcall(loader.load, defaults, fake_options({ typo = 1 }))
assert(not ok and err:match("unknown setting"), "unknown settings should fail")

ok, err = pcall(loader.load, defaults, fake_options({ width_steps = { 0.5 }, default_width_step = 2 }))
assert(not ok and err:match("default_width_step"), "out-of-range defaults should fail")

ok, err = pcall(loader.load, defaults, fake_options({ focus_follows_mouse = 0 }))
assert(not ok and err:match("focus_follows_mouse"), "mouse focus must be a boolean")

ok, err = pcall(loader.load, defaults, {
    path = "/broken.lua",
    exists = function() return true end,
    loadfile = function() return nil, "syntax error" end,
})
assert(not ok and err:match("syntax error"), "syntax errors should include the loader error")

print("ok - config loader")
