import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"
import "../theme"

Item {
    id: root
    property string currentFile: ""
    property var availableCols: []
    property var statsResult: null

    function urlToPath(urlStr) {
        var path = urlStr.toString();
        path = path.replace(/^(file:\/{2,3})/, "");
        if (Qt.platform.os !== "windows" && path.charAt(0) === '/' && path.charAt(2) === ':') {
            path = path.substring(1);
        }
        return decodeURIComponent(path);
    }

    FileDialog {
        id: fileDialog
        title: "Load Dataset for Profiling"
        nameFilters: ["Data (*.csv *.xlsx)"]
        onAccepted: {
            currentFile = urlToPath(selectedFile)
            if (typeof backend !== "undefined" && backend.health) { backend.health.load_data(currentFile) }
        }
    }

    FileDialog {
        id: saveDialog
        title: "Export Health Report"
        fileMode: FileDialog.SaveFile
        nameFilters: ["HTML Report (*.html)"]
        onAccepted: {
            if (typeof backend !== "undefined" && backend.health) { backend.health.export_health_report(urlToPath(selectedFile)) }
        }
    }

    Connections {
        target: typeof backend !== "undefined" ? backend.health : null
        ignoreUnknownSignals: true

        function onTableReady(payload) {
            try { var d = JSON.parse(payload); availableCols = d.columns || []; statsResult = null } catch(e) {}
        }
        function onHealthReady(payload) {
            try { statsResult = JSON.parse(payload) } catch(e) {}
        }
        function onStatsReady(payload) {
            try { statsResult = JSON.parse(payload) } catch(e) {}
        }
    }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: Theme.spacingXLarge; spacing: Theme.spacingLarge

        PageTitle { title: "Health & Statistics"; subtitle: "Profile dataset health and run statistical operations."; Layout.fillWidth: true }

        Card {
            Layout.fillWidth: true; Layout.preferredHeight: 120
            ColumnLayout {
                anchors.fill: parent; anchors.margins: Theme.spacingMedium; spacing: Theme.spacingSmall
                RowLayout {
                    Layout.fillWidth: true; spacing: Theme.spacingMedium
                    AppButton { text: "Load Dataset"; onClicked: fileDialog.open() }
                    Text { text: currentFile !== "" ? currentFile : "No dataset loaded."; color: Theme.textSecondary; Layout.fillWidth: true; elide: Text.ElideRight }
                    PrimaryButton { text: "Export Report"; enabled: root.currentFile !== ""; onClicked: saveDialog.open() }
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: Theme.spacingMedium
                    Text { text: "Column:"; color: Theme.textSecondary }
                    ComboBox {
                        id: colCombo
                        Layout.preferredWidth: 150; model: availableCols
                        background: Rectangle { color: Theme.background; border.color: Theme.border; radius: Theme.radiusMedium }
                        contentItem: Text { text: parent.currentIndex >= 0 ? parent.currentText : ""; color: Theme.textPrimary; verticalAlignment: Text.AlignVCenter; leftPadding: 8 }
                    }
                    Text { text: "Operation:"; color: Theme.textSecondary }
                    ComboBox {
                        id: opCombo
                        Layout.preferredWidth: 120; model: ["COUNT", "SUM", "AVG", "MIN", "MAX"]
                        background: Rectangle { color: Theme.background; border.color: Theme.border; radius: Theme.radiusMedium }
                        contentItem: Text { text: parent.currentIndex >= 0 ? parent.currentText : ""; color: Theme.textPrimary; verticalAlignment: Text.AlignVCenter; leftPadding: 8 }
                    }
                    Text { text: "Group By:"; color: Theme.textSecondary }
                    ComboBox {
                        id: groupCombo
                        Layout.preferredWidth: 150; model: ["(None)"].concat(availableCols)
                        background: Rectangle { color: Theme.background; border.color: Theme.border; radius: Theme.radiusMedium }
                        contentItem: Text { text: parent.currentIndex >= 0 ? parent.currentText : ""; color: Theme.textPrimary; verticalAlignment: Text.AlignVCenter; leftPadding: 8 }
                    }
                    AppButton { 
                        text: "Calculate"
                        enabled: availableCols.length > 0
                        onClicked: { if (backend && backend.health) { backend.health.stats(colCombo.currentText, opCombo.currentText, groupCombo.currentText === "(None)" ? "" : groupCombo.currentText) } }
                    }
                }
            }
        }

        Card {
            Layout.fillWidth: true; Layout.fillHeight: true
            ColumnLayout {
                anchors.fill: parent; anchors.margins: Theme.spacingMedium; spacing: Theme.spacingSmall
                Text { text: "Statistical Output"; color: Theme.textPrimary; font.bold: true }
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true; color: Theme.background; border.color: Theme.border; radius: Theme.radiusMedium
                    ScrollView {
                        anchors.fill: parent; anchors.margins: Theme.spacingMedium; clip: true
                        Text { text: statsResult ? JSON.stringify(statsResult, null, 2) : "Run an operation to view statistics."; color: statsResult ? Theme.textPrimary : Theme.textMuted; wrapMode: Text.WordWrap }
                    }
                }
            }
        }
    }
}
