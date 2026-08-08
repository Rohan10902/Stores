import QtQuick
import "../theme"

Rectangle {
    id: cardRoot
    radius: Theme.radiusLarge
    color: hoverHandler.hovered && hoverable ? Theme.surfaceHover : Theme.surface
    border.color: hoverHandler.hovered && hoverable ? Theme.primary : Theme.border
    border.width: 1

    property bool hoverable: true

    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

    HoverHandler {
        id: hoverHandler
        enabled: cardRoot.hoverable
    }
}
