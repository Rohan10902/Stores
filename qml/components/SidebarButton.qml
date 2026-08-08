import QtQuick
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root
    property string text: ""
    property string iconSource: ""
    signal clicked()

    Layout.fillWidth: true
    Layout.preferredHeight: 44
    radius: Theme.radiusMedium
    color: mouseArea.containsMouse ? Theme.surfaceHover : "transparent"

    Behavior on color { ColorAnimation { duration: Theme.durationFast } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingMedium
        spacing: Theme.spacingMedium

        Text {
            text: root.text
            color: Theme.textPrimary
            font.pixelSize: 15
            Layout.fillWidth: true
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
