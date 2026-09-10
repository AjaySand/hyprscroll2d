local function current_dir()
    local source = debug and debug.getinfo(1, "S").source
    if type(source) ~= "string" or source:sub(1, 1) ~= "@" then
        error("hyprscroll2d: unable to resolve layout directory")
    end
    return source:sub(2):match("^(.*)/[^/]*$")
end

local function load_relative(filename)
    local chunk, err = loadfile(current_dir() .. "/" .. filename)
    if not chunk then error(err) end
    return chunk()
end

return function(config)
if type(config) ~= "table" then error("hyprscroll2d: configuration table required") end
if rawget(_G, "__hyprscroll2d_set_config") then
    _G.__hyprscroll2d_set_config(config)
    return true
end

local active_config = config
local core = load_relative("core.lua")
local overview = load_relative("overview.lua")
local json = load_relative("json.lua")
local workspaces = {}
local contexts = {}
local session = nil
local next_token = 0
local preserve_camera_address = nil

local function apply_input_config(value)
    hl.config({
        input = {
            follow_mouse = value.focus_follows_mouse and 1 or 0,
        },
    })
end

apply_input_config(active_config)

local function safe_field(value, field)
    if value == nil then return nil end
    local ok, result = pcall(function() return value[field] end)
    if ok then return result end
end

local function target_id(target, index)
    local window = safe_field(target, "window")
    local stable_id = safe_field(window, "stable_id")
    if stable_id ~= nil then return tostring(stable_id) end
    local address = safe_field(window, "address")
    if address then return "address:" .. tostring(address) end
    return "target:" .. tostring(safe_field(target, "index") or index)
end

local function workspace_key(ctx)
    for _, target in ipairs(ctx.targets or {}) do
        local window = safe_field(target, "window")
        local workspace = safe_field(window, "workspace")
        local id = safe_field(workspace, "id")
        if id ~= nil then return "workspace:" .. tostring(id) end
        local name = safe_field(workspace, "name")
        if name then return "workspace-name:" .. tostring(name) end
    end
    return active_config.workspace and "workspace:" .. tostring(active_config.workspace) or "global"
end

local function describe(ctx)
    local descriptors = {}
    local active_id = nil

    for index, target in ipairs(ctx.targets or {}) do
        local window = safe_field(target, "window")
        local id = target_id(target, index)
        if window then descriptors[id] = {
            id = id,
            target = target,
            window = window,
            address = safe_field(window, "address"),
        } end
        if safe_field(window, "active") then active_id = id end
    end

    return descriptors, active_id
end

