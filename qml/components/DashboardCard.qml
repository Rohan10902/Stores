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
    Layout.preferredHeight: 180
    Layout.minimumWidth: 300

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingLarge
        spacing: Theme.spacingMedium

        Text {
            text: root.title
            color: Theme.textPrimary
            font.pixelSize: 18
            font.bold: true
            Layout.fillWidth: true
        }

        Text {
            text: root.description
            color: Theme.textSecondary
            font.pixelSize: 14
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.fillHeight: true
            verticalAlignment: Text.AlignTop
        }

        PrimaryButton {
            text: root.buttonText
            Layout.alignment: Qt.AlignRight
            onClicked: root.clicked()
        }
    }
}
