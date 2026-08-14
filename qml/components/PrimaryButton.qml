import QtQuick
import QtQuick.Controls
import "../theme"

Button {
    id: control

    text: "Button"
    implicitWidth: Math.max(120, contentItem.implicitWidth + Theme.spacingLarge * 2)
    implicitHeight: Theme.buttonHeight
    hoverEnabled: true

    contentItem: Text {
        text: control.text
        font.pixelSize: 13
        font.bold: true
        color: "#FFFFFF"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        radius: Theme.radiusMedium
        color: control.pressed
               ? Theme.primaryPressed
               : control.hovered
                 ? Theme.primaryHover
                 : Theme.primary
        border.color: control.activeFocus ? Theme.focusRing : "transparent"
        border.width: control.activeFocus ? 2 : 0

        Behavior on color {
            ColorAnimation { duration: Theme.durationFast }
        }
    }
}
