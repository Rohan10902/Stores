import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"

Item {
    id: page

    FileDialog {
        id: repairDlg
        fileMode: FileDialog.OpenFile
        nameFilters: ["CSV / Text (*.csv *.txt *.tsv)", "All files (*)"]
        onAccepted: {
            var path = selectedFile ? selectedFile.toString() : ""
            repairPath.text = path
            backend.inspectRepair(path)
        }
    }

    FileDialog {
        id: saveRepairDlg
        fileMode: FileDialog.SaveFile
        nameFilters: ["CSV (*.csv)"]
        onAccepted: backend.repair(repairPath.text, selectedFile.toString())
    }

    Connections {
        target: backend
        function onRepairReady(payload) {
            var audit = JSON.parse(payload)
            totalRecords.text = audit.total_records || 0
            expectedFields.text = audit.expected_fields || 0
            healthyCount.text = audit.healthy_count || 0
            autoFixedCount.text = audit.auto_fixed_count || 0
            needsReviewCount.text = audit.issues ? audit.issues.length : 0

            issuesModel.clear()
            var issues = audit.issues || []
            for (var i = 0; i < issues.length; ++i) {
                issuesModel.append(issues[i])
            }
        }
    }

    ListModel { id: issuesModel }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        PageTitle { text: "Record Repair" }
        Text { text: "Detect broken records, reconstruct shifted lines, and resolve overflow without changing the source file."; color: "#94a3b8" }

        Card {
            Layout.fillWidth: true
            implicitHeight: 72
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10
                TextField {
                    id: repairPath
                    Layout.fillWidth: true
                    placeholderText: "CSV / TXT / TSV"
                    readOnly: true
                    color: "#f8fafc"
                }
                AppButton {
                    text: "Choose File"
                    onClicked: repairDlg.open()
                }
                AppButton {
                    text: "Undo Last Action"
                    onClicked: backend.undoRepairAction()
                }
                PrimaryButton {
                    text: "Save Reviewed Copy"
                    onClicked: saveRepairDlg.open()
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 5
            columnSpacing: 8

            Card {
                Layout.fillWidth: true; implicitHeight: 75
                ColumnLayout {
                    anchors.centerIn: parent
                    Text { id: totalRecords; text: "0"; color: "#f8fafc"; font.bold: true; font.pixelSize: 18 }
                    Text { text: "RECORDS"; color: "#94a3b8"; font.pixelSize: 9 }
                }
            }
            Card {
                Layout.fillWidth: true; implicitHeight: 75
                ColumnLayout {
                    anchors.centerIn: parent
                    Text { id: expectedFields; text: "0"; color: "#f8fafc"; font.bold: true; font.pixelSize: 18 }
                    Text { text: "EXPECTED FIELDS"; color: "#94a3b8"; font.pixelSize: 9 }
                }
            }
            Card {
                Layout.fillWidth: true; implicitHeight: 75
                ColumnLayout {
                    anchors.centerIn: parent
                    Text { id: healthyCount; text: "0"; color: "#4ade80"; font.bold: true; font.pixelSize: 18 }
                    Text { text: "HEALTHY"; color: "#94a3b8"; font.pixelSize: 9 }
                }
            }
            Card {
                Layout.fillWidth: true; implicitHeight: 75
                ColumnLayout {
                    anchors.centerIn: parent
                    Text { id: autoFixedCount; text: "0"; color: "#60a5fa"; font.bold: true; font.pixelSize: 18 }
                    Text { text: "AUTO FIXED"; color: "#94a3b8"; font.pixelSize: 9 }
                }
            }
            Card {
                Layout.fillWidth: true; implicitHeight: 75
                ColumnLayout {
                    anchors.centerIn: parent
                    Text { id: needsReviewCount; text: "0"; color: "#f59e0b"; font.bold: true; font.pixelSize: 18 }
                    Text { text: "NEEDS REVIEW"; color: "#94a3b8"; font.pixelSize: 9 }
                }
            }
        }

        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                Text { text: "Repair Queue"; color: "#f8fafc"; font.bold: true }
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: issuesModel
                    clip: true
                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 36
                        color: "#0b1829"
                        border.color: "#1e293b"
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            Text { text: "Row " + (model.row || 0); color: "#f59e0b"; font.bold: true; width: 80 }
                            Text { text: model.issue_type || ""; color: "#f8fafc"; width: 140 }
                            Text { text: model.description || ""; color: "#94a3b8"; Layout.fillWidth: true }
                        }
                    }
                }
            }
        }
    }
}
