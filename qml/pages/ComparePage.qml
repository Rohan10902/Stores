import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"
import "../theme"

Item {
    id: root

    ScrollView {
        id: scrollView
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth

        ColumnLayout {
            width: scrollView.availableWidth
            anchors.margins: Theme.spacingXLarge
            spacing: Theme.spacingLarge

            PageTitle {
                title: "Compare & Validate"
                subtitle: "Match and validate uploaded store data against the Master dataset."
                Layout.fillWidth: true
            }

            // --- 1. FILE SELECTION ---
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingLarge

                Card {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 110
                    hoverable: false
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingMedium
                        Text { text: "Master Dataset"; color: Theme.textPrimary; font.bold: true }
                        Text { 
                            text: typeof validate_controller !== "undefined" && validate_controller.masterFilePath !== "" ? validate_controller.masterFilePath : "No master file selected." 
                            color: Theme.textSecondary; elide: Text.ElideMiddle; Layout.fillWidth: true
                        }
                        Item { Layout.fillHeight: true }
                        AppButton { text: "Select Master"; onClicked: masterFileDialog.open() }
                    }
                }

                Card {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 110
                    hoverable: false
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingMedium
                        Text { text: "Uploaded Dataset"; color: Theme.textPrimary; font.bold: true }
                        Text { 
                            text: typeof validate_controller !== "undefined" && validate_controller.uploadFilePath !== "" ? validate_controller.uploadFilePath : "No upload file selected."
                            color: Theme.textSecondary; elide: Text.ElideMiddle; Layout.fillWidth: true
                        }
                        Item { Layout.fillHeight: true }
                        AppButton { text: "Select Upload"; onClicked: uploadFileDialog.open() }
                    }
                }
            }

            // --- 2. MATCH CONTROLS & ACTIONS ---
            Card {
                Layout.fillWidth: true
                Layout.preferredHeight: 80
                hoverable: false
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMedium
                    spacing: Theme.spacingLarge

                    Text { text: "Match By:"; color: Theme.textPrimary; font.bold: true }
                    
                    RadioButton {
                        text: "SID"
                        checked: typeof validate_controller !== "undefined" ? validate_controller.matchMethod === "SID" : true
                        onCheckedChanged: if(checked && typeof validate_controller !== "undefined") validate_controller.matchMethod = "SID"
                        contentItem: Text { text: parent.text; color: Theme.textPrimary; leftMargin: parent.indicator.width + Theme.spacingSmall; verticalAlignment: Text.AlignVCenter }
                    }
                    
                    RadioButton {
                        text: "Nielsen Store Code"
                        checked: typeof validate_controller !== "undefined" ? validate_controller.matchMethod === "Nielsen" : false
                        onCheckedChanged: if(checked && typeof validate_controller !== "undefined") validate_controller.matchMethod = "Nielsen"
                        contentItem: Text { text: parent.text; color: Theme.textPrimary; leftMargin: parent.indicator.width + Theme.spacingSmall; verticalAlignment: Text.AlignVCenter }
                    }

                    Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: Theme.border; Layout.margins: Theme.spacingSmall }

                    AppButton { 
                        text: "Detect Columns"
                        enabled: typeof validate_controller !== "undefined" && validate_controller.masterFilePath !== "" && validate_controller.uploadFilePath !== ""
                        onClicked: if(typeof validate_controller !== "undefined") validate_controller.detectColumns()
                    }

                    Item { Layout.fillWidth: true } // Spacer

                    CheckBox {
                        text: "Differences Only"
                        checked: typeof validate_controller !== "undefined" ? validate_controller.differencesOnly : false
                        onCheckedChanged: if(typeof validate_controller !== "undefined") validate_controller.differencesOnly = checked
                        contentItem: Text { text: parent.text; color: Theme.textPrimary; leftMargin: parent.indicator.width + Theme.spacingSmall; verticalAlignment: Text.AlignVCenter }
                    }

                    PrimaryButton {
                        text: typeof validate_controller !== "undefined" && validate_controller.isProcessing ? "Validating..." : "Run Validation"
                        enabled: typeof validate_controller !== "undefined" && validate_controller.masterFilePath !== "" && validate_controller.uploadFilePath !== "" && !validate_controller.isProcessing
                        onClicked: validate_controller.startValidation()
                    }
                }
            }

            // --- 3. METRICS COUNTERS ---
            Card {
                Layout.fillWidth: true
                Layout.preferredHeight: 90
                hoverable: false
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMedium
                    spacing: Theme.spacingLarge

                    MetricBlock { label: "Total Rows"; value: typeof validate_controller !== "undefined" ? validate_controller.totalCount : "0"; valueColor: Theme.textPrimary }
                    Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: Theme.border }
                    MetricBlock { label: "Correct"; value: typeof validate_controller !== "undefined" ? validate_controller.correctCount : "0"; valueColor: Theme.success }
                    Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: Theme.border }
                    MetricBlock { label: "Review Needed"; value: typeof validate_controller !== "undefined" ? validate_controller.reviewCount : "0"; valueColor: Theme.warning }
                    Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: Theme.border }
                    MetricBlock { label: "Errors"; value: typeof validate_controller !== "undefined" ? validate_controller.errorCount : "0"; valueColor: Theme.error }
                }
            }

            // --- 4. COMPARISON INSPECTOR ---
            Card {
                Layout.fillWidth: true
                Layout.minimumHeight: 300
                Layout.fillHeight: true
                hoverable: false

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMedium
                    spacing: 0

                    Text { 
                        text: "Comparison Inspector"
                        color: Theme.textPrimary
                        font.bold: true
                        font.pixelSize: 16
                        Layout.bottomMargin: Theme.spacingMedium
                    }

                    ProgressBar {
                        Layout.fillWidth: true
                        visible: typeof validate_controller !== "undefined" && validate_controller.isProcessing
                        value: typeof validate_controller !== "undefined" ? validate_controller.progress : 0
                        from: 0
                        to: 100
                        Layout.bottomMargin: Theme.spacingMedium
                    }

                    // Table Header
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        color: Theme.surfaceHover
                        border.color: Theme.border
                        border.width: 1
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingMedium
                            anchors.rightMargin: Theme.spacingMedium
                            spacing: Theme.spacingMedium

                            Text { text: "Field"; color: Theme.textSecondary; font.bold: true; Layout.preferredWidth: 150 }
                            Text { text: "Master Value"; color: Theme.textSecondary; font.bold: true; Layout.fillWidth: true }
                            Text { text: "Uploaded Value"; color: Theme.textSecondary; font.bold: true; Layout.fillWidth: true }
                            Text { text: "Result"; color: Theme.textSecondary; font.bold: true; Layout.preferredWidth: 100 }
                        }
                    }

                    // Table Body (List View)
                    ListView {
                        id: resultsList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: typeof validate_controller !== "undefined" ? validate_controller.comparisonModel : null
                        
                        delegate: Rectangle {
                            width: resultsList.width
                            height: 40
                            color: index % 2 === 0 ? "transparent" : Theme.surfaceHover
                            border.color: Theme.border
                            border.width: 1
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingMedium
                                anchors.rightMargin: Theme.spacingMedium
                                spacing: Theme.spacingMedium

                                Text { text: model.field; color: Theme.textPrimary; Layout.preferredWidth: 150; elide: Text.ElideRight }
                                Text { text: model.masterValue; color: Theme.textPrimary; Layout.fillWidth: true; elide: Text.ElideRight }
                                Text { 
                                    text: model.uploadValue
                                    color: model.status === "Error" ? Theme.error : (model.status === "Review" ? Theme.warning : Theme.textPrimary)
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                Text { 
                                    text: model.result
                                    color: model.status === "Error" ? Theme.error : (model.status === "Review" ? Theme.warning : Theme.success)
                                    font.bold: true
                                    Layout.preferredWidth: 100 
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "No validation data to display."
                            color: Theme.textMuted
                            visible: resultsList.count === 0 && (typeof validate_controller === "undefined" || !validate_controller.isProcessing)
                        }
                    }
                }
            }
        }
    }

    // Inline Component for Metric Display
    component MetricBlock: ColumnLayout {
        property string label: ""
        property string value: "0"
        property color valueColor: Theme.textPrimary
        
        Layout.fillWidth: true
        spacing: 4

        Text { text: parent.label; color: Theme.textSecondary; font.pixelSize: 12; Layout.alignment: Qt.AlignHCenter }
        Text { text: parent.value; color: parent.valueColor; font.pixelSize: 24; font.bold: true; Layout.alignment: Qt.AlignHCenter }
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
