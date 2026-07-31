import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"

Item {
    id: page

    FileDialog {
        id: healthDlg
        fileMode: FileDialog.OpenFile
        nameFilters: ["All files (*)","CSV (*.csv)","TSV (*.tsv)","Excel (*.xlsx *.xls *.xlsm)"]
        onAccepted: {
            var path = selectedFile ? selectedFile.toString() : ""
            backend.loadData(path)
        }
    }

    Connections {
        target: backend
        function onHealthReady(payload) {
            var d = JSON.parse(payload)
            totalRows.text = d.rows || 0
            totalCols.text = d.columns || 0
            completeness.text = (d.completeness || 0) + "%"
            duplicates.text = d.duplicates || 0
            healthScore.text = (d.health_score || 0) + "/100"

            colModel.clear()
            var cols = d.column_details || []
            for (var i = 0; i < cols.length; ++i) {
                colModel.append(cols[i])
            }
        }
        function onStatsReady(payload) {
            var s = JSON.parse(payload)
            statsModel.clear()
            var rows = s.results || []
            for (var j = 0; j < rows.length; ++j) {
                statsModel.append(rows[j])
            }
        }
    }

    ListModel { id: colModel }
    ListModel { id: statsModel }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true
                PageTitle { text: "Data Intelligence" }
            }
            AppButton {
                text: "Choose Dataset"
                onClicked: healthDlg.open()
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 5
            columnSpacing: 10

            Card {
                Layout.fillWidth: true; implicitHeight: 75
                ColumnLayout {
                    anchors.centerIn: parent
                    Text { id: totalRows; text: "0"; color: "#f8fafc"; font.bold: true; font.pixelSize: 18 }
                    Text { text: "ROWS"; color: "#94a3b8"; font.pixelSize: 9 }
                }
            }
            Card {
                Layout.fillWidth: true; implicitHeight: 75
                ColumnLayout {
                    anchors.centerIn: parent
                    Text { id: totalCols; text: "0"; color: "#f8fafc"; font.bold: true; font.pixelSize: 18 }
                    Text { text: "COLUMNS"; color: "#94a3b8"; font.pixelSize: 9 }
                }
            }
            Card {
                Layout.fillWidth: true; implicitHeight: 75
                ColumnLayout {
                    anchors.centerIn: parent
                    Text { id: completeness; text: "0%"; color: "#4ade80"; font.bold: true; font.pixelSize: 18 }
                    Text { text: "COMPLETENESS"; color: "#94a3b8"; font.pixelSize: 9 }
                }
            }
            Card {
                Layout.fillWidth: true; implicitHeight: 75
                ColumnLayout {
                    anchors.centerIn: parent
                    Text { id: duplicates; text: "0"; color: "#f59e0b"; font.bold: true; font.pixelSize: 18 }
                    Text { text: "DUPLICATES"; color: "#94a3b8"; font.pixelSize: 9 }
                }
            }
            Card {
                Layout.fillWidth: true; implicitHeight: 75
                ColumnLayout {
                    anchors.centerIn: parent
                    Text { id: healthScore; text: "0/100"; color: "#60a5fa"; font.bold: true; font.pixelSize: 18 }
                    Text { text: "HEALTH"; color: "#94a3b8"; font.pixelSize: 9 }
                }
            }
        }

        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                Text { text: "Column Quality"; color: "#f8fafc"; font.bold: true }
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: colModel
                    clip: true
                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 28
                        color: "#0b1829"
                        border.color: "#1e293b"
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 4
                            Text { text: model.column || ""; color: "#f8fafc"; width: 180 }
                            Text { text: model.type || ""; color: "#94a3b8"; width: 100 }
                            Text { text: model.non_blank || ""; color: "#4ade80"; width: 100 }
                            Text { text: model.blank || ""; color: "#ef4444"; width: 80 }
                            Text { text: model.unique || ""; color: "#60a5fa"; Layout.fillWidth: true }
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
                Text { text: "Statistics Analysis"; color: "#f8fafc"; font.bold: true }
                RowLayout {
                    Layout.fillWidth: true
                    ComboBox { id: targetCol; model: ["SID", "Store Name", "Banner", "ZIP"] }
                    ComboBox { id: opCombo; model: ["Summary", "Frequency", "Average", "Outliers"] }
                    ComboBox { id: groupCol; model: ["None", "Banner", "Active / Inactive"] }
                    Item { Layout.fillWidth: true }
                    PrimaryButton {
                        text: "Calculate"
                        onClicked: backend.stats(targetCol.currentText, opCombo.currentText, groupCol.currentText)
                    }
                }
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: statsModel
                    clip: true
                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 26
                        color: "#0b1829"
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 4
                            Text { text: model.metric || ""; color: "#f8fafc"; width: 200 }
                            Text { text: model.result || ""; color: "#60a5fa"; Layout.fillWidth: true }
                        }
                    }
                }
            }
        }
    }
}
