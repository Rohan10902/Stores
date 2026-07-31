import QtQuick
import QtQuick.Controls

Button {
    id: control

    contentItem: Text {
        text: control.text
        color: "#ffffff"
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
        color: control.pressed ? "#1d4ed8" : (control.hovered ? "#3b82f6" : "#2563eb")
        border.color: "#60a5fa"
        border.width: 1
    }
}
