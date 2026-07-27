import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"

Item {
    property string src: ""
    property var cols: []
    property var resultCols: []
    property var numericCols: []
    property var textCols: []
    ListModel { id: tableRows }
    ListModel { id: suggestions }

    function qi(name) { return '"' + String(name).replace(/"/g, '""') + '"' }
    function addSuggestion(title, description, query) { suggestions.append({title:title, description:description, query:query}) }
    function buildSuggestions(profile) {
        suggestions.clear(); numericCols=[]; textCols=[]
        var columns = profile.columns || []
        for (var i=0;i<columns.length;i++) {
            var c=columns[i]
            if (String(c.type).toLowerCase()==="numeric") numericCols.push(c.column)
            else textCols.push(c.column)
        }
        addSuggestion("Show first 100 records", "Safe starting view of the dataset", "SELECT * FROM data LIMIT 100")
        addSuggestion("Find exact duplicate rows", "Shows duplicated records so they can be reviewed", "SELECT * FROM data WHERE rowid IN (SELECT MIN(rowid) FROM data GROUP BY " + cols.map(qi).join(", ") + " HAVING COUNT(*) > 1) LIMIT 100")
        if (cols.length>0) {
            var missing=[]; for (var m=0;m<cols.length;m++) missing.push(qi(cols[m])+" IS NULL OR TRIM(CAST("+qi(cols[m])+" AS VARCHAR)) = ''")
            addSuggestion("Show rows with missing values", "Find records with at least one blank or null field", "SELECT * FROM data WHERE "+missing.join(" OR ")+" LIMIT 100")
        }
        for (var t=0;t<textCols.length && t<4;t++) {
            var tc=textCols[t]
            addSuggestion("Count by "+tc, "Distribution of records across "+tc, "SELECT "+qi(tc)+", COUNT(*) AS record_count FROM data GROUP BY "+qi(tc)+" ORDER BY record_count DESC")
        }
        for (var n=0;n<numericCols.length && n<4;n++) {
            var nc=numericCols[n]
            addSuggestion("Summary of "+nc, "Count, sum, average, minimum and maximum", "SELECT COUNT("+qi(nc)+") AS count_value, SUM("+qi(nc)+") AS total, AVG("+qi(nc)+") AS average, MIN("+qi(nc)+") AS minimum, MAX("+qi(nc)+") AS maximum FROM data")
            addSuggestion("Top 10 by "+nc, "Highest values in "+nc, "SELECT * FROM data WHERE "+qi(nc)+" IS NOT NULL ORDER BY "+qi(nc)+" DESC LIMIT 10")
        }
        if (textCols.length>0 && numericCols.length>0) {
            addSuggestion("Total "+numericCols[0]+" by "+textCols[0], "Aggregate a numeric measure by category", "SELECT "+qi(textCols[0])+", SUM("+qi(numericCols[0])+") AS total FROM data GROUP BY "+qi(textCols[0])+" ORDER BY total DESC")
            addSuggestion("Average "+numericCols[0]+" by "+textCols[0], "Compare average values between groups", "SELECT "+qi(textCols[0])+", AVG("+qi(numericCols[0])+") AS average FROM data GROUP BY "+qi(textCols[0])+" ORDER BY average DESC")
        }
    }

    FileDialog {
        id: fd
        nameFilters: ["Data (*.csv *.xlsx *.xls *.xlsm *.txt *.tsv *.json *.xml)"]
        onAccepted: { src = selectedFile.toString(); backend.loadData(src) }
    }

    Connections {
        target: backend
        function onHealthReady(p) {
            var d = JSON.parse(p)
            cols = d.columnNames
            searchCol.model = ["All columns"].concat(cols)
            buildSuggestions(d)
        }
        function onTableReady(p) {
            var d = JSON.parse(p)
            resultCols = d.columns
            tableRows.clear()
            for (var i=0; i<d.rows.length; i++) tableRows.append({rowJson: JSON.stringify(d.rows[i])})
            info.text = d.total + " row(s) — " + d.displayed + " displayed"
        }
    }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 22; spacing: 10
        PageTitle { text: "Explore & Analyze" }

        RowLayout {
            Layout.fillWidth: true
            Text { text: src || "No dataset loaded"; color: "#94a3b8"; Layout.fillWidth: true; elide: Text.ElideMiddle }
            PrimaryButton { text: "Load Dataset"; onClicked: fd.open() }
        }

        Card {
            Layout.fillWidth: true; implicitHeight: suggestions.count>0 ? 280 : 150
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 10; spacing: 8
                RowLayout {
                    TextField { id: search; placeholderText: "Search records..."; Layout.fillWidth: true }
                    ComboBox { id: searchCol; Layout.preferredWidth: 240 }
                    PrimaryButton { text: "Search"; enabled: src!==""; onClicked: backend.search(search.text, searchCol.currentIndex<=0 ? "" : searchCol.currentText) }
                }
                RowLayout {
                    TextArea {
                        id: sql; text: "SELECT * FROM data LIMIT 100"
                        color: "#f8fafc"; Layout.fillWidth: true; Layout.preferredHeight: 65
                        background: Rectangle { color: "#071321"; border.width: 1; border.color: "#263850"; radius: 6 }
                    }
                    PrimaryButton { text: "Run SQL"; enabled: src!==""; onClicked: backend.sql(sql.text) }
                }
                RowLayout {
                    visible: suggestions.count>0; Layout.fillWidth: true
                    Text { text: "Suggested Queries"; color: "#f8fafc"; font.bold: true }
                    Text { text: "Generated from the columns and data types in the loaded dataset. Click one to preview the SQL."; color: "#94a3b8"; Layout.fillWidth: true }
                    AppButton { text: "Run Selected"; enabled: suggestionList.currentIndex>=0; onClicked: { if(suggestionList.currentIndex>=0){sql.text=suggestions.get(suggestionList.currentIndex).query;backend.sql(sql.text)} } }
                }
                ListView {
                    id: suggestionList; visible: suggestions.count>0; Layout.fillWidth: true; Layout.preferredHeight: 90
                    orientation: ListView.Horizontal; spacing: 8; clip: true; model: suggestions
                    delegate: Rectangle {
                        required property int index; required property string title; required property string description; required property string query
                        width: 245; height: 78; radius: 6; color: suggestionList.currentIndex===index ? "#17375f" : "#0d1b2e"; border.color: "#29415f"
                        MouseArea { anchors.fill: parent; onClicked: { suggestionList.currentIndex=index; sql.text=query } }
                        Column { anchors.fill: parent; anchors.margins: 8; spacing: 4
                            Text { width: parent.width; text: title; color: "#bfdbfe"; font.bold: true; elide: Text.ElideRight }
                            Text { width: parent.width; text: description; color: "#94a3b8"; font.pixelSize: 10; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
                        }
                    }
                    ScrollBar.horizontal: ScrollBar {}
                }
            }
        }

        Card {
            Layout.fillWidth: true; Layout.fillHeight: true
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 9
                RowLayout {
                    Text { text: "Result Table"; color: "#f8fafc"; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { id: info; text: "0 rows"; color: "#94a3b8" }
                }
                Flickable {
                    id: flick; Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                    contentWidth: Math.max(width, resultCols.length * 180); contentHeight: tableColumn.height
                    Column {
                        id: tableColumn; width: flick.contentWidth
                        Row { height: 34
                            Repeater { model: resultCols; delegate: Rectangle { required property var modelData; width: 180; height: 34; color: "#132238"; Text { anchors.fill: parent; anchors.margins: 6; text: String(modelData); color: "#94a3b8"; font.bold: true; elide: Text.ElideRight } } }
                        }
                        Repeater {
                            model: tableRows
                            delegate: Rectangle {
                                required property int index; required property string rowJson; property var cells: JSON.parse(rowJson)
                                width: tableColumn.width; height: 32; color: index%2 ? "#0d1b2e" : "#0b1829"
                                Row { anchors.fill: parent
                                    Repeater { model: cells; delegate: Rectangle { required property var modelData; width: 180; height: 32; color: "transparent"; border.width: 1; border.color: "#17283d"; Text { anchors.fill: parent; anchors.margins: 5; text: modelData===null ? "" : String(modelData); color: "#f8fafc"; font.pixelSize: 10; elide: Text.ElideRight } } }
                                }
                            }
                        }
                    }
                    ScrollBar.vertical: ScrollBar {}; ScrollBar.horizontal: ScrollBar {}
                }
            }
        }
    }
}