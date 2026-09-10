local source = debug.getinfo(1, "S").source:sub(2)
local tests_dir = source:match("^(.*)/[^/]+$") or "tests"
local root = tests_dir:match("^(.*)/tests$") or "."

local registered = nil
local dispatched = {}
local configured = {}
local timers = {}

_G.__hyprscroll2d_focus_subscription = nil
_G.hl = {
    timer = function(callback)
        local timer = { callback = callback, enabled = true }
        function timer:set_enabled(value) self.enabled = value end
        function timer:set_timeout(_) self.enabled = true end
        table.insert(timers, timer)
        return timer
    end,
    get_active_workspace = function() return { id = 9 } end,
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
    workspace = 9,
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

local function overview_request(action, token, argument)
    return _G.__hyprscroll2d_overview(action, 9, token or 0, argument or "")
end

local function open_overview()
    return assert(tonumber(overview_request("open"):match('"token":(%d+)')))
end

registered.provider.layout_msg(ctx, "pan down")
local before_x, before_y = a.placed.x, a.placed.y
registered.provider.recalculate(ctx)
before_x, before_y = a.placed.x, a.placed.y
local before_width, before_height = a.placed.w, a.placed.h
local token = open_overview()
local dispatch_count = #dispatched
overview_request("capture", token)
assert(a.placed.x == b.placed.x, "off-screen windows were not staged for capture")
assert(a.placed.w == before_width and a.placed.h == before_height, "capture resized a client")
overview_request("navigate", token, "right")
assert(#dispatched == dispatch_count, "overview navigation changed application focus")
assert(type(registered.provider.layout_msg(ctx, "move right")) == "string", "layout mutations escaped overview")
assert(overview_request("cancel", token):find('"closing":true', 1, true))
assert(a.placed.x == before_x and a.placed.y == before_y, "cancel lost a manually panned camera")
assert(#dispatched == dispatch_count, "focus changed before the overlay released its grab")
overview_request("release", token)
assert(a.placed.x == before_x and a.placed.y == before_y)
assert(not timers[1].enabled, "watchdog remained active after dismissal")

token = open_overview()
overview_request("capture", token)
assert(overview_request("cancel", token - 1):find("Overview session ended", 1, true))
assert(a.placed.x == b.placed.x, "a stale request changed the current session")
dispatch_count = #dispatched
overview_request("confirm", token, "B")
assert(#dispatched == dispatch_count, "confirmation focused a window under the keyboard grab")
overview_request("release", token)
assert(dispatched[#dispatched].window == "address:0xB", "click confirmation focused the wrong window")

token = open_overview()
overview_request("capture", token)
overview_request("confirm", token, "B")
ctx.targets = { a }
registered.provider.recalculate(ctx)
overview_request("release", token)
assert(not timers[1].enabled, "closing the confirmed window stranded the overview session")
assert(overview_request("snapshot", token):find("Overview session ended", 1, true))
ctx.targets = { a, b }
a.window.active, b.window.active = false, true
registered.provider.recalculate(ctx)
before_x, before_y = a.placed.x, a.placed.y
token = open_overview()
overview_request("capture", token)
timers[1].callback()
assert(a.placed.x == before_x and a.placed.y == before_y, "watchdog failed to restore normal placements")
assert(not timers[1].enabled, "watchdog kept running after expiry")

token = open_overview()
overview_request("capture", token)
ctx.targets = { a }
registered.provider.recalculate(ctx)
local remaining = overview_request("snapshot", token)
assert(not remaining:find('"id":"B"', 1, true), "closed windows remained in overview")
ctx.targets = {}
registered.provider.recalculate(ctx)
assert(overview_request("snapshot", token):find('"active":false', 1, true), "empty workspace kept overview alive")
print("ok - overview IPC, staging, input guards, focus handoff, stale requests, watchdog, and closed windows")
