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
            title: "Compare & Validate"
            subtitle: "Compare an uploaded store file against the Master dataset."
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingLarge

            // Master File Selection
            Card {
                Layout.fillWidth: true
                Layout.preferredHeight: 140
                hoverable: false

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMedium
                    
                    Text { text: "Master Dataset"; color: Theme.textPrimary; font.bold: true }
                    Text { 
                        text: validate_controller.masterFilePath !== "" ? validate_controller.masterFilePath : "No file selected." 
                        color: Theme.textSecondary; elide: Text.ElideMiddle; Layout.fillWidth: true
                    }
                    Item { Layout.fillHeight: true }
                    PrimaryButton { 
                        text: "Select Master File"
                        onClicked: masterFileDialog.open()
                    }
                }
            }

            // Uploaded File Selection
            Card {
                Layout.fillWidth: true
                Layout.preferredHeight: 140
                hoverable: false

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMedium
                    
                    Text { text: "Uploaded Dataset"; color: Theme.textPrimary; font.bold: true }
                    Text { 
                        text: validate_controller.uploadFilePath !== "" ? validate_controller.uploadFilePath : "No file selected."
                        color: Theme.textSecondary; elide: Text.ElideMiddle; Layout.fillWidth: true
                    }
                    Item { Layout.fillHeight: true }
                    PrimaryButton { 
                        text: "Select Upload File"
                        onClicked: uploadFileDialog.open()
                    }
                }
            }
        }

        // Action & Progress Area
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            hoverable: false

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Theme.spacingMedium

                PrimaryButton {
                    text: validate_controller.isProcessing ? "Processing..." : "Run Validation"
                    enabled: validate_controller.masterFilePath !== "" && validate_controller.uploadFilePath !== "" && !validate_controller.isProcessing
                    Layout.alignment: Qt.AlignHCenter
                    onClicked: validate_controller.startValidation()
                }

                ProgressBar {
                    Layout.preferredWidth: 300
                    Layout.alignment: Qt.AlignHCenter
                    visible: validate_controller.isProcessing
                    value: validate_controller.progress
                    from: 0
                    to: 100
                }
            }
        }
    }

    // Native File Dialogs
    FileDialog {
        id: masterFileDialog
        title: "Select Master CSV"
        nameFilters: ["CSV Files (*.csv)", "All Files (*)"]
        onAccepted: validate_controller.setMasterFile(selectedFile)
    }

    FileDialog {
        id: uploadFileDialog
        title: "Select Uploaded CSV"
        nameFilters: ["CSV Files (*.csv)", "All Files (*)"]
        onAccepted: validate_controller.setUploadFile(selectedFile)
    }
}
