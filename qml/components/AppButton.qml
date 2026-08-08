import QtQuick
import QtQuick.Controls
import "../theme"

Button {
    id: control
    property string text: "Button"
    
    implicitWidth: Math.max(120, contentItem.implicitWidth + Theme.spacingLarge * 2)
    implicitHeight: Theme.buttonHeight
    hoverEnabled: true

    contentItem: Text {
        text: control.text
        font.pixelSize: 14
        font.bold: true
        color: Theme.textPrimary
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        radius: Theme.radiusMedium
        color: "transparent"
        border.color: control.pressed ? Theme.primary : (control.hovered ? Theme.textSecondary : "transparent")
        border.width: 1
        
        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
    }
    
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.PointingHandCursor
    }
}
