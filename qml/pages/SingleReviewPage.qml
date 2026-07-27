import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"

Item {
    property string src: ""
    property int total: 0
    property int issueCount: 0
    ListModel { id: findings }

    FileDialog {
        id: openDlg
        nameFilters: ["Data (*.csv *.xlsx *.xls *.xlsm *.txt *.tsv *.json *.xml)"]
        onAccepted: { src = selectedFile.toString(); backend.reviewSingleFile(src) }
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
            findings.clear()
            for (var i = 0; i < d.rows.length; ++i) {
                var r = d.rows[i]
                if (r.issues.length) findings.append({row: String(r.row), severity: String(r.severity), problem: r.issues.join("; ")})
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 22
        spacing: 10
        PageTitle { text: "Review One File" }
        Text { text: "Review a dataset without a Master file. Source data remains unchanged until you export a reviewed copy."; color: "#94a3b8" }

        Card {
            Layout.fillWidth: true
            implicitHeight: 72
            RowLayout {
                anchors.fill: parent; anchors.margins: 10
                TextField { Layout.fillWidth: true; readOnly: true; text: src; placeholderText: "Choose CSV / Excel / text file" }
                AppButton { text: "Choose File"; onClicked: openDlg.open() }
                PrimaryButton { text: "Analyze"; enabled: src !== ""; onClicked: backend.reviewSingleFile(src) }
                AppButton { text: "Export Reviewed Copy"; enabled: src !== ""; onClicked: saveDlg.open() }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Card { Layout.fillWidth: true; implicitHeight: 62; Column { anchors.fill: parent; anchors.margins: 8; Text { text: total; color: "#22c55e"; font.pixelSize: 18; font.bold: true } Text { text: "RECORDS"; color: "#94a3b8"; font.pixelSize: 9 } } }
            Card { Layout.fillWidth: true; implicitHeight: 62; Column { anchors.fill: parent; anchors.margins: 8; Text { text: issueCount; color: issueCount ? "#f59e0b" : "#22c55e"; font.pixelSize: 18; font.bold: true } Text { text: "NEEDS ATTENTION"; color: "#94a3b8"; font.pixelSize: 9 } } }
        }

        Card {
            Layout.fillWidth: true; Layout.fillHeight: true
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 10
                Text { text: "Records Needing Attention"; color: "#f8fafc"; font.bold: true }
                RowLayout { Layout.fillWidth: true; Text { text: "Row"; color: "#94a3b8"; font.bold: true; Layout.preferredWidth: 80 } Text { text: "State"; color: "#94a3b8"; font.bold: true; Layout.preferredWidth: 110 } Text { text: "Finding"; color: "#94a3b8"; font.bold: true; Layout.fillWidth: true } }
                ListView { Layout.fillWidth: true; Layout.fillHeight: true; model: findings; clip: true; delegate: Rectangle { required property int index; required property string row; required property string severity; required property string problem; width: ListView.view.width; height: 40; color: index % 2 ? "#0d1b2e" : "#0b1829"; RowLayout { anchors.fill: parent; Text { text: row; color: "#f8fafc"; Layout.preferredWidth: 80; leftPadding: 6 } Text { text: severity; color: "#f59e0b"; font.bold: true; Layout.preferredWidth: 110 } Text { text: problem; color: "#f8fafc"; Layout.fillWidth: true; elide: Text.ElideRight } } } }
            }
        }
    }
}