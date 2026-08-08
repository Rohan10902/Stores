import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Card {
    id: root
    property string title: ""
    property string description: ""
    property string buttonText: ""
    signal clicked()

    Layout.fillWidth: true
    // FIXED: Hard-clamp card height metrics per requirements to prevent empty-space stretching
    Layout.preferredHeight: 140
    Layout.minimumHeight: 140
    Layout.maximumHeight: 140
    Layout.alignment: Qt.AlignTop

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingMedium
        spacing: Theme.spacingSmall

        Text {
            text: root.title
            color: Theme.textPrimary
            font.pixelSize: 16
            font.bold: true
            Layout.fillWidth: true
        }

        Text {
            text: root.description
            color: Theme.textSecondary
            font.pixelSize: 13
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            verticalAlignment: Text.AlignTop
        }

        Item { Layout.fillHeight: true }

        PrimaryButton {
            text: root.buttonText
            Layout.alignment: Qt.AlignRight
            onClicked: root.clicked()
        }
    }
}
