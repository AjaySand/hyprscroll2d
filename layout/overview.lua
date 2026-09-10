local M = {}

local function camera_copy(camera)
    return { col = camera.col, row = camera.row }
end

function M.open(state)
    if not state.focused_id then return nil end
    return {
        original_id = state.focused_id,
        original_camera = camera_copy(state.camera),
        selected_id = state.focused_id,
        camera = camera_copy(state.camera),
        capturing = false,
    }
end

local function reveal(session, position)
    session.camera.col = math.max(position.col - 1, math.min(position.col + 1, session.camera.col))
    session.camera.row = math.max(position.row - 1, math.min(position.row + 1, session.camera.row))
end

function M.navigate(core, state, session, direction)
    local id = core.neighbor(state, session.selected_id, direction)
    if not id then return false end
    session.selected_id = id
    reveal(session, state.positions[id])
    return true
end

function M.sync(state, session)
    if not state.positions[session.selected_id] then
        session.selected_id = state.focused_id
        if session.selected_id then reveal(session, state.positions[session.selected_id]) end
    end
end

function M.finish(core, state, session, confirm, id)
    if confirm then
        local selected = id or session.selected_id
        if not state.positions[selected] then return nil end
        state.focused_id = selected
        state.observed_active_id = selected
        core.follow(state)
    else
        if state.positions[session.original_id] then
            state.focused_id = session.original_id
            state.observed_active_id = session.original_id
        end
        state.camera = camera_copy(session.original_camera)
    end
    return state.focused_id
end

function M.placements(core, state, session, area, config)
    local view = setmetatable({ camera = session.camera }, { __index = state })
    return core.placements(view, area, config)
end

function M.capture_placements(placements, area)
    local result = {}
    -- Hyprland 0.56 only exports windows intersecting their monitor. Keep their
    -- normal sizes behind the opaque overlay so distant windows can be captured.
    for id, box in pairs(placements) do
        result[id] = { x = math.floor(area.x + (area.w - box.w) / 2), y = math.floor(area.y + (area.h - box.h) / 2), w = box.w, h = box.h }
    end
    return result
end

return M
