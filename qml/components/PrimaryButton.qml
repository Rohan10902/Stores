import QtQuick 2.15
import QtQuick.Controls 2.15
import "../theme"

Button {
    id: control
    text: "Action"
    
    contentItem: Text {
        text: control.text
        font: Theme.fontBody
        color: Theme.surface
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        implicitWidth: 120
        implicitHeight: 40
        radius: Theme.radius
        color: control.down || control.hovered ? Theme.primaryHover : Theme.primary
        
        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }
}
