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
            title: "Data Health & Statistics"
            subtitle: "Overview of your repository's data quality."
            Layout.fillWidth: true
        }

        // Quality Score Overview
        Card {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            hoverable: false
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingLarge
                spacing: Theme.spacingLarge

                ColumnLayout {
                    Text { text: "Overall Quality Score"; color: Theme.textSecondary; font.pixelSize: 14 }
                    Text { 
                        text: health_controller.qualityScore + "%"
                        color: health_controller.qualityScore > 80 ? Theme.success : (health_controller.qualityScore > 50 ? Theme.warning : Theme.error)
                        font.pixelSize: 36
                        font.bold: true
                    }
                }
                
                Item { Layout.fillWidth: true }
                
                PrimaryButton {
                    text: "Refresh Statistics"
                    onClicked: health_controller.refreshHealthStats()
                }
            }
        }

        // Detailed Statistics Grid
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 2
            columnSpacing: Theme.spacingLarge
            rowSpacing: Theme.spacingLarge

            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true
                hoverable: false
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMedium
                    Text { text: "Total Records"; color: Theme.textPrimary; font.bold: true }
                    Text { text: health_controller.totalRecords; color: Theme.textSecondary; font.pixelSize: 24 }
                    Item { Layout.fillHeight: true }
                }
            }

            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true
                hoverable: false
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMedium
                    Text { text: "Identified Errors"; color: Theme.textPrimary; font.bold: true }
                    Text { text: health_controller.totalErrors; color: Theme.error; font.pixelSize: 24 }
                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}
