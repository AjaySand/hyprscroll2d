import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

    required property int workspace
    property bool opened: false
    property string phase: "idle"
    property var display: null
    property var snapshot: null
    property int token: 0
    property bool cancelPending: false
    property var queue: []
    property var request: null
    property bool received: false
    property var pressedKeys: []
    property string errorMessage: ""
    property bool releasePending: false
    property bool previewReady: false
    property alias windows: windows

    ListModel { id: windows; dynamicRoles: true }

    function open() {
        if (root.phase !== "idle") return
        if (!Hyprland.focusedWorkspace || Hyprland.focusedWorkspace.id !== root.workspace) return
        const monitor = Hyprland.focusedMonitor
        const screen = Quickshell.screens.find(screen => monitor && screen.name === monitor.name)
        if (!screen) return
        root.display = screen
        root.snapshot = null
        windows.clear()
        root.token = 0
        root.errorMessage = ""
        root.releasePending = false
        root.previewReady = false
        root.cancelPending = false
        root.pressedKeys = []
        root.phase = "opening"
        root.opened = true
        opening.start()
    }

    function enqueue(action, argument) {
        root.queue = root.queue.concat([{ action: action, argument: argument || "" }])
        pump.restart()
    }

    function navigate(direction) {
        if (root.phase === "active") root.enqueue("navigate", direction)
    }

    function finish(confirm, id) {
        if (!root.opened || (root.phase !== "active" && root.phase !== "opening")) return
        if (root.phase === "opening") {
            root.cancelPending = true
            return
        }
        root.phase = "closing"
        root.enqueue(confirm ? "confirm" : "cancel", id)
    }

    function receive(text) {
        const action = root.request.action
        root.received = true
        deadline.stop()
        transport.connected = false
        let result
        try {
            result = JSON.parse(text)
        } catch (error) {
            root.fail("Cannot read overview state: " + text)
            return
        }
        if (result.error) {
            root.fail(result.error)
            return
        }
        if (result.windows) root.updateSnapshot(result)
        if (!result.active) {
            if (action === "release") {
                root.opened = false
                root.phase = "idle"
                root.snapshot = null
                root.token = 0
                root.queue = []
                return
            }
            if (root.phase === "releasing") return
            root.phase = "closing"
            root.releasePending = result.closing === true
            root.queue = []
            if (!closing.running) {
                closing.interval = 450
                closing.start()
            }
            return
        }
        root.token = result.token
        if (action === "open") {
            root.phase = "active"
            if (root.cancelPending) root.finish(false)
            else root.enqueue("capture")
        } else if (action === "confirm") {
            root.phase = "active"
        }
    }

    function updateSnapshot(result) {
        root.snapshot = result
        for (let i = windows.count - 1; i >= 0; i--) {
            if (!result.windows.some(window => window.id === windows.get(i).id)) windows.remove(i)
        }
        for (const window of result.windows) {
            let index = -1
            for (let i = 0; i < windows.count; i++) {
                if (windows.get(i).id === window.id) { index = i; break }
            }
            if (index < 0) windows.append(window)
            else windows.set(index, window)
        }
    }

    function fail(message) {
        console.warn("Hyprscroll2D overview:", message)
        root.errorMessage = message
        root.phase = "closing"
        root.queue = []
        deadline.stop()
        // Keep the opaque cover until the compositor's restoration lease expires.
        closing.interval = 3500
        closing.start()
    }

    IpcHandler {
        target: "io.github.kirollosatef.hyprscroll2d"
        function open(): void { root.open() }
    }

    Loader {
        active: root.opened
        sourceComponent: Overview {
            controller: root
            screen: root.display
        }
    }

    Timer {
        id: opening
        interval: 100
        onTriggered: root.enqueue("open")
    }

    Timer {
        id: pump
        interval: 0
        onTriggered: {
            if (root.request || transport.connected || root.queue.length === 0) return
            root.request = root.queue[0]
            root.queue = root.queue.slice(1)
            root.received = false
            transport.connected = true
            deadline.start()
        }
    }

    Socket {
        id: transport
        path: Hyprland.requestSocketPath
        onConnectedChanged: {
            if (connected) {
                const call = "__hyprscroll2d_overview(" + JSON.stringify(root.request.action)
                    + "," + root.workspace + "," + root.token + "," + JSON.stringify(root.request.argument) + ")"
                transport.write("/repl return " + call + " .. '\\n'")
                transport.flush()
            } else if (root.request) {
                if (!root.received) root.fail("The compositor did not return overview state.")
                root.request = null
                pump.restart()
            }
        }
        parser: SplitParser { onRead: data => root.receive(data) }
        onError: error => {
            if (!root.received && root.request) root.fail("Cannot communicate with the compositor.")
        }
    }

    Timer {
        id: deadline
        interval: 2000
        onTriggered: {
            root.fail("The compositor did not respond.")
            transport.connected = false
            root.request = null
        }
    }

    Timer {
        interval: 3000
        running: root.phase === "active" && !root.previewReady
        onTriggered: root.fail("Window previews are unavailable. Restoring the canvas.")
    }

    Timer {
        interval: 500
        running: root.token > 0 && (root.phase === "active" || (root.phase === "closing" && root.errorMessage === ""))
        repeat: true
        onTriggered: {
            if (root.queue.length === 0 && !root.request) root.enqueue("snapshot")
        }
    }

    Timer {
        id: closing
        onTriggered: {
            if (root.pressedKeys.length > 0) { closing.restart(); return }
            if (root.errorMessage !== "" || !root.releasePending) {
                root.opened = false
                root.phase = "idle"
                root.snapshot = null
                root.token = 0
            } else {
                root.opened = false
                root.phase = "releasing"
                release.start()
            }
        }
    }

    Timer {
        id: release
        interval: 50
        onTriggered: root.enqueue("release")
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (!root.opened) return
            if (event.name === "configreloaded"
                || (event.name === "monitorremoved" && event.data === root.display.name)
                || (event.name === "workspacev2" && Number(event.data.split(",")[0]) !== root.workspace)
                || (event.name === "focusedmon" && event.data.split(",")[0] !== root.display.name)) root.finish(false)
        }
    }
}
