import QtQuick
import "../theme"

Rectangle {
    id: cardRoot
    radius: Theme.radiusLarge
    color: Theme.surface
    border.color: Theme.border
    border.width: 1

    property bool hoverable: true

    Behavior on color {
        ColorAnimation { duration: Theme.durationFast }
    }

    Behavior on border.color {
        ColorAnimation { duration: Theme.durationFast }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: cardRoot.hoverable
        // Pass clicks through if not explicitly handled here
        propagateComposedEvents: true 
        
        onEntered: {
            if (cardRoot.hoverable) {
                cardRoot.color = Theme.surfaceHover
                cardRoot.border.color = Theme.primary
            }
        }
        
        onExited: {
            if (cardRoot.hoverable) {
                cardRoot.color = Theme.surface
                cardRoot.border.color = Theme.border
            }
        }
    }
}
