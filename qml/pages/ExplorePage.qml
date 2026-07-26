import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"

Item {
    id: page
    property string src: ""
    property var cols: []
    property var resultCols: []
    property var suggestedQueries: []
    ListModel { id: tableRows }

    function qident(s) { return '"' + String(s).replace(/"/g, '""') + '"' }
    function refreshSuggestions() {
        var q = ["SELECT * FROM data LIMIT 100", "SELECT COUNT(*) AS total_records FROM data"]
        if (cols.length > 0) q.push("SELECT " + qident(cols[0]) + ", COUNT(*) AS count FROM data GROUP BY " + qident(cols[0]) + " ORDER BY count DESC LIMIT 50")
        if (cols.length > 1) q.push("SELECT * FROM data WHERE " + qident(cols[1]) + " IS NULL LIMIT 100")
        suggestedQueries = q
        suggestion.model = suggestedQueries
    }
    function rowColor(rowIndex) {
        if ((rowIndex % 2) === 1) return "#0d1b2e"
        return "#0b1829"
    }
    function displayCell(value) {
        if (value === null || value === undefined) return ""
        return String(value)
    }

    FileDialog {
        id: fd
        nameFilters: ["Data (*.csv *.xlsx *.xls *.xlsm *.txt *.tsv *.json *.xml)"]
        onAccepted: {
            src = selectedFile.toString()
            backend.loadData(src)
        }
    }

    Connections {
        target: backend
        function onHealthReady(p) {
            var d = JSON.parse(p)
            cols = d.columnNames
            searchCol.model = ["All columns"].concat(cols)
            refreshSuggestions()
        }
        function onTableReady(p) {
            var d = JSON.parse(p)
            resultCols = d.columns
            tableRows.clear()
            for (var i = 0; i < d.rows.length; i++) {
                tableRows.append({rowJson: JSON.stringify(d.rows[i])})
            }
            info.text = d.total + " row(s) — " + d.displayed + " displayed"
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 22
        spacing: 10

        PageTitle { text: "Explore & Analyze" }

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: src || "No dataset loaded"
                color: "#94a3b8"
                Layout.fillWidth: true
                elide: Text.ElideMiddle
            }
            PrimaryButton {
                text: "Load Dataset"
                onClicked: fd.open()
            }
        }

        Card {
            Layout.fillWidth: true
            implicitHeight: 245
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8
                RowLayout {
                    TextField {
                        id: search
                        placeholderText: "Search records..."
                        Layout.fillWidth: true
                        Keys.onReturnPressed: backend.search(search.text, searchCol.currentIndex <= 0 ? "" : searchCol.currentText)
                    }
                    ComboBox { id: searchCol; Layout.preferredWidth: 240 }
                    PrimaryButton {
                        text: "Search"
                        enabled: src !== ""
                        onClicked: backend.search(search.text, searchCol.currentIndex <= 0 ? "" : searchCol.currentText)
                    }
                }
                RowLayout {
                    Text { text: "Suggested query"; color: "#94a3b8"; font.bold: true }
                    ComboBox {
                        id: suggestion
                        Layout.fillWidth: true
                        onActivated: sql.text = currentText
                    }
                    AppButton {
                        text: "Use Suggestion"
                        enabled: suggestion.currentText !== ""
                        onClicked: sql.text = suggestion.currentText
                    }
                    AppButton { text: "Clear"; onClicked: sql.clear() }
                }
                TextArea {
                    id: sql
                    text: "SELECT * FROM data LIMIT 100"
                    color: "#f8fafc"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    wrapMode: TextEdit.NoWrap
                    selectByMouse: true
                    font.family: "Consolas"
                    Keys.onPressed: function(event) {
                        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Return) {
                            backend.sql(sql.text)
                            event.accepted = true
                        }
                    }
                    background: Rectangle {
                        color: "#071321"
                        border.width: 1
                        border.color: "#263850"
                        radius: 6
                    }
                }
                RowLayout {
                    Text {
                        text: "Read-only analysis workspace • Ctrl+Enter runs query"
                        color: "#60a5fa"
                        Layout.fillWidth: true
                    }
                    PrimaryButton {
                        text: "Run SQL"
                        enabled: src !== "" && sql.text.trim() !== ""
                        onClicked: backend.sql(sql.text)
                    }
                }
            }
        }

        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 9
                RowLayout {
                    Text { text: "Result Table"; color: "#f8fafc"; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { id: info; text: "0 rows"; color: "#94a3b8" }
                }
                Flickable {
                    id: flick
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: Math.max(width, resultCols.length * 180)
                    contentHeight: tableColumn.height
                    Column {
                        id: tableColumn
                        width: flick.contentWidth
                        Row {
                            height: 34
                            Repeater {
                                model: resultCols
                                delegate: Rectangle {
                                    required property var modelData
                                    width: 180
                                    height: 34
                                    color: "#132238"
                                    Text {
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        text: String(modelData)
                                        color: "#94a3b8"
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                        Repeater {
                            model: tableRows
                            delegate: Rectangle {
                                id: resultRow
                                required property int index
                                required property string rowJson
                                property var cells: JSON.parse(rowJson)
                                property int rowIndex: index
                                width: tableColumn.width
                                height: 32
                                color: page.rowColor(rowIndex)
                                Row {
                                    anchors.fill: parent
                                    Repeater {
                                        model: resultRow.cells
                                        delegate: Rectangle {
                                            required property var modelData
                                            width: 180
                                            height: 32
                                            color: "transparent"
                                            border.width: 1
                                            border.color: "#17283d"
                                            Text {
                                                anchors.fill: parent
                                                anchors.margins: 5
                                                text: page.displayCell(modelData)
                                                color: "#f8fafc"
                                                font.pixelSize: 10
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    ScrollBar.vertical: ScrollBar {}
                    ScrollBar.horizontal: ScrollBar {}
                }
            }
        }
    }
}
