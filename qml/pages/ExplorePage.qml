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
    property var sqlSuggestions: []

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

    function quoteIdentifier(value) {
        return '"' + String(value || "").replace(/"/g, '""') + '"'
    }

    function rebuildSqlSuggestions() {
        var suggestions = [
            "SELECT * FROM data LIMIT 100",
            "SELECT COUNT(*) AS row_count FROM data"
        ]
        var firstColumn = root.columns.length > 0 ? String(root.columns[0]) : ""
        if (firstColumn !== "") {
            var q = root.quoteIdentifier(firstColumn)
            suggestions.push("SELECT " + q + " FROM data LIMIT 100")
            suggestions.push("SELECT DISTINCT " + q + " FROM data ORDER BY " + q + " LIMIT 100")
            suggestions.push("SELECT " + q + ", COUNT(*) AS count FROM data GROUP BY " + q + " ORDER BY count DESC LIMIT 20")
        }
        if (root.columns.length > 1) {
            suggestions.push("SELECT " + root.quoteIdentifier(root.columns[0]) + ", " + root.quoteIdentifier(root.columns[1]) + " FROM data LIMIT 100")
        }
        root.sqlSuggestions = suggestions
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

    function useExampleSql() {
        root.sqlText = root.sqlSuggestions.length > 0 ? String(root.sqlSuggestions[0]) : "SELECT * FROM data LIMIT 100"
    }

    function useSqlSuggestion(index) {
        if (index >= 0 && index < root.sqlSuggestions.length)
            root.sqlText = String(root.sqlSuggestions[index])
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
                root.rebuildSqlSuggestions()
            } catch (error) {
                root.columns = []
                root.rows = []
                root.totalRows = 0
                root.displayedRows = 0
                root.truncated = false
                root.sqlSuggestions = ["SELECT * FROM data LIMIT 100", "SELECT COUNT(*) AS row_count FROM data"]
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
                        placeholderTextColor: Theme.textMuted
                        color: Theme.textPrimary
                        background: Rectangle {
                            color: Theme.background
                            border.color: Theme.border
                            radius: Theme.radiusSmall
                        }
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
                            contentItem: Text {
                                leftPadding: 12
                                rightPadding: 30
                                text: columnCombo.displayText
                                color: Theme.textPrimary
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                            background: Rectangle {
                                color: Theme.background
                                border.color: Theme.border
                                radius: Theme.radiusSmall
                            }
                            indicator: Text {
                                x: columnCombo.width - width - 10
                                y: (columnCombo.height - height) / 2
                                text: "▾"
                                color: Theme.textSecondary
                            }
                        }
                        TextField {
                            Layout.fillWidth: true
                            placeholderText: "Search for a value..."
                            placeholderTextColor: Theme.textMuted
                            text: root.searchText
                            color: Theme.textPrimary
                            background: Rectangle {
                                color: Theme.background
                                border.color: Theme.border
                                radius: Theme.radiusSmall
                            }
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
                                root.searchColumn = ""
                                columnCombo.currentIndex = 0
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
                Layout.preferredHeight: 205
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
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Automatic suggestion"
                            color: Theme.textSecondary
                            font.pixelSize: 11
                            font.bold: true
                        }
                        ComboBox {
                            id: sqlSuggestionCombo
                            Layout.fillWidth: true
                            Layout.preferredHeight: Theme.fieldHeight
                            model: ["Choose a query suggestion..."] .concat(root.sqlSuggestions)
                            onActivated: {
                                if (currentIndex > 0)
                                    root.useSqlSuggestion(currentIndex - 1)
                                currentIndex = 0
                            }
                            contentItem: Text {
                                leftPadding: 12
                                rightPadding: 30
                                text: sqlSuggestionCombo.displayText
                                color: sqlSuggestionCombo.currentIndex > 0 ? Theme.textPrimary : Theme.textMuted
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                            background: Rectangle {
                                color: Theme.background
                                border.color: Theme.border
                                radius: Theme.radiusSmall
                            }
                            indicator: Text {
                                x: sqlSuggestionCombo.width - width - 10
                                y: (sqlSuggestionCombo.height - height) / 2
                                text: "▾"
                                color: Theme.textSecondary
                            }
                        }
                    }
                    TextArea {
                        id: sqlEditor
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        text: root.sqlText
                        placeholderText: "Enter SQL query..."
                        placeholderTextColor: Theme.textMuted
                        color: Theme.textPrimary
                        selectionColor: Theme.primary
                        selectedTextColor: Theme.textPrimary
                        wrapMode: TextEdit.NoWrap
                        background: Rectangle {
                            color: Theme.background
                            border.color: sqlEditor.activeFocus ? Theme.primary : Theme.border
                            radius: Theme.radiusSmall
                        }
                        onTextChanged: root.sqlText = text
                        Keys.onPressed: function(event) {
                            if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Enter) {
                                root.executeSql()
                                event.accepted = true
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Example: SELECT * FROM data LIMIT 100"
                            color: Theme.textMuted
                            font.pixelSize: 10
                        }
                        Item { Layout.fillWidth: true }
                        AppButton {
                            text: "Use Example"
                            onClicked: root.useExampleSql()
                        }
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
