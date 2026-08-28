local M = {}

local function default_exists(path)
    local file = io.open(path, "r")
    if not file then return false end
    file:close()
    return true
end

local function validate_steps(config, name)
    local steps = config[name]
    if type(steps) ~= "table" or #steps == 0 then
        error(name .. " must be a non-empty array")
    end

    local previous = 0
    for index, value in ipairs(steps) do
        if type(value) ~= "number" or value <= previous or value > 1 then
            error(string.format("%s[%d] must be greater than %.2f and at most 1", name, index, previous))
        end
        previous = value
    end
end

local function validate(config)
    for _, name in ipairs({ "peek_x", "peek_y", "gap_x", "gap_y" }) do
        if type(config[name]) ~= "number" or config[name] < 0 then
            error(name .. " must be a non-negative number")
        end
    end

    if type(config.focus_follows_mouse) ~= "boolean" then
        error("focus_follows_mouse must be a boolean")
    end

    validate_steps(config, "width_steps")
    validate_steps(config, "height_steps")

    for step_name, steps_name in pairs({
        default_width_step = "width_steps",
        default_height_step = "height_steps",
    }) do
        local value = config[step_name]
        if type(value) ~= "number" or value % 1 ~= 0 or value < 1 or value > #config[steps_name] then
            error(string.format("%s must select an entry in %s", step_name, steps_name))
        end
    end
end

function M.override_path(getenv)
    getenv = getenv or os.getenv
    local config_home = getenv("XDG_CONFIG_HOME")
    if config_home and config_home ~= "" then
        return config_home .. "/hyprscroll2d/config.lua"
    end

    local home = getenv("HOME")
    if home and home ~= "" then
        return home .. "/.config/hyprscroll2d/config.lua"
    end
end

function M.load(defaults, options)
    options = options or {}
    local path = options.path or M.override_path(options.getenv)
    local exists = options.exists or default_exists
    if not path or not exists(path) then return defaults end

    local loader = options.loadfile or loadfile
    local chunk, load_error = loader(path)
    if not chunk then error(string.format("hyprscroll2d: invalid config %s: %s", path, load_error)) end

    local ok, overrides = pcall(chunk)
    if not ok then error(string.format("hyprscroll2d: failed to load config %s: %s", path, overrides)) end
    if type(overrides) ~= "table" then
        error(string.format("hyprscroll2d: config %s must return a table", path))
    end

    local config = {}
    for name, value in pairs(defaults) do config[name] = value end
    for name, value in pairs(overrides) do
        if defaults[name] == nil then
            error(string.format("hyprscroll2d: unknown setting %q in %s", name, path))
        end
        config[name] = value
    end

    local valid, validation_error = pcall(validate, config)
    if not valid then error(string.format("hyprscroll2d: invalid config %s: %s", path, validation_error)) end
    return config
end

return M
