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
    property int totalRows: 0
    property int displayedRows: 0
    property bool truncated: false
    property string searchText: ""
    property string searchColumn: ""
    property string sqlText: ""

    function backendAvailable() {
        return typeof backend !== "undefined" && backend !== null && backend.health !== undefined && backend.health !== null
    }

    function urlToPath(value) {
        var text = String(value || "")
        if (text.indexOf("file:///") === 0)
            text = text.substring(8)
        else if (text.indexOf("file://") === 0)
            text = text.substring(7)
        if (Qt.platform.os === "windows")
            text = text.replace(/^\/+/, "")
        try {
            return decodeURIComponent(text)
        } catch (error) {
            return text
        }
    }

    function loadData() {
        if (root.backendAvailable() && root.sourcePath !== "")
            backend.health.load_data(root.sourcePath)
    }

    function executeSearch() {
        if (root.backendAvailable() && root.searchText.trim() !== "")
            backend.health.search(root.searchText, root.searchColumn)
    }

    function executeSql() {
        if (root.backendAvailable() && root.sqlText.trim() !== "")
            backend.health.sql(root.sqlText)
    }

    function rowValue(row, column) {
        if (row === null || row === undefined)
            return ""
        if (Array.isArray(row)) {
            var index = root.columns.indexOf(column)
            if (index >= 0 && index < row.length && row[index] !== null && row[index] !== undefined)
                return String(row[index])
            return ""
        }
        if (typeof row === "object") {
            var value = row[column]
            return value === null || value === undefined ? "" : String(value)
        }
        return ""
    }

    FileDialog {
        id: fileDialog
        title: "Select Dataset"
        nameFilters: [
            "Data Files (*.csv *.xlsx *.xls *.xlsm *.tsv *.txt)",
            "All Files (*)"
        ]
        onAccepted: {
            root.sourcePath = root.urlToPath(selectedFile)
            root.loadData()
        }
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
            } catch (error) {
                root.columns = []
                root.rows = []
                root.totalRows = 0
                root.displayedRows = 0
                root.truncated = false
            }
        }
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
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacingXLarge
                Layout.rightMargin: Theme.spacingXLarge
                Layout.topMargin: Theme.spacingLarge
                title: "Explore Data"
                subtitle: "Search, inspect, and query your loaded dataset."
            }

            Card {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacingXLarge
                Layout.rightMargin: Theme.spacingXLarge
                Layout.preferredHeight: 115
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMedium
                    Text {
                        text: "Dataset"
                        color: Theme.textSecondary
                        font.bold: true
                        Layout.preferredWidth: 75
                    }
                    TextField {
                        Layout.fillWidth: true
                        readOnly: true
                        text: root.sourcePath
                        placeholderText: "Select CSV or spreadsheet"
                        color: Theme.textPrimary
                    }
                    AppButton {
                        text: "Browse"
                        onClicked: fileDialog.open()
                    }
                    PrimaryButton {
                        text: "Load"
                        enabled: root.sourcePath !== ""
                        onClicked: root.loadData()
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacingXLarge
                Layout.rightMargin: Theme.spacingXLarge
                spacing: Theme.spacingMedium
                Repeater {
                    model: [
                        { label: "TOTAL ROWS", value: root.totalRows, tone: Theme.primary },
                        { label: "COLUMNS", value: root.columns.length, tone: Theme.info },
                        { label: "DISPLAYED", value: root.displayedRows, tone: Theme.success },
                        { label: "TRUNCATED", value: root.truncated ? "YES" : "NO", tone: root.truncated ? Theme.warning : Theme.success }
                    ]
                    delegate: Card {
                        id: metricDelegate
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 82
                        ColumnLayout {
                            anchors.centerIn: parent
                            Text {
                                text: metricDelegate.modelData.value
                                color: metricDelegate.modelData.tone
                                font.pixelSize: 22
                                font.bold: true
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: metricDelegate.modelData.label
                                color: Theme.textSecondary
                                font.pixelSize: 10
                                font.bold: true
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                }
            }

            Card {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacingXLarge
                Layout.rightMargin: Theme.spacingXLarge
                Layout.preferredHeight: 120
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMedium
                    Text {
                        text: "Search Dataset"
                        color: Theme.textPrimary
                        font.pixelSize: 14
                        font.bold: true
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        ComboBox {
                            id: columnCombo
                            Layout.preferredWidth: 220
                            model: ["All Columns"].concat(root.columns)
                            onActivated: root.searchColumn = currentIndex <= 0 ? "" : currentText
                        }
                        TextField {
                            Layout.fillWidth: true
                            placeholderText: "Search for a value..."
                            text: root.searchText
                            color: Theme.textPrimary
                            onTextChanged: root.searchText = text
                            onAccepted: root.executeSearch()
                        }
                        PrimaryButton {
                            text: "Search"
                            enabled: root.searchText.trim() !== ""
                            onClicked: root.executeSearch()
                        }
                        AppButton {
                            text: "Clear"
                            onClicked: {
                                root.searchText = ""
                                root.loadData()
                            }
                        }
                    }
                }
            }

            Card {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacingXLarge
                Layout.rightMargin: Theme.spacingXLarge
                Layout.preferredHeight: 150
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMedium
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "SQL Query"
                            color: Theme.textPrimary
                            font.pixelSize: 14
                            font.bold: true
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "Run against the loaded dataset"
                            color: Theme.textSecondary
                            font.pixelSize: 10
                        }
                    }
                    TextArea {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        text: root.sqlText
                        placeholderText: "SELECT * FROM data LIMIT 100"
                        color: Theme.textPrimary
                        wrapMode: TextEdit.NoWrap
                        onTextChanged: root.sqlText = text
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Item { Layout.fillWidth: true }
                        AppButton {
                            text: "Reset"
                            onClicked: root.sqlText = ""
                        }
                        PrimaryButton {
                            text: "Run SQL"
                            enabled: root.sqlText.trim() !== ""
                            onClicked: root.executeSql()
                        }
                    }
                }
            }

            Card {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacingXLarge
                Layout.rightMargin: Theme.spacingXLarge
                Layout.bottomMargin: Theme.spacingXLarge
                Layout.preferredHeight: 650
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMedium
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Data Preview"
                            color: Theme.textPrimary
                            font.pixelSize: 15
                            font.bold: true
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            visible: root.truncated
                            text: "Showing " + root.displayedRows + " of " + root.totalRows
                            color: Theme.warning
                            font.pixelSize: 11
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: Theme.background
                        border.color: Theme.border
                        radius: Theme.radiusMedium
                        clip: true
                        Flickable {
                            id: tableFlick
                            anchors.fill: parent
                            clip: true
                            contentWidth: Math.max(width, root.columns.length * 160)
                            contentHeight: tableColumn.height
                            boundsBehavior: Flickable.StopAtBounds
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                            ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
                            Column {
                                id: tableColumn
                                width: Math.max(tableFlick.width, root.columns.length * 160)
                                Rectangle {
                                    width: tableColumn.width
                                    height: 40
                                    color: Theme.surfaceHover
                                    border.color: Theme.border
                                    Row {
                                        anchors.fill: parent
                                        Repeater {
                                            model: root.columns
                                            delegate: Rectangle {
                                                id: headerDelegate
                                                required property string modelData
                                                width: 160
                                                height: 40
                                                color: "transparent"
                                                border.color: Theme.border
                                                Text {
                                                    anchors.fill: parent
                                                    anchors.margins: 7
                                                    text: headerDelegate.modelData
                                                    color: Theme.textSecondary
                                                    font.bold: true
                                                    font.pixelSize: 11
                                                    elide: Text.ElideRight
                                                    verticalAlignment: Text.AlignVCenter
                                                }
                                            }
                                        }
                                    }
                                }
                                Repeater {
                                    model: root.rows
                                    delegate: Row {
                                        id: rowDelegate
                                        required property var modelData
                                        required property int index
                                        readonly property var rowData: modelData
                                        readonly property int rowIndex: index
                                        width: tableColumn.width
                                        height: 40
                                        Repeater {
                                            model: root.columns
                                            delegate: Rectangle {
                                                id: cellDelegate
                                                required property string modelData
                                                required property int index
                                                width: 160
                                                height: 40
                                                color: cellDelegate.index % 2 === 0 ? Theme.background : Theme.surface
                                                border.color: Theme.border
                                                Text {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 7
                                                    anchors.rightMargin: 7
                                                    text: root.rowValue(rowDelegate.rowData, cellDelegate.modelData)
                                                    color: Theme.textPrimary
                                                    font.pixelSize: 11
                                                    elide: Text.ElideRight
                                                    verticalAlignment: Text.AlignVCenter
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        Text {
                            visible: root.rows.length === 0
                            anchors.centerIn: parent
                            text: root.sourcePath === "" ? "Load a dataset to begin." : "No rows returned."
                            color: Theme.textMuted
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }
    }
}
