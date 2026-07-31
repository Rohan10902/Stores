import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"

Item {
    id: page

    FileDialog {
        id: exploreDlg
        fileMode: FileDialog.OpenFile
        nameFilters: ["All files (*)","CSV (*.csv)","TSV (*.tsv)","Excel (*.xlsx *.xls *.xlsm)"]
        onAccepted: {
            var path = selectedFile ? selectedFile.toString() : ""
            backend.loadData(path)
        }
    }

    Connections {
        target: backend
        function onTableReady(payload) {
            var d = JSON.parse(payload)
            tableModel.clear()
            headersModel.clear()
            
            var cols = d.columns || []
            for (var c = 0; c < cols.length; ++c) {
                headersModel.append({ name: cols[c] })
            }
            
            var rows = d.rows || []
            for (var r = 0; r < rows.length; ++r) {
                tableModel.append({ rowData: rows[r] })
            }
            rowCountText.text = d.total + " rows"
        }
    }

    ListModel { id: headersModel }
    ListModel { id: tableModel }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true
                PageTitle { text: "Explore & Analyze" }
            }
            PrimaryButton {
                text: "Load Dataset"
                onClicked: exploreDlg.open()
            }
        }

        Card {
            Layout.fillWidth: true
            implicitHeight: 140
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    TextField {
                        id: searchQuery
                        Layout.fillWidth: true
                        placeholderText: "Search records..."
                        color: "#f8fafc"
                    }
                    ComboBox {
                        id: colCombo
                        model: ["All columns", "SID", "Store Name", "Banner", "ZIP"]
                    }
                    AppButton {
                        text: "Search"
                        onClicked: backend.search(searchQuery.text, colCombo.currentText)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    TextField {
                        id: sqlInput
                        Layout.fillWidth: true
                        text: "SELECT * FROM data LIMIT 100"
                        color: "#f8fafc"
                    }
                    PrimaryButton {
                        text: "Run SQL"
                        onClicked: backend.sql(sqlInput.text)
                    }
                }
            }
        }

        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Result Table"; color: "#f8fafc"; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { id: rowCountText; text: "0 rows"; color: "#94a3b8" }
                }
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: tableModel
                    clip: true
                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 28
                        color: index % 2 ? "#0d1b2e" : "#0b1829"
                        border.color: "#1e293b"
                        Text {
                            anchors.fill: parent
                            anchors.margins: 6
                            text: JSON.stringify(model.rowData || {})
                            color: "#f8fafc"
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
