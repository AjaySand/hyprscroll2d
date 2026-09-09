local source = debug.getinfo(1, "S").source:sub(2)
local tests_dir = source:match("^(.*)/[^/]+$") or "tests"
local root = tests_dir:match("^(.*)/tests$") or "."

local registered = nil
local dispatched = {}
local configured = {}

_G.__hyprscroll2d_focus_subscription = nil
_G.hl = {
    config = function(value)
        table.insert(configured, value)
    end,
    layout = {
        register = function(name, provider)
            registered = { name = name, provider = provider }
        end,
    },
    on = function()
        return true
    end,
    dispatch = function(dispatcher)
        table.insert(dispatched, dispatcher)
    end,
    dsp = {
        layout = function(message)
            return { kind = "layout", message = message }
        end,
        focus = function(options)
            return { kind = "focus", window = options.window }
        end,
    },
}

local configure = assert(loadfile(root .. "/layout/init.lua"))()
local config = {
    peek_x = 48,
    peek_y = 48,
    gap_x = 12,
    gap_y = 12,
    focus_follows_mouse = true,
    width_steps = { 0.50, 0.67, 0.85, 1.00 },
    height_steps = { 0.50, 0.67, 0.85, 1.00 },
    default_width_step = 2,
    default_height_step = 3,
}
configure(config)
assert(registered and registered.name == "hyprscroll2d", "layout did not register")
assert(configured[#configured].input.follow_mouse == 1, "focus follows mouse was not enabled")

local function target(id, active)
    return {
        window = {
            stable_id = id,
            address = "0x" .. id,
            active = active,
            workspace = { id = 9 },
            layout = { name = "lua:hyprscroll2d" },
        },
        place = function(self, box)
            self.placed = box
        end,
    }
end

local a = target("A", true)
local b = target("B", false)
local ctx = {
    area = { x = 0, y = 0, w = 1000, h = 800 },
    targets = { a, b },
}

registered.provider.recalculate(ctx)
assert(a.placed and b.placed, "recalculate did not place every target")
assert(a.placed.x < b.placed.x, "new targets should initially extend right")

local original_x = a.placed.x
local updated = {}
for key, value in pairs(config) do updated[key] = value end
updated.peek_x = 20
updated.focus_follows_mouse = false
configure(updated)
assert(configured[#configured].input.follow_mouse == 0, "focus follows mouse was not disabled")
registered.provider.recalculate(ctx)
assert(a.placed.x ~= original_x, "reconfiguration did not update the active layout")

local response = registered.provider.layout_msg(ctx, "focus right")
assert(response == true, "focus command was rejected")
assert(dispatched[#dispatched].kind == "focus", "focus command did not dispatch")
assert(dispatched[#dispatched].window == "address:0xB", "focus targeted the wrong window")

response = registered.provider.layout_msg(ctx, "resize height shrink")
assert(response == true, "height resize command was rejected")

response = registered.provider.layout_msg(ctx, "resize height sideways")
assert(type(response) == "string", "invalid resize command should return an error")

print("ok - mocked Hyprland adapter")
