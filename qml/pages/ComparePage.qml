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
        function onMappingReady(payload) {
            var d = JSON.parse(payload)
            if (d.suggestedKeys && d.suggestedKeys.length > 0) {
                keyCombo1.currentIndex = keyCombo1.find(d.suggestedKeys[0])
                if (d.suggestedKeys.length > 1) {
                    keyCombo2.currentIndex = keyCombo2.find(d.suggestedKeys[1])
                }
            }
        }
        function onValidationReady(payload) {
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
        }
        function onDetailReady(payload) {
            var rec = JSON.parse(payload)
            detailModel.clear()
            var diffs = rec.diffs || {}
            var masterVals = rec.master || {}
            var uploadVals = rec.upload || {}
            for (var k in masterVals) {
                detailModel.append({
                    field: k,
                    masterVal: String(masterVals[k] !== undefined ? masterVals[k] : ""),
                    uploadVal: String(uploadVals[k] !== undefined ? uploadVals[k] : ""),
                    status: diffs[k] ? "DIFFERENT" : "MATCH"
                })
            }
        }
    }

    ListModel { id: resultsModel }
    ListModel { id: detailModel }
    ListModel { id: keysModel }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        PageTitle { text: "Compare & Validate" }

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
                        model: ["Nielsen Store Code", "SID", "Store Name", "ZIP", "None"]
                    }
                    Item { Layout.fillWidth: true }
                    AppButton {
                        text: "Detect Columns"
                        onClicked: backend.detect()
                    }
                    PrimaryButton {
                        text: "Validate"
                        onClicked: {
                            var keys = [keyCombo1.currentText]
                            if (keyCombo2.currentText !== "None")
                                keys.push(keyCombo2.currentText)
                            backend.validate(JSON.stringify(keys))
                        }
                    }
                }
            }
        }

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

        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                Text { text: "Validation Results — row order does not affect matching"; color: "#f8fafc"; font.bold: true }

                ListView {
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
                            Text { text: model.status || ""; color: model.status === "CORRECT" ? "#4ade80" : "#f59e0b"; font.bold: true; width: 90 }
                            Text { text: "Key: " + (model.key || ""); color: "#f8fafc"; width: 140 }
                            Text { text: model.message || ""; color: "#94a3b8"; Layout.fillWidth: true }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: backend.detail(index, false)
                        }
                    }
                }
            }
        }

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
                    CheckBox { id: diffsOnlyCheck; text: "Differences only"; checked: false }
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
                            Text { text: model.field || ""; color: "#f8fafc"; width: 150 }
                            Text { text: model.masterVal || ""; color: "#94a3b8"; width: 220 }
                            Text { text: model.uploadVal || ""; color: "#60a5fa"; width: 220 }
                            Text { text: model.status || ""; color: model.status === "MATCH" ? "#4ade80" : "#ef4444"; Layout.fillWidth: true }
                        }
                    }
                }
            }
        }
    }
}
