import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"
import "../theme"

Item {
    id: root
    property string currentFile: ""
    property var tCols: []
    property var tRows: []
    property int tTotal: 0
    property int tDisplayed: 0
    property bool tTruncated: false

    function urlToPath(urlStr) {
        var path = urlStr.toString();
        path = path.replace(/^(file:\/{2,3})/, "");
        if (Qt.platform.os !== "windows" && !path.startsWith("/")) {
            path = "/" + path;
        }
        return decodeURIComponent(path);
    }

    FileDialog {
        id: fileDialog
        title: "Load Dataset for Exploration"
        nameFilters: ["Data (*.csv *.xlsx *.db *.sqlite)"]
        onAccepted: {
            currentFile = urlToPath(selectedFile)
            if (typeof backend !== "undefined" && backend.health) { backend.health.load_data(currentFile) }
        }
    }

    Connections {
        target: typeof backend !== "undefined" ? backend.health : null
        ignoreUnknownSignals: true

        function onTableReady(payload) {
            try {
                var d = JSON.parse(payload)
                tCols = d.columns || []
                tRows = d.rows || []
                tTotal = d.total || 0
                tDisplayed = d.displayed !== undefined ? d.displayed : tRows.length
                tTruncated = !!d.truncated
            } catch(e) {}
        }
    }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: Theme.spacingXLarge; spacing: Theme.spacingLarge

        PageTitle { title: "Explore Data"; subtitle: "Query, search, and visually inspect dataset contents."; Layout.fillWidth: true }

        Card {
            Layout.fillWidth: true; Layout.preferredHeight: 120
            ColumnLayout {
                anchors.fill: parent; anchors.margins: Theme.spacingMedium; spacing: Theme.spacingSmall
                RowLayout {
                    Layout.fillWidth: true; spacing: Theme.spacingMedium
                    AppButton { text: "Load Data"; onClicked: fileDialog.open() }
                    Text { text: currentFile !== "" ? currentFile : "No file loaded"; color: Theme.textSecondary; Layout.fillWidth: true; elide: Text.ElideRight }
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: Theme.spacingMedium
                    TextField {
                        id: searchInput
                        Layout.fillWidth: true; placeholderText: "Quick search / SQL Query..."; color: Theme.textPrimary
                        background: Rectangle { color: Theme.background; border.color: Theme.border; radius: Theme.radiusMedium }
                    }
                    ComboBox {
                        id: colCombo
                        Layout.preferredWidth: 150; model: ["All Columns"].concat(tCols)
                        background: Rectangle { color: Theme.background; border.color: Theme.border; radius: Theme.radiusMedium }
                        contentItem: Text { text: parent.currentIndex >= 0 ? parent.currentText : ""; color: Theme.textPrimary; verticalAlignment: Text.AlignVCenter; leftPadding: 8 }
                    }
                    AppButton { 
                        text: "Search"
                        onClicked: { if (backend && backend.health) backend.health.search(searchInput.text, colCombo.currentText === "All Columns" ? "" : colCombo.currentText) }
                    }
                    PrimaryButton { 
                        text: "Run SQL"
                        onClicked: { if (backend && backend.health) backend.health.sql(searchInput.text) }
                    }
                }
            }
        }

        Card {
            Layout.fillWidth: true; Layout.fillHeight: true
            ColumnLayout {
                anchors.fill: parent; anchors.margins: Theme.spacingMedium; spacing: Theme.spacingSmall
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Data Table"; color: Theme.textPrimary; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { 
                        text: "Showing " + tDisplayed + " of " + tTotal + (tTruncated ? " (Truncated)" : "")
                        color: tTruncated ? Theme.warning : Theme.textSecondary; font.pixelSize: 11
                    }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 30; color: Theme.surfaceHover; border.color: Theme.border
                    RowLayout {
                        anchors.fill: parent; spacing: 2
                        Repeater {
                            model: tCols
                            delegate: Text { text: String(modelData); color: Theme.textSecondary; font.bold: true; Layout.preferredWidth: 150; elide: Text.ElideRight; leftPadding: 4 }
                        }
                    }
                }
                ScrollView {
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                    ListView {
                        width: parent.width; model: root.tRows.length
                        delegate: RowLayout {
                            required property int index
                            property var rowData: root.tRows[index]
                            spacing: 2
                            Repeater {
                                model: root.tCols.length
                                delegate: Rectangle {
                                    required property int index
                                    width: 150; height: 30; color: Theme.background; border.color: Theme.border; border.width: 1
                                    Text { 
                                        anchors.fill: parent; anchors.margins: 4
                                        text: rowData[index] !== undefined ? String(rowData[index]) : ""
                                        color: Theme.textPrimary; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
