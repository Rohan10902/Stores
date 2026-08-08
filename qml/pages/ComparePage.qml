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

            Card {
                Layout.fillWidth: true
                Layout.preferredHeight: 140
                hoverable: false

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMedium
                    
                    Text { text: "Master Dataset"; color: Theme.textPrimary; font.bold: true }
                    Text { 
                        text: typeof validate_controller !== "undefined" && validate_controller.masterFilePath !== "" ? validate_controller.masterFilePath : "No file selected." 
                        color: Theme.textSecondary; elide: Text.ElideMiddle; Layout.fillWidth: true
                    }
                    Item { Layout.fillHeight: true }
                    PrimaryButton { 
                        text: "Select Master File"
                        onClicked: masterFileDialog.open()
                    }
                }
            }

            Card {
                Layout.fillWidth: true
                Layout.preferredHeight: 140
                hoverable: false

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMedium
                    
                    Text { text: "Uploaded Dataset"; color: Theme.textPrimary; font.bold: true }
                    Text { 
                        text: typeof validate_controller !== "undefined" && validate_controller.uploadFilePath !== "" ? validate_controller.uploadFilePath : "No file selected."
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

        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            hoverable: false

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Theme.spacingMedium

                PrimaryButton {
                    text: typeof validate_controller !== "undefined" && validate_controller.isProcessing ? "Processing..." : "Run Validation"
                    enabled: typeof validate_controller !== "undefined" && validate_controller.masterFilePath !== "" && validate_controller.uploadFilePath !== "" && !validate_controller.isProcessing
                    Layout.alignment: Qt.AlignHCenter
                    onClicked: validate_controller.startValidation()
                }

                ProgressBar {
                    Layout.preferredWidth: 300
                    Layout.alignment: Qt.AlignHCenter
                    visible: typeof validate_controller !== "undefined" && validate_controller.isProcessing
                    value: typeof validate_controller !== "undefined" ? validate_controller.progress : 0
                    from: 0
                    to: 100
                }
            }
        }
    }

    FileDialog {
        id: masterFileDialog
        title: "Select Master CSV"
        nameFilters: ["CSV Files (*.csv)", "All Files (*)"]
        onAccepted: if(typeof validate_controller !== "undefined") validate_controller.setMasterFile(selectedFile)
    }

    FileDialog {
        id: uploadFileDialog
        title: "Select Uploaded CSV"
        nameFilters: ["CSV Files (*.csv)", "All Files (*)"]
        onAccepted: if(typeof validate_controller !== "undefined") validate_controller.setUploadFile(selectedFile)
    }
}
