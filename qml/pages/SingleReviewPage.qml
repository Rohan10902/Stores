import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"
import "../theme"

Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingXLarge
        spacing: Theme.spacingLarge

        PageTitle {
            title: "Single File Review"
            subtitle: "Analyze an isolated dataset for formatting and code integrity."
            Layout.fillWidth: true
        }

        Card {
            Layout.fillWidth: true
            Layout.preferredHeight: 140
            hoverable: false

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingMedium
                
                Text { text: "Target Dataset"; color: Theme.textPrimary; font.bold: true }
                Text { 
                    text: review_controller.targetFilePath !== "" ? review_controller.targetFilePath : "No file selected." 
                    color: Theme.textSecondary; elide: Text.ElideMiddle; Layout.fillWidth: true
                }
                
                Item { Layout.fillHeight: true }
                
                RowLayout {
                    Layout.fillWidth: true
                    PrimaryButton { 
                        text: "Select File"
                        onClicked: targetFileDialog.open()
                    }
                    Item { Layout.fillWidth: true }
                    PrimaryButton {
                        text: review_controller.isProcessing ? "Analyzing..." : "Run Review"
                        enabled: review_controller.targetFilePath !== "" && !review_controller.isProcessing
                        onClicked: review_controller.startReview()
                    }
                }
            }
        }

        // Results Area
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            hoverable: false

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingMedium
                spacing: Theme.spacingMedium

                Text { text: "Review Results"; color: Theme.textPrimary; font.bold: true; font.pixelSize: 16 }
                
                ListView {
                    id: resultsList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: review_controller.resultsModel
                    spacing: Theme.spacingSmall

                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 40
                        color: "transparent"
                        border.color: Theme.border
                        radius: Theme.radiusMedium

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingSmall
                            spacing: Theme.spacingMedium

                            Text { 
                                text: model.issueType
                                color: model.severity === "Error" ? Theme.error : Theme.warning
                                font.bold: true
                                Layout.preferredWidth: 100
                            }
                            
                            Text { 
                                text: model.description 
                                color: Theme.textPrimary
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: review_controller.targetFilePath === "" ? "Select a file and run a review to see results." : "No formatting issues found."
                        color: Theme.textSecondary
                        font.pixelSize: 16
                        visible: resultsList.count === 0 && !review_controller.isProcessing
                    }
                }
            }
        }
    }

    FileDialog {
        id: targetFileDialog
        title: "Select Dataset"
        nameFilters: ["CSV Files (*.csv)", "Text Files (*.txt)", "All Files (*)"]
        onAccepted: review_controller.setTargetFile(selectedFile)
    }
}
