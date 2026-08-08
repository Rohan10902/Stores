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
            title: "Query Studio"
            subtitle: "Explore and analyze datasets using read-only queries."
            Layout.fillWidth: true
        }

        // Query Input Area
        Card {
            Layout.fillWidth: true
            Layout.preferredHeight: 160
            hoverable: false

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingMedium
                spacing: Theme.spacingMedium

                Text { text: "SQL Query"; color: Theme.textPrimary; font.bold: true }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    TextArea {
                        id: queryInput
                        text: "SELECT * FROM store_data LIMIT 100;" // Default placeholder query
                        color: Theme.textPrimary
                        background: Rectangle {
                            color: Theme.background
                            border.color: Theme.border
                            radius: Theme.radiusMedium
                        }
                        font.pixelSize: 14
                        font.family: "Monospace"
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Item { Layout.fillWidth: true }
                    PrimaryButton {
                        text: "Execute Query"
                        onClicked: explorer_controller.executeQuery(queryInput.text)
                    }
                }
            }
        }

        // Data Table Output
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            hoverable: false

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingMedium
                spacing: Theme.spacingMedium

                Text { text: "Results Output"; color: Theme.textPrimary; font.bold: true }

                // This assumes your backend provides a QAbstractTableModel
                TableView {
                    id: resultsTable
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: explorer_controller.queryResultsModel
                    
                    columnSpacing: 1
                    rowSpacing: 1

                    delegate: Rectangle {
                        implicitWidth: 150
                        implicitHeight: 36
                        color: Theme.background
                        border.color: Theme.border
                        
                        Text {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingSmall
                            text: display
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }
    }
}
