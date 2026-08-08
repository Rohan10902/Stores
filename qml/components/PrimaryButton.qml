import QtQuick
import QtQuick.Controls
import "../theme"

Button {
    id: control
    property string text: "Button"
    
    implicitWidth: Math.max(120, contentItem.implicitWidth + Theme.spacingLarge * 2)
    implicitHeight: Theme.buttonHeight

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
    
    mouseArea.cursorShape: Qt.PointingHandCursor
}
