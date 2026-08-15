pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"
import "../theme"

Item {
    id: root

    property string sourcePath: ""
    property var columns: []
    property var rows: []
    property var statsData: ({})
    property var healthData: ({})
    property int totalRows: 0
    property int displayedRows: 0
    property bool truncated: false
    property string selectedColumn: ""
    property string selectedOperation: "count"
    property string groupColumn: ""

    function backendAvailable() { return typeof backend !== "undefined" && backend !== null && backend.health !== undefined && backend.health !== null }
    function urlToPath(value) {
        var text = String(value || "")
        if (text.indexOf("file:///") === 0) text = text.substring(8)
        else if (text.indexOf("file://") === 0) text = text.substring(7)
        if (Qt.platform.os === "windows") text = text.replace(/^\/+/, "")
        try { return decodeURIComponent(text) } catch (e) { return text }
    }
    function loadData() { if (root.backendAvailable() && root.sourcePath !== "") backend.health.load_data(root.sourcePath) }
    function calculateStats() { if (root.backendAvailable() && root.selectedColumn !== "") backend.health.stats(root.selectedColumn, root.selectedOperation, root.groupColumn) }
    function rowValue(row, column) {
        if (row === null || row === undefined) return ""
        if (Array.isArray(row)) {
            var index = root.columns.indexOf(column)
            return index >= 0 && index < row.length && row[index] !== null && row[index] !== undefined ? String(row[index]) : ""
        }
        if (typeof row === "object") {
            var value = row[column]
            return value === null || value === undefined ? "" : String(value)
        }
        return ""
    }
    function formatStatValue(value) {
        if (value === null || value === undefined) return "—"
        if (typeof value === "object") {
            if (Array.isArray(value)) return value.length + " item(s)"
            var keys = Object.keys(value)
            if (keys.length === 0) return "—"
            return keys.slice(0, 3).map(function(key) { return key + ": " + String(value[key]) }).join(" • ") + (keys.length > 3 ? " …" : "")
        }
        return String(value)
    }
    function statRows() { return root.statsData && Array.isArray(root.statsData.rows) ? root.statsData.rows : [] }
    function statsAvailable() { return root.statsData && Object.keys(root.statsData).length > 0 }

    FileDialog {
        id: fileDialog
        title: "Select Dataset"
        nameFilters: ["Data Files (*.csv *.xlsx *.xls *.xlsm *.tsv *.txt)", "All Files (*)"]
        onAccepted: { root.sourcePath = root.urlToPath(selectedFile); root.loadData() }
    }
    FileDialog {
        id: reportDialog
        title: "Export Health Report"
        fileMode: FileDialog.SaveFile
        currentFile: "health_report.html"
        nameFilters: ["HTML Files (*.html)", "All Files (*)"]
        onAccepted: if (root.backendAvailable()) backend.health.export_health_report(root.urlToPath(selectedFile))
    }

    Connections {
        target: root.backendAvailable() ? backend.health : null
        ignoreUnknownSignals: true
        function onTableReady(payload) {
            try {
                var data = JSON.parse(String(payload || "{}"))
                root.columns = Array.isArray(data.columns) ? data.columns : []
                root.rows = Array.isArray(data.rows) ? data.rows : []
                root.totalRows = Number(data.total || 0)
                root.displayedRows = Number(data.displayed === undefined ? root.rows.length : data.displayed)
                root.truncated = Boolean(data.truncated)
                if (root.selectedColumn === "" && root.columns.length) root.selectedColumn = String(root.columns[0])
            } catch (error) { root.columns = []; root.rows = []; root.totalRows = 0; root.displayedRows = 0; root.truncated = false }
        }
        function onStatsReady(payload) { try { root.statsData = JSON.parse(String(payload || "{}")) } catch (error) { root.statsData = ({}) } }
        function onHealthReady(payload) { try { root.healthData = JSON.parse(String(payload || "{}")) } catch (error) { root.healthData = ({}) } }
    }

    ScrollView {
        id: scrollView
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        ColumnLayout {
            width: scrollView.availableWidth
            spacing: Theme.spacingLarge

            PageTitle {
                Layout.fillWidth: true; Layout.leftMargin: Theme.spacingXLarge; Layout.rightMargin: Theme.spacingXLarge; Layout.topMargin: Theme.spacingLarge
                title: "Data Health"; subtitle: "Profile your dataset, calculate statistics, and inspect data quality."
            }

            Card {
                Layout.fillWidth: true; Layout.leftMargin: Theme.spacingXLarge; Layout.rightMargin: Theme.spacingXLarge; Layout.preferredHeight: 115
                RowLayout {
                    anchors.fill: parent; anchors.margins: Theme.spacingMedium; spacing: Theme.spacingSmall
                    Text { text: "Dataset"; color: Theme.textSecondary; font.bold: true; Layout.preferredWidth: 75 }
                    TextField { Layout.fillWidth: true; readOnly: true; text: root.sourcePath; placeholderText: "Select dataset"; color: Theme.textPrimary }
                    AppButton { text: "Browse"; onClicked: fileDialog.open() }
                    PrimaryButton { text: "Analyze"; enabled: root.sourcePath !== ""; onClicked: root.loadData() }
                    AppButton { text: "Export Report"; enabled: root.totalRows > 0; onClicked: reportDialog.open() }
                }
            }

            RowLayout {
                Layout.fillWidth: true; Layout.leftMargin: Theme.spacingXLarge; Layout.rightMargin: Theme.spacingXLarge; spacing: Theme.spacingMedium
                Repeater {
                    model: [
                        {label: "TOTAL ROWS", value: root.totalRows, tone: Theme.primary},
                        {label: "COLUMNS", value: root.columns.length, tone: Theme.info},
                        {label: "HEALTH SCORE", value: root.healthData && root.healthData.score !== undefined ? root.healthData.score : 0, tone: Theme.success},
                        {label: "PREVIEW", value: root.truncated ? "LIMITED" : "FULL", tone: root.truncated ? Theme.warning : Theme.success}
                    ]
                    delegate: Card {
                        required property var modelData
                        Layout.fillWidth: true; Layout.preferredHeight: 82
                        ColumnLayout { anchors.centerIn: parent; Text { text: modelData.value; color: modelData.tone; font.pixelSize: 22; font.bold: true; Layout.alignment: Qt.AlignHCenter }; Text { text: modelData.label; color: Theme.textSecondary; font.pixelSize: 10; font.bold: true; Layout.alignment: Qt.AlignHCenter } }
                    }
                }
            }

            Card {
                Layout.fillWidth: true; Layout.leftMargin: Theme.spacingXLarge; Layout.rightMargin: Theme.spacingXLarge; Layout.preferredHeight: 150
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: Theme.spacingMedium; spacing: Theme.spacingSmall
                    Text { text: "Column Statistics"; color: Theme.textPrimary; font.pixelSize: 15; font.bold: true }
                    RowLayout {
                        Layout.fillWidth: true
                        ComboBox { id: columnCombo; Layout.fillWidth: true; model: root.columns; currentIndex: Math.max(0, root.columns.indexOf(root.selectedColumn)); onActivated: root.selectedColumn = currentText }
                        ComboBox { id: operationCombo; Layout.preferredWidth: 170; model: ["count","unique","nulls","mean","median","min","max","sum"]; currentIndex: Math.max(0, model.indexOf(root.selectedOperation)); onActivated: root.selectedOperation = currentText }
                        ComboBox { id: groupCombo; Layout.preferredWidth: 190; model: ["No Group"].concat(root.columns); currentIndex: root.groupColumn === "" ? 0 : root.columns.indexOf(root.groupColumn) + 1; onActivated: root.groupColumn = currentIndex <= 0 ? "" : root.columns[currentIndex - 1] }
                        PrimaryButton { text: "Calculate"; enabled: root.selectedColumn !== ""; onClicked: root.calculateStats() }
                    }
                    Text { text: root.selectedColumn === "" ? "Select a column to calculate statistics." : "Column: " + root.selectedColumn + (root.groupColumn !== "" ? " • Grouped by " + root.groupColumn : ""); color: Theme.textSecondary; font.pixelSize: 11 }
                }
            }

            Card {
                visible: root.statsAvailable()
                Layout.fillWidth: true; Layout.leftMargin: Theme.spacingXLarge; Layout.rightMargin: Theme.spacingXLarge; Layout.preferredHeight: Math.max(130, Math.min(360, 120 + root.statRows().length * 42))
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: Theme.spacingMedium; spacing: Theme.spacingSmall
                    Text { text: "Statistics Result"; color: Theme.textPrimary; font.pixelSize: 15; font.bold: true }
                    RowLayout { Layout.fillWidth: true; Text { text: "Column: " + String(root.statsData.column || ""); color: Theme.textSecondary; Layout.fillWidth: true }; Text { text: "Operation: " + String(root.statsData.operation || ""); color: Theme.info } }
                    ListView {
                        Layout.fillWidth: true; Layout.fillHeight: true; clip: true; model: root.statRows(); ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        delegate: Rectangle {
                            id: statDelegate
                            required property var modelData
                            width: ListView.view.width; height: 40; color: Theme.background; border.color: Theme.border
                            RowLayout { anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; Text { text: String(statDelegate.modelData.label || ""); color: Theme.textSecondary; Layout.preferredWidth: 220; elide: Text.ElideRight }; Text { text: String(statDelegate.modelData.result === undefined ? "" : statDelegate.modelData.result); color: Theme.textPrimary; Layout.fillWidth: true; elide: Text.ElideRight } }
                        }
                    }
                }
            }

            Card {
                visible: root.healthData && Object.keys(root.healthData).length > 0
                Layout.fillWidth: true; Layout.leftMargin: Theme.spacingXLarge; Layout.rightMargin: Theme.spacingXLarge; Layout.preferredHeight: Math.max(160, Math.min(420, 100 + Object.keys(root.healthData).length * 38))
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: Theme.spacingMedium; spacing: Theme.spacingSmall
                    Text { text: "Dataset Health"; color: Theme.textPrimary; font.pixelSize: 15; font.bold: true }
                    GridLayout {
                        Layout.fillWidth: true; Layout.fillHeight: true; columns: 3; rowSpacing: Theme.spacingSmall; columnSpacing: Theme.spacingMedium
                        Repeater {
                            model: Object.keys(root.healthData || {})
                            delegate: Rectangle {
                                id: healthDelegate
                                required property string modelData
                                Layout.fillWidth: true; Layout.preferredHeight: 42; color: Theme.background; border.color: Theme.border; radius: Theme.radiusMedium
                                RowLayout { anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; Text { text: healthDelegate.modelData; color: Theme.textSecondary; font.pixelSize: 10; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }; Text { text: root.formatStatValue(root.healthData[healthDelegate.modelData]); color: Theme.textPrimary; font.bold: true; elide: Text.ElideRight } }
                            }
                        }
                    }
                }
            }

            Card {
                Layout.fillWidth: true; Layout.leftMargin: Theme.spacingXLarge; Layout.rightMargin: Theme.spacingXLarge; Layout.bottomMargin: Theme.spacingXLarge; Layout.preferredHeight: 620
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: Theme.spacingMedium; spacing: Theme.spacingSmall
                    RowLayout { Layout.fillWidth: true; Text { text: "Data Preview"; color: Theme.textPrimary; font.pixelSize: 15; font.bold: true }; Item { Layout.fillWidth: true }; Text { text: root.displayedRows + " displayed"; color: Theme.textSecondary; font.pixelSize: 11 } }
                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true; color: Theme.background; border.color: Theme.border; radius: Theme.radiusMedium; clip: true
                        Flickable {
                            id: tableFlick
                            anchors.fill: parent; clip: true; contentWidth: Math.max(width, root.columns.length * 160); contentHeight: tableColumn.height; boundsBehavior: Flickable.StopAtBounds
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }; ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
                            Column {
                                id: tableColumn
                                width: Math.max(tableFlick.width, root.columns.length * 160)
                                Rectangle { width: tableColumn.width; height: 40; color: Theme.surfaceHover; border.color: Theme.border; Row { anchors.fill: parent; Repeater { model: root.columns; delegate: Rectangle { id: headerDelegate; required property string modelData; width: 160; height: 40; color: "transparent"; border.color: Theme.border; Text { anchors.fill: parent; anchors.margins: 7; text: headerDelegate.modelData; color: Theme.textSecondary; font.bold: true; font.pixelSize: 11; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter } } } } }
                                Repeater {
                                    model: root.rows
                                    delegate: Row {
                                        id: rowDelegate
                                        required property var modelData
                                        required property int index
                                        readonly property var rowData: modelData
                                        readonly property int rowIndex: index
                                        width: tableColumn.width; height: 40
                                        Repeater {
                                            model: root.columns
                                            delegate: Rectangle {
                                                id: cellDelegate
                                                required property string modelData
                                                required property int index
                                                width: 160; height: 40; color: cellDelegate.index % 2 === 0 ? Theme.background : Theme.surface; border.color: Theme.border
                                                Text { anchors.fill: parent; anchors.leftMargin: 7; anchors.rightMargin: 7; text: root.rowValue(rowDelegate.rowData, cellDelegate.modelData); color: Theme.textPrimary; font.pixelSize: 11; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        Text { visible: root.rows.length === 0; anchors.centerIn: parent; text: root.sourcePath === "" ? "Load a dataset to begin." : "No preview rows available."; color: Theme.textMuted; font.pixelSize: 13 }
                    }
                }
            }
        }
    }
}
