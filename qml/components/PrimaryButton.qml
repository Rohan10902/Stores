import QtQuick
import QtQuick.Controls
import "../theme"

Button {
    id: control
    
    implicitWidth: Math.max(120, contentItem.implicitWidth + Theme.spacingLarge * 2)
    implicitHeight: Theme.buttonHeight
    hoverEnabled: true

    contentItem: Text {
        text: control.text
        font.pixelSize: 14
        font.bold: true
        color: "#FFFFFF"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        radius: Theme.radiusMedium
        color: control.pressed ? Qt.darker(Theme.primary, 1.2) : (control.hovered ? Theme.primaryHover : Theme.primary)
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
    }
}
