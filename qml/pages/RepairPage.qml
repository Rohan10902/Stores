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
            title: "Record Repair"
            subtitle: "Inspect and repair malformed CSV/Text records."
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

                // Table or List view driven by the Python backend model
                ListView {
                    id: brokenRecordsList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: repair_controller.brokenRecordsModel // Binds to your existing Python model
                    spacing: Theme.spacingSmall

                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 60
                        color: Theme.background
                        border.color: Theme.border
                        radius: Theme.radiusMedium

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingSmall
                            spacing: Theme.spacingMedium

                            Text { 
                                text: "Row " + model.rowNumber 
                                color: Theme.textSecondary
                                font.bold: true
                                Layout.preferredWidth: 60
                            }
                            
                            Text { 
                                text: model.errorDescription 
                                color: Theme.error
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            PrimaryButton {
                                text: "Auto-Fix"
                                onClicked: repair_controller.attemptAutoFix(model.rowNumber)
                            }
                        }
                    }

                    // Empty State
                    Text {
                        anchors.centerIn: parent
                        text: "No broken records detected. You're good to go!"
                        color: Theme.textSecondary
                        font.pixelSize: 16
                        visible: brokenRecordsList.count === 0
                    }
                }
                
                RowLayout {
                    Layout.fillWidth: true
                    Item { Layout.fillWidth: true }
                    PrimaryButton {
                        text: "Export Cleaned File"
                        enabled: repair_controller.isRepairComplete
                        onClicked: repair_controller.exportRepairedFile()
                    }
                }
            }
        }
    }
}
