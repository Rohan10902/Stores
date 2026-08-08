import QtQuick
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root
    property string text: ""
    property string iconSource: ""
    property bool isActive: false
    signal clicked()

    Layout.fillWidth: true
    Layout.preferredHeight: 40
    radius: Theme.radiusMedium
    color: isActive ? Theme.surfaceHover : (mouseArea.containsMouse ? Qt.darker(Theme.surfaceHover, 1.2) : "transparent")

    Behavior on color { ColorAnimation { duration: Theme.durationFast } }

    Rectangle {
        width: 3
        height: parent.height - Theme.spacingMedium
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 2
        radius: 2
        color: Theme.primary
        visible: root.isActive
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingMedium + (root.isActive ? 8 : 0)
        spacing: Theme.spacingMedium

        Text {
            text: root.text
            color: root.isActive ? Theme.primary : Theme.textPrimary
            font.pixelSize: 14
            font.bold: root.isActive
            Layout.fillWidth: true
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
        cursorShape: Qt.PointingHandCursor
    }
}
