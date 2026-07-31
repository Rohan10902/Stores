import QtQuick
import QtQuick.Controls

Button {
    id: control

    contentItem: Text {
        text: control.text
        color: control.enabled ? "#f8fafc" : "#64748b"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        font.pixelSize: 12
        font.bold: true
    }

    background: Rectangle {
        implicitWidth: Math.max(80, contentItem.implicitWidth + 20)
        implicitHeight: 32
        radius: 6
        color: control.pressed ? "#334155" : (control.hovered ? "#1e293b" : "#0f172a")
        border.color: control.hovered ? "#3b82f6" : "#334155"
        border.width: 1
    }
}
