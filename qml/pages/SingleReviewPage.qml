import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"

Item {
    id: page

    FileDialog {
        id: fileDlg
        fileMode: FileDialog.OpenFile
        nameFilters: ["All files (*)","CSV (*.csv)","TSV (*.tsv)","Excel (*.xlsx *.xls *.xlsm)","JSON (*.json)"]
        onAccepted: {
            var path = selectedFile ? selectedFile.toString() : ""
            filePath.text = path
        }
    }

    FileDialog {
        id: saveDlg
        fileMode: FileDialog.SaveFile
        nameFilters: ["CSV (*.csv)"]
        onAccepted: backend.exportSingleReview(filePath.text, selectedFile.toString())
    }

    Connections {
        target: backend
        function onSingleReviewReady(payload) {
            var d = JSON.parse(payload)
            totalRecs.text = d.totalRecords || 0
            attentionRecs.text = d.attentionCount || 0
            
            previewModel.clear()
            var cols = d.previewColumns || []
            var rows = d.previewRows || []
            for (var i = 0; i < rows.length; ++i) {
                previewModel.append(rows[i])
            }
            
            findingsModel.clear()
            var findings = d.findings || []
            for (var j = 0; j < findings.length; ++j) {
                findingsModel.append(findings[j])
            }
        }
    }

    ListModel { id: previewModel }
    ListModel { id: findingsModel }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        PageTitle { text: "Review One File" }
        Text { text: "Review a dataset without a Master file. The loaded file is previewed below; source data remains unchanged until export."; color: "#94a3b8" }

        Card {
            Layout.fillWidth: true
            implicitHeight: 72
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10
                TextField {
                    id: filePath
                    Layout.fillWidth: true
                    placeholderText: "Choose CSV / Excel / text file"
                    readOnly: true
                    color: "#f8fafc"
                }
                AppButton {
                    text: "Choose File"
                    onClicked: fileDlg.open()
                }
                PrimaryButton {
                    text: "Analyze"
                    onClicked: backend.reviewSingleFile(filePath.text)
                }
                AppButton {
                    text: "Export Reviewed Copy"
                    onClicked: saveDlg.open()
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 12

            Card {
                Layout.fillWidth: true; implicitHeight: 75
                ColumnLayout {
                    anchors.centerIn: parent
                    Text { id: totalRecs; text: "0"; color: "#f8fafc"; font.bold: true; font.pixelSize: 20 }
                    Text { text: "RECORDS"; color: "#94a3b8"; font.pixelSize: 10 }
                }
            }
            Card {
                Layout.fillWidth: true; implicitHeight: 75
                ColumnLayout {
                    anchors.centerIn: parent
                    Text { id: attentionRecs; text: "0"; color: "#f59e0b"; font.bold: true; font.pixelSize: 20 }
                    Text { text: "RECORDS NEEDING ATTENTION"; color: "#94a3b8"; font.pixelSize: 10 }
                }
            }
        }

        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                Text { text: "File Preview"; color: "#f8fafc"; font.bold: true }
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: previewModel
                    clip: true
                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 28
                        color: index % 2 ? "#0d1b2e" : "#0b1829"
                        border.color: "#1e293b"
                        Text {
                            anchors.fill: parent
                            anchors.margins: 6
                            text: JSON.stringify(modelData)
                            color: "#f8fafc"
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        Card {
            Layout.fillWidth: true
            Layout.preferredHeight: 140
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                Text { text: "Records Needing Attention"; color: "#f8fafc"; font.bold: true }
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: findingsModel
                    clip: true
                    delegate: Text {
                        width: ListView.view.width
                        height: 24
                        text: model.message || ""
                        color: "#f59e0b"
                    }
                }
            }
        }
    }
}