local function context(ctx)
    local key = workspace_key(ctx)
    contexts[key] = ctx
    local state = workspaces[key]
    if not state then
        state = core.new_state()
        workspaces[key] = state
    end

    local descriptors, active_id = describe(ctx)
    local ids = {}
    for _, target in ipairs(ctx.targets or {}) do
        if safe_field(target, "window") then table.insert(ids, target_id(target, #ids + 1)) end
    end
    if session and session.key == key then active_id = nil end
    core.sync(state, ids, active_id, active_config)
    if session and session.key == key then overview.sync(state, session) end

    return state, descriptors
end

local function focus_descriptor(descriptor)
    if not descriptor or not descriptor.address then return end
    hl.dispatch(hl.dsp.focus({ window = "address:" .. descriptor.address }))
end

local function recalculate(ctx)
    local state, descriptors = context(ctx)
    local placements = core.placements(state, ctx.area, active_config)
    if session and session.key == workspace_key(ctx) and session.capturing then
        placements = overview.capture_placements(placements, ctx.area)
    end

    for id, descriptor in pairs(descriptors) do
        local placement = placements[id]
        if placement then descriptor.target:place(placement) end
    end
end

local function prepare_finish(confirm, id)
    if not session then return end
    local current = session
    local ctx = contexts[current.key]
    local state = context(ctx)
    local target = overview.finish(core, state, current, confirm, id)
    if confirm and not target then return false end
    current.capturing = false
    current.finishing = true
    current.confirm = confirm
    current.target = target
    recalculate(ctx)
    return true
end

local function finish_overview(confirm, id)
    if not session or not prepare_finish(confirm, id) then return false end
    local ctx = contexts[session.key]
    local _, descriptors = context(ctx)
    local target = session.target
    local descriptor = target and descriptors[target]
    preserve_camera_address = not confirm and descriptor and descriptor.address or nil
    focus_descriptor(descriptor)
    session = nil
    recalculate(ctx)
    return true
end

local watchdog
watchdog = hl.timer(function()
    finish_overview(false)
    watchdog:set_enabled(false)
end, { timeout = 3000, type = "repeat" })
watchdog:set_enabled(false)

_G.__hyprscroll2d_overview = function(action, workspace, token, argument)
    local key = "workspace:" .. tostring(workspace)
    local ctx = contexts[key]
    if not ctx then return json({ active = false, error = "No tiled windows on this workspace." }) end
    if action == "open" then
        if session then return json({ active = false, error = "Overview is already open." }) end
        if hl.get_active_workspace().id ~= workspace then
            return json({ active = false, error = "Switch to the canvas workspace first." })
        end
        local state = context(ctx)
        session = overview.open(state)
        if not session then return json({ active = false, error = "No tiled windows on this workspace." }) end
        next_token = next_token + 1
        session.key, session.token = key, next_token
    elseif not session or session.key ~= key or session.token ~= token then
        return json({ active = false, error = "Overview session ended." })
    end

    watchdog:set_timeout(3000)
    if action == "cancel" or action == "confirm" then
        prepare_finish(action == "confirm", argument ~= "" and argument or nil)
    elseif action == "release" and session.finishing then
        -- A window can close between Enter and the end of the zoom animation.
        if not finish_overview(session.confirm, session.target) then finish_overview(false) end
        watchdog:set_enabled(false)
        return json({ active = false })
    elseif action == "capture" then
        session.capturing = true
        recalculate(ctx)
    elseif action == "navigate" then
        overview.navigate(core, workspaces[key], session, argument)
    elseif action ~= "open" and action ~= "snapshot" then
        return json({ active = true, error = "Unknown overview action." })
    end

    local state, descriptors = context(ctx)
    if not session.selected_id then
        finish_overview(false)
        watchdog:set_enabled(false)
        return json({ active = false })
    end
    local placements = session.finishing and core.placements(state, ctx.area, active_config)
        or overview.placements(core, state, session, ctx.area, active_config)
    local windows = {}
    for _, id in ipairs(state.ids) do
        local descriptor = descriptors[id]
        local position = state.positions[id]
        windows[#windows + 1] = {
            id = id, address = descriptor.address, col = position.col, row = position.row,
            box = placements[id], title = safe_field(descriptor.window, "title") or "",
        }
    end
    return json({ active = not session.finishing, closing = session.finishing == true,
        token = session.token, selected = session.finishing and state.focused_id or session.selected_id,
        camera = session.finishing and state.camera or session.camera, area = ctx.area, windows = windows })
end

local function layout_msg(ctx, message)
    if session then return "hyprscroll2d: close overview before changing the layout" end
    preserve_camera_address = nil
    local state, descriptors = context(ctx)
    local command, argument, extra = message:match("^(%S+)%s*(%S*)%s*(%S*)$")

    if command == "focus" then
        local id = core.focus(state, argument)
        focus_descriptor(id and descriptors[id])
    elseif command == "move" then
        core.move(state, argument)
    elseif command == "pan" then
        core.pan(state, argument)
    elseif command == "follow" or command == "center" then
        core.follow(state)
    elseif command == "resize" and argument == "width" then
        if extra ~= "grow" and extra ~= "shrink" then
            return "hyprscroll2d: resize width expects grow or shrink"
        end
        core.resize_width(state, active_config, extra == "grow" and 1 or -1)
    elseif command == "resize" and argument == "height" then
        if extra ~= "grow" and extra ~= "shrink" then
            return "hyprscroll2d: resize height expects grow or shrink"
        end
        core.resize_height(state, active_config, extra == "grow" and 1 or -1)
    else
        return "hyprscroll2d: expected focus/move/pan <direction>, resize width/height grow/shrink, or center"
    end

    return true
end

local function window_layout_name(window)
    local layout = safe_field(window, "layout")
    return safe_field(layout, "name")
end

if not rawget(_G, "__hyprscroll2d_focus_subscription") then
    local ok, subscription = pcall(function()
        return hl.on("window.active", function(window)
            if session then return end
            if preserve_camera_address == safe_field(window, "address") then return end
            preserve_camera_address = nil
            if window_layout_name(window) == "lua:hyprscroll2d" then
                hl.dispatch(hl.dsp.layout("follow"))
            end
        end)
    end)
    if ok then _G.__hyprscroll2d_focus_subscription = subscription or true end
end

hl.layout.register("hyprscroll2d", {
    recalculate = recalculate,
    layout_msg = layout_msg,
})

_G.__hyprscroll2d_set_config = function(next_config)
    finish_overview(false)
    watchdog:set_enabled(false)
    active_config = next_config
    apply_input_config(active_config)
end
_G.__hyprscroll2d_layout_registered = true
return true
end
