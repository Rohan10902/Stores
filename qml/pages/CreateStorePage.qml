import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../theme"

Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingXLarge
        spacing: Theme.spacingLarge

        PageTitle {
            title: "Create Store File"
            subtitle: "Paste tabular data to map into the fixed Store schema and export."
            Layout.fillWidth: true
        }

        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            hoverable: false

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingMedium
                spacing: Theme.spacingMedium

                Text { text: "Raw Tabular Data (Paste here)"; color: Theme.textPrimary; font.bold: true }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    TextArea {
                        id: rawDataInput
                        placeholderText: "Paste your raw tabular data (e.g., from Excel) here..."
                        color: Theme.textPrimary
                        placeholderTextColor: Theme.textSecondary
                        background: Rectangle {
                            color: Theme.background
                            border.color: Theme.border
                            radius: Theme.radiusMedium
                        }
                        font.pixelSize: 14
                        wrapMode: Text.NoWrap
                        onTextChanged: creator_controller.rawText = text
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    
                    Text {
                        text: creator_controller.recordCount > 0 ? "Detected " + creator_controller.recordCount + " records." : ""
                        color: Theme.info
                        Layout.fillWidth: true
                    }

                    PrimaryButton {
                        text: "Process & Export CSV"
                        enabled: rawDataInput.text.length > 0
                        onClicked: creator_controller.generateAndExport()
                    }
                }
            }
        }
    }
}
