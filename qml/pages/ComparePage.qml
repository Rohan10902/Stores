import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"

Item {
    id: page

    FileDialog {
        id: masterDlg
        fileMode: FileDialog.OpenFile
        nameFilters: ["All files (*)","CSV (*.csv)","TSV (*.tsv)","Excel (*.xlsx *.xls *.xlsm)"]
        onAccepted: {
            var path = selectedFile ? selectedFile.toString() : ""
            masterPath.text = path
            backend.loadMaster(path)
        }
    }

    FileDialog {
        id: uploadDlg
        fileMode: FileDialog.OpenFile
        nameFilters: ["All files (*)","CSV (*.csv)","TSV (*.tsv)","Excel (*.xlsx *.xls *.xlsm)"]
        onAccepted: {
            var path = selectedFile ? selectedFile.toString() : ""
            uploadPath.text = path
            backend.loadUpload(path)
        }
    }

    Connections {
        target: backend

        // Dynamically update ComboBox models when backend returns auto-detected keys
        function onMappingReady(payload) {
            try {
                var d = JSON.parse(payload)
                if (d.suggestedKeys && d.suggestedKeys.length > 0) {
                    var keys = d.suggestedKeys
                    
                    // Assign dynamic models
                    keyCombo1.model = keys
                    keyCombo1.currentIndex = 0

                    keyCombo2.model = ["None"].concat(keys)
                    if (keys.length > 1) {
                        keyCombo2.currentIndex = 2 // Select second key
                    } else {
                        keyCombo2.currentIndex = 0 // "None"
                    }
                }
            } catch (e) {
                console.log("Error parsing mapping payload: " + e)
            }
        }

        function onValidationReady(payload) {
            try {
                var d = JSON.parse(payload)
                totalCount.text = d.total || 0
                correctCount.text = d.correct || 0
                reviewCount.text = d.review || 0
                errorCount.text = d.errors || 0
                
                resultsModel.clear()
                var rows = d.rows || []
                for (var i = 0; i < rows.length; ++i) {
                    resultsModel.append(rows[i])
                }
            } catch (e) {
                console.log("Error parsing validation payload: " + e)
            }
        }

        function onDetailReady(payload) {
            try {
                var rec = JSON.parse(payload)
                detailModel.clear()
                
                var diffs = rec.diffs || {}
                var masterVals = rec.master || {}
                var uploadVals = rec.upload || {}
                
                // Combine keys from both master and upload
                var allKeys = {}
                for (var k1 in masterVals) allKeys[k1] = true
                for (var k2 in uploadVals) allKeys[k2] = true
                
                for (var k in allKeys) {
                    var mV = masterVals[k] !== undefined ? String(masterVals[k]) : ""
                    var uV = uploadVals[k] !== undefined ? String(uploadVals[k]) : ""
                    var isDiff = !!diffs[k] || (mV.toLowerCase() !== uV.toLowerCase())
                    
                    if (!diffsOnlyCheck.checked || isDiff) {
                        detailModel.append({
                            field: k,
                            masterVal: mV,
                            uploadVal: uV,
                            status: isDiff ? "DIFFERENT" : "MATCH"
                        })
                    }
                }
            } catch (e) {
                console.log("Error parsing detail payload: " + e)
            }
        }
    }

    ListModel { id: resultsModel }
    ListModel { id: detailModel }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        PageTitle { text: "Compare & Validate" }

        // Top Controls Header Card
        Card {
            Layout.fillWidth: true
            implicitHeight: 180

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    TextField {
                        id: masterPath
                        Layout.fillWidth: true
                        placeholderText: "Master file"
                        readOnly: true
                        color: "#f8fafc"
                    }
                    AppButton {
                        text: "Browse"
                        onClicked: masterDlg.open()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    TextField {
                        id: uploadPath
                        Layout.fillWidth: true
                        placeholderText: "Uploaded / country file"
                        readOnly: true
                        color: "#f8fafc"
                    }
                    AppButton {
                        text: "Browse"
                        onClicked: uploadDlg.open()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text { text: "Match by"; color: "#94a3b8" }
                    
                    ComboBox {
                        id: keyCombo1
                        Layout.preferredWidth: 180
                        model: ["SID", "Nielsen Store Code", "Store Name", "ZIP"]
                    }
                    
                    Text { text: "+"; color: "#94a3b8" }
                    
                    ComboBox {
                        id: keyCombo2
                        Layout.preferredWidth: 180
                        model: ["None", "Nielsen Store Code", "SID", "Store Name", "ZIP"]
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    AppButton {
                        text: "Detect Columns"
                        onClicked: backend.detect()
                    }
                    
                    PrimaryButton {
                        text: "Validate"
                        onClicked: {
                            var keys = []
                            if (keyCombo1.currentText && keyCombo1.currentText.length > 0) {
                                keys.push(keyCombo1.currentText)
                            }
                            if (keyCombo2.currentText && keyCombo2.currentText !== "None") {
                                keys.push(keyCombo2.currentText)
                            }
                            if (keys.length === 0) {
                                backend.say("Please select at least one matching key.")
                                return
                            }
                            backend.validate(JSON.stringify(keys))
                        }
                    }
                }
            }
        }

        // Summary Metric Cards
        GridLayout {
            Layout.fillWidth: true
            columns: 4
            columnSpacing: 12

            Card {
                Layout.fillWidth: true; implicitHeight: 75
                ColumnLayout {
                    anchors.centerIn: parent
                    Text { id: totalCount; text: "0"; color: "#f8fafc"; font.bold: true; font.pixelSize: 20 }
                    Text { text: "TOTAL"; color: "#94a3b8"; font.pixelSize: 10 }
                }
            }
            Card {
                Layout.fillWidth: true; implicitHeight: 75
                ColumnLayout {
                    anchors.centerIn: parent
                    Text { id: correctCount; text: "0"; color: "#4ade80"; font.bold: true; font.pixelSize: 20 }
                    Text { text: "CORRECT"; color: "#94a3b8"; font.pixelSize: 10 }
                }
            }
            Card {
                Layout.fillWidth: true; implicitHeight: 75
                ColumnLayout {
                    anchors.centerIn: parent
                    Text { id: reviewCount; text: "0"; color: "#f59e0b"; font.bold: true; font.pixelSize: 20 }
                    Text { text: "REVIEW"; color: "#94a3b8"; font.pixelSize: 10 }
                }
            }
            Card {
                Layout.fillWidth: true; implicitHeight: 75
                ColumnLayout {
                    anchors.centerIn: parent
                    Text { id: errorCount; text: "0"; color: "#ef4444"; font.bold: true; font.pixelSize: 20 }
                    Text { text: "ERROR"; color: "#94a3b8"; font.pixelSize: 10 }
                }
            }
        }

        // Main Validation Results List
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10

                Text {
                    text: "Validation Results — row order does not affect matching"
                    color: "#f8fafc"
                    font.bold: true
                }

                ListView {
                    id: resultsListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: resultsModel
                    clip: true

                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 32
                        color: index % 2 ? "#0d1b2e" : "#0b1829"
                        border.color: "#1e293b"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            
                            Text {
                                text: model.status || ""
                                color: model.status === "CORRECT" ? "#4ade80" : (model.status === "REVIEW" ? "#f59e0b" : "#ef4444")
                                font.bold: true
                                width: 90
                            }
                            Text {
                                text: "Key: " + (model.key || "N/A")
                                color: "#f8fafc"
                                font.bold: true
                                width: 220
                                elide: Text.ElideRight
                            }
                            Text {
                                text: model.message || model.problem || ""
                                color: "#94a3b8"
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                resultsListView.currentIndex = index
                                backend.detail(index, diffsOnlyCheck.checked)
                            }
                        }
                    }
                }
            }
        }

        // Side-by-Side Record Difference Inspector
        Card {
            Layout.fillWidth: true
            Layout.preferredHeight: 180

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Error-aware Comparison Inspector"; color: "#f8fafc"; font.bold: true }
                    Item { Layout.fillWidth: true }
                    CheckBox {
                        id: diffsOnlyCheck
                        text: "Differences only"
                        checked: false
                        onToggled: {
                            if (resultsListView.currentIndex >= 0) {
                                backend.detail(resultsListView.currentIndex, checked)
                            }
                        }
                    }
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: detailModel
                    clip: true

                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 28
                        color: "#0b1829"
                        border.color: "#1e293b"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 4
                            Text { text: model.field || ""; color: "#f8fafc"; width: 150; font.bold: true }
                            Text { text: model.masterVal || "(empty)"; color: "#94a3b8"; width: 220; elide: Text.ElideRight }
                            Text { text: model.uploadVal || "(empty)"; color: "#60a5fa"; width: 220; elide: Text.ElideRight }
                            Text {
                                text: model.status || ""
                                color: model.status === "MATCH" ? "#4ade80" : "#ef4444"
                                font.bold: true
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }
    }
}
