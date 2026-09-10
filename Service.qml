import QtQuick
import Quickshell.Hyprland
import Quickshell.Io

Item {
    id: root

    property var shell: null
    property bool loadPending: false
    property int appliedWorkspace: -1
    readonly property string pluginId: "io.github.kirollosatef.hyprscroll2d"
    readonly property string bootstrapPath: decodeURIComponent(
        Qt.resolvedUrl("integration/plugin.lua").toString().replace(/^file:\/\//, "")
    )
    readonly property var settings: normalizedSettings(pluginEntry())

    function pluginEntry() {
        const plugins = shell && shell.shellConfig ? shell.shellConfig.plugins : null
        if (!Array.isArray(plugins)) return ({})
        for (let i = 0; i < plugins.length; i++) {
            if (plugins[i] && plugins[i].id === root.pluginId) return plugins[i]
        }
        return ({})
    }

    function finiteNumber(value, fallback, minimum, maximum) {
        const number = Number(value)
        if (!Number.isFinite(number)) return fallback
        return Math.max(minimum, Math.min(maximum, number))
    }

    function positiveSteps(value, fallback) {
        if (!Array.isArray(value) || value.length === 0) return fallback
        const result = []
        for (let i = 0; i < value.length; i++) {
            const step = Number(value[i])
            if (!Number.isFinite(step) || step <= 0 || step > 1) return fallback
            result.push(step)
        }
        return result
    }

    function normalizedSettings(entry) {
        const widthSteps = positiveSteps(entry.widthSteps, [0.50, 0.67, 0.85, 1.00])
        const heightSteps = positiveSteps(entry.heightSteps, [0.50, 0.67, 0.85, 1.00])
        return {
            overview_keybind: entry.overviewKeybind === undefined ? "SUPER + CTRL + SHIFT + O" : String(entry.overviewKeybind),
            workspace: Math.round(finiteNumber(entry.workspace, 9, 1, 99)),
            peek_x: finiteNumber(entry.peekX, 48, 0, 10000),
            peek_y: finiteNumber(entry.peekY, 48, 0, 10000),
            gap_x: finiteNumber(entry.gapX, 12, 0, 10000),
            gap_y: finiteNumber(entry.gapY, 12, 0, 10000),
            focus_follows_mouse: entry.focusFollowsMouse === undefined ? true : Boolean(entry.focusFollowsMouse),
            width_steps: widthSteps,
            height_steps: heightSteps,
            default_width_step: Math.round(finiteNumber(entry.defaultWidthStep, 2, 1, widthSteps.length)),
            default_height_step: Math.round(finiteNumber(entry.defaultHeightStep, 3, 1, heightSteps.length))
        }
    }

    function luaQuote(value) {
        return "\"" + value
            .replace(/\\/g, "\\\\")
            .replace(/\"/g, "\\\"")
            .replace(/\n/g, "\\n")
            .replace(/\r/g, "\\r") + "\""
    }

    function luaArray(values) {
        return "{" + values.map(value => Number(value).toString()).join(",") + "}"
    }

    function luaSettings(value) {
        return "{workspace=" + value.workspace
            + ",overview_keybind=" + root.luaQuote(value.overview_keybind)
            + ",peek_x=" + value.peek_x
            + ",peek_y=" + value.peek_y
            + ",gap_x=" + value.gap_x
            + ",gap_y=" + value.gap_y
            + ",focus_follows_mouse=" + (value.focus_follows_mouse ? "true" : "false")
            + ",width_steps=" + luaArray(value.width_steps)
            + ",height_steps=" + luaArray(value.height_steps)
            + ",default_width_step=" + value.default_width_step
            + ",default_height_step=" + value.default_height_step + "}"
    }

    function loadLayout() {
        if (loader.running) {
            root.loadPending = true
            return
        }
        const bootstrap = "dofile(" + root.luaQuote(root.bootstrapPath) + ")(" + root.luaSettings(root.settings) + ")"
        loader.command = ["hyprctl", "eval", bootstrap]
        loader.running = true
        root.appliedWorkspace = root.settings.workspace
    }

    Component.onCompleted: loadTimer.start()

    OverviewController { workspace: root.settings.workspace }
    onSettingsChanged: {
        if (root.appliedWorkspace !== -1 && root.appliedWorkspace !== root.settings.workspace) {
            reloader.running = true
        } else {
            loadTimer.restart()
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event && event.name === "configreloaded") loadTimer.restart()
        }
    }

    Timer {
        id: loadTimer
        interval: 150
        onTriggered: root.loadLayout()
    }

    Process {
        id: loader

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const message = text.trim()
                if (message && message !== "ok") console.warn("Hyprscroll2D:", message)
            }
        }

        onRunningChanged: {
            if (!running && root.loadPending) {
                root.loadPending = false
                loadTimer.restart()
            }
        }

        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const message = text.trim()
                if (message) console.warn("Hyprscroll2D:", message)
            }
        }
    }

    Process {
        id: reloader
        command: ["hyprctl", "reload"]
    }
}
