import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"

Item {
    property string src: ""
    property int total: 0
    property int issueCount: 0
    property int findingCount: 0
    property var previewCols: []

    ListModel { id: findings }
    ListModel { id: previewRows }

    FileDialog {
        id: openDlg
        nameFilters: ["Data (*.csv *.xlsx *.xls *.xlsm *.txt *.tsv *.json *.xml)"]
        onAccepted: {
            src = selectedFile.toString()
            findings.clear()
            previewRows.clear()
            previewCols = []
            backend.reviewSingleFile(src)
        }
    }

    FileDialog {
        id: saveDlg
        fileMode: FileDialog.SaveFile
        nameFilters: ["CSV (*.csv)"]
        onAccepted: backend.exportSingleReview(src, selectedFile.toString())
    }

    Connections {
        target: backend
        function onSingleReviewReady(p) {
            var d = JSON.parse(p)
            total = d.total || 0
            issueCount = d.issueCount || 0
            findingCount = d.findingCount === undefined ? issueCount : d.findingCount
            findings.clear()
            previewRows.clear()
            previewCols = d.previewColumns || []
            var rows = d.rows || []
            for (var i = 0; i < rows.length; ++i) {
                var r = rows[i]
                if (r.issues && r.issues.length) {
                    findings.append({
                        row: String(r.row),
                        severity: String(r.severity),
                        problem: r.issues.join("; ")
                    })
                }
            }
            var pp = d.previewRows || []
            for (var j = 0; j < pp.length; ++j)
                previewRows.append({ valuesJson: JSON.stringify(pp[j]) })
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 22
        spacing: 10

        PageTitle { text: "Review One File" }
        Text {
            text: "Review a dataset without a Master file. The loaded file is previewed below; source data remains unchanged until export."
            color: "#94a3b8"
        }

        Card {
            Layout.fillWidth: true
            implicitHeight: 72
            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                TextField {
                    Layout.fillWidth: true
                    readOnly: true
                    text: src
                    placeholderText: "Choose CSV / Excel / text file"
                }
                AppButton { text: "Choose File"; onClicked: openDlg.open() }
                PrimaryButton { text: "Analyze"; enabled: src !== ""; onClicked: backend.reviewSingleFile(src) }
                AppButton { text: "Export Reviewed Copy"; enabled: src !== ""; onClicked: saveDlg.open() }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Card {
                Layout.fillWidth: true
                implicitHeight: 62
                Column {
                    anchors.fill: parent
                    anchors.margins: 8
                    Text { text: total; color: "#22c55e"; font.pixelSize: 18; font.bold: true }
                    Text { text: "RECORDS"; color: "#94a3b8"; font.pixelSize: 9 }
                }
            }
            Card {
                Layout.fillWidth: true
                implicitHeight: 62
                Column {
                    anchors.fill: parent
                    anchors.margins: 8
                    Text { text: issueCount; color: issueCount ? "#f59e0b" : "#22c55e"; font.pixelSize: 18; font.bold: true }
                    Text { text: "RECORDS NEEDING ATTENTION"; color: "#94a3b8"; font.pixelSize: 9 }
                }
            }
        }

        Card {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(360, Math.max(150, 85 + previewRows.count * 32))
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 5
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "File Preview"; color: "#f8fafc"; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { text: previewRows.count ? previewRows.count + " row(s) shown" : "No preview loaded"; color: "#94a3b8" }
                }
                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: Math.max(width, previewCols.length * 170)
                    contentHeight: previewTable.height
                    Column {
                        id: previewTable
                        width: Math.max(parent.width, previewCols.length * 170)
                        Row {
                            height: 32
                            Repeater {
                                model: previewCols
                                delegate: Rectangle {
                                    required property var modelData
                                    width: 170
                                    height: 32
                                    color: "#132238"
                                    border.width: 1
                                    border.color: "#29415f"
                                    Text { anchors.fill: parent; anchors.margins: 6; text: String(modelData); color: "#bfdbfe"; font.bold: true; elide: Text.ElideRight }
                                }
                            }
                        }
                        Repeater {
                            model: previewRows
                            delegate: Rectangle {
                                required property int index
                                required property string valuesJson
                                property var vals: JSON.parse(valuesJson)
                                width: previewTable.width
                                height: 31
                                color: index % 2 ? "#0d1b2e" : "#0b1829"
                                Row {
                                    anchors.fill: parent
                                    Repeater {
                                        model: vals
                                        delegate: Rectangle {
                                            required property var modelData
                                            width: 170
                                            height: 31
                                            color: "transparent"
                                            border.width: 1
                                            border.color: "#17283d"
                                            Text { anchors.fill: parent; anchors.margins: 5; text: modelData === null ? "" : String(modelData); color: "#f8fafc"; elide: Text.ElideRight }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    ScrollBar.vertical: ScrollBar { }
                    ScrollBar.horizontal: ScrollBar { }
                }
            }
        }

        Card {
            Layout.fillWidth: true
            Layout.preferredHeight: issueCount ? Math.min(250, 76 + findings.count * 40) : 70
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Records Needing Attention"; color: "#f8fafc"; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { text: issueCount ? (issueCount + " record(s), " + findingCount + " finding(s)") : "No findings"; color: issueCount ? "#f59e0b" : "#22c55e" }
                }
                Text {
                    visible: issueCount === 0
                    text: "✓ No records need attention. The empty results area is collapsed so the preview remains the focus."
                    color: "#22c55e"
                }
                RowLayout {
                    visible: issueCount > 0
                    Layout.fillWidth: true
                    Text { text: "Row"; color: "#94a3b8"; font.bold: true; Layout.preferredWidth: 80 }
                    Text { text: "State"; color: "#94a3b8"; font.bold: true; Layout.preferredWidth: 110 }
                    Text { text: "Finding"; color: "#94a3b8"; font.bold: true; Layout.fillWidth: true }
                }
                ListView {
                    visible: issueCount > 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: findings
                    clip: true
                    delegate: Rectangle {
                        required property int index
                        required property string row
                        required property string severity
                        required property string problem
                        width: ListView.view.width
                        height: 40
                        color: index % 2 ? "#0d1b2e" : "#0b1829"
                        RowLayout {
                            anchors.fill: parent
                            Text { text: row; color: "#f8fafc"; Layout.preferredWidth: 80; leftPadding: 6 }
                            Text { text: severity; color: "#f59e0b"; font.bold: true; Layout.preferredWidth: 110 }
                            Text { text: problem; color: "#f8fafc"; Layout.fillWidth: true; elide: Text.ElideRight }
                        }
                    }
                }
            }
        }
        Item { Layout.fillHeight: true }
    }
}
