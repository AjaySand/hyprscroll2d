return function(key)
    local previous = rawget(_G, "__hyprscroll2d_overview_key")
    if previous == key then return end
    if previous then hl.unbind(previous) end
    hl.bind(key, function()
        hl.exec_cmd("omarchy-shell io.github.kirollosatef.hyprscroll2d open")
    end, { description = "Open 2D canvas overview" })
    _G.__hyprscroll2d_overview_key = key
end
