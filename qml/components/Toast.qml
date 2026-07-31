import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    property string title: ""
    property string message: ""
    property string type: "info"
    
    width: 320
    implicitHeight: 64
    radius: 8
    color: "#0f172a"
    border.color: type === "success" ? "#22c55e" : (type === "error" ? "#ef4444" : (type === "warning" ? "#f59e0b" : "#3b82f6"))
    border.width: 1

    Row {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Rectangle {
            width: 4; height: parent.height
            radius: 2
            color: root.border.color
        }

        Column {
            width: parent.width - 24
            spacing: 2
            Text { text: root.title; color: "#f8fafc"; font.bold: true; font.pixelSize: 12 }
            Text { text: root.message; color: "#94a3b8"; font.pixelSize: 11; elide: Text.ElideRight; width: parent.width }
        }
    }

    ParallelAnimation {
        id: showAnim
        NumberAnimation { target: root; property: "opacity"; from: 0; to: 1; duration: 200 }
        NumberAnimation { target: root; property: "y"; from: root.y + 20; to: root.y; duration: 200 }
    }

    Timer {
        interval: 3500
        running: true
        onTriggered: root.destroy()
    }

    Component.onCompleted: showAnim.start()
}
