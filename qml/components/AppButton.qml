import QtQuick
import QtQuick.Controls
import "../theme"

Button {
    id: control

    text: "Button"
    implicitWidth: Math.max(112, contentItem.implicitWidth + Theme.spacingLarge * 2)
    implicitHeight: Theme.buttonHeight
    hoverEnabled: true

    contentItem: Text {
        text: control.text
        font.pixelSize: 13
        font.bold: true
        color: control.enabled ? Theme.textPrimary : Theme.textDisabled
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        radius: Theme.radiusMedium
        color: control.hovered ? Theme.surfaceHover : "transparent"
        border.color: control.activeFocus || control.hovered
                      ? Theme.borderStrong
                      : Theme.border
        border.width: 1

        Behavior on color {
            ColorAnimation { duration: Theme.durationFast }
        }

        Behavior on border.color {
            ColorAnimation { duration: Theme.durationFast }
        }
    }
}
