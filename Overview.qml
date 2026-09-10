import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: root
    required property var controller
    readonly property var snapshot: controller.snapshot
    property real zoom: controller.previewReady && controller.phase === "active" ? 1 / 3 : 1
    readonly property real previewScale: snapshot ? Math.min(canvas.width / snapshot.area.w, canvas.height / snapshot.area.h) * zoom : 0
    Behavior on zoom { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    anchors { top: true; right: true; bottom: true; left: true }
    color: "#10141c"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "hyprscroll2d-overview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Image {
        anchors.fill: parent
        source: root.controller.wallpaperSource
        fillMode: Image.PreserveAspectCrop
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Component.onCompleted: forceActiveFocus()
        Keys.onPressed: event => {
            event.accepted = true
            if (!root.controller.pressedKeys.includes(event.key))
                root.controller.pressedKeys = root.controller.pressedKeys.concat([event.key])
            if (event.key === Qt.Key_Escape) root.controller.finish(false)
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.controller.finish(true)
            else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) root.controller.navigate("left")
            else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) root.controller.navigate("down")
            else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) root.controller.navigate("up")
            else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) root.controller.navigate("right")
        }
        Keys.onReleased: event => {
            event.accepted = true
            if (!event.isAutoRepeat)
                root.controller.pressedKeys = root.controller.pressedKeys.filter(key => key !== event.key)
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onWheel: wheel => { wheel.accepted = true }
        }

        Item {
            id: canvas
            anchors.fill: parent
            clip: true

            Repeater {
                model: root.controller.windows
                delegate: Item {
                    id: card
                    required property var model
                    readonly property var modelData: model
                    readonly property bool selected: root.snapshot && root.snapshot.selected === modelData.id
                    readonly property var toplevel: Hyprland.toplevels.values.find(window => window.address === modelData.address.replace(/^0x/, "")) || null
                    readonly property bool inView: x + width > 0 && y + height > 0 && x < canvas.width && y < canvas.height
                    x: canvas.width / 2 + (modelData.box.x - root.snapshot.area.x - root.snapshot.area.w / 2) * root.previewScale
                    y: canvas.height / 2 + (modelData.box.y - root.snapshot.area.y - root.snapshot.area.h / 2) * root.previewScale
                    width: modelData.box.w * root.previewScale
                    height: modelData.box.h * root.previewScale
                    visible: inView

                    Rectangle {
                        anchors.fill: parent
                        color: "#202939"
                        border.color: card.selected ? "#83b9ff" : "#39465c"
                        border.width: card.selected ? 3 : 1
                        radius: 6
                    }

                    Loader {
                        anchors.fill: parent
                        anchors.margins: 5
                        active: card.inView
                        sourceComponent: ScreencopyView {
                            captureSource: card.toplevel ? card.toplevel.wayland : null
                            live: false
                            onHasContentChanged: if (hasContent) root.controller.previewReady = true
                            Text {
                                anchors.centerIn: parent
                                text: "Loading preview…"
                                color: "#9daac0"
                                visible: !parent.hasContent
                            }
                        }
                    }

                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 5 }
                        height: 30
                        color: "#e610141c"
                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            text: card.modelData.title
                            color: "#eef2fa"
                            font.pixelSize: 13
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.controller.finish(true, card.modelData.id)
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: root.controller.errorMessage !== "" || !root.snapshot
            text: root.controller.errorMessage || "Opening overview…"
            color: "#eef2fa"
            font.pixelSize: 16
        }

        Rectangle {
            anchors { bottom: parent.bottom; bottomMargin: 16; horizontalCenter: parent.horizontalCenter }
            width: hint.implicitWidth + 28
            height: 32
            radius: 16
            color: "#ed10141c"
            visible: root.controller.phase === "active"
            Text {
                id: hint
                anchors.centerIn: parent
                text: "↑ ↓ ← →  /  H J K L   Navigate        Enter / Click   Select        Esc   Return"
                color: "#a9b6ca"
                font.pixelSize: 14
            }
        }
    }
}
