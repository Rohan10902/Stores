import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"
import "../theme"

Item {
    id: root

    property string currentFile: ""
    property var tableHeaders: []
    property var tableRows: []
    property int valCount: 0
    property bool exportBlocked: true
    
    ListModel { id: findingsModel }

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
        title: "Load Store Template"
        nameFilters: ["Data (*.csv *.xlsx)"]
        onAccepted: {
            currentFile = urlToPath(selectedFile)
            if (typeof backend !== "undefined" && backend.creator) { backend.creator.load_creator_file(currentFile) }
        }
    }

    FileDialog {
        id: saveDialog
        title: "Export Store Record"
        fileMode: FileDialog.SaveFile
        nameFilters: ["CSV Data (*.csv)"]
        onAccepted: {
            if (typeof backend !== "undefined" && backend.creator) {
                backend.creator.export_creator_file(JSON.stringify(tableRows), urlToPath(selectedFile))
            }
        }
    }

    Connections {
        target: typeof backend !== "undefined" ? backend.creator : null
        ignoreUnknownSignals: true

        function onCreatorLoaded(payloadStr) {
            try {
                var d = JSON.parse(payloadStr)
                tableHeaders = d.headers || []
                tableRows = d.rows || []
                findingsModel.clear()
                exportBlocked = true
                valCount = 0
            } catch(e) {}
        }

        function onCreatorReady(payloadStr) {
            try {
                var d = JSON.parse(payloadStr)
                valCount = d.count || 0
                var f = d.findings || []
                findingsModel.clear()
                var hasError = false
                for(var i=0; i<f.length; i++) {
                    findingsModel.append({ msg: String(f[i].message || ""), sev: String(f[i].severity || "INFO") })
                    if(f[i].severity === "ERROR") hasError = true;
                }
                exportBlocked = hasError || (valCount === 0)
            } catch(e) {}
        }

        function onCreatorExported() {
            // Unused manually in QML, assumed python fires global notifySignal instead.
        }
    }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: Theme.spacingXLarge; spacing: Theme.spacingLarge

        PageTitle { title: "Create Store Record"; subtitle: "Enter, validate, and export new store records."; Layout.fillWidth: true }

        Card {
            Layout.fillWidth: true; Layout.preferredHeight: 90
            RowLayout {
                anchors.fill: parent; anchors.margins: Theme.spacingMedium; spacing: Theme.spacingMedium
                AppButton { text: "Load Template"; onClicked: fileDialog.open() }
                Item { Layout.fillWidth: true }
                AppButton { 
                    text: "Validate Data"
                    enabled: tableRows.length > 0
                    onClicked: {
                        if (typeof backend !== "undefined" && backend.creator) { backend.creator.validate_creator(JSON.stringify(tableRows)) }
                    }
                }
                PrimaryButton { 
                    text: "Export Store"
                    enabled: !exportBlocked && tableRows.length > 0
                    onClicked: saveDialog.open()
                }
            }
        }

        SplitView {
            Layout.fillWidth: true; Layout.fillHeight: true; orientation: Qt.Vertical

            Card {
                SplitView.minimumHeight: 200; SplitView.fillHeight: true
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: Theme.spacingMedium; spacing: Theme.spacingSmall
                    Text { text: "Data Entry"; color: Theme.textPrimary; font.bold: true }

                    ScrollView {
                        Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                        ListView {
                            width: parent.width; model: root.tableRows.length
                            delegate: RowLayout {
                                required property int index
                                property int rowIndex: index
                                property var rowData: root.tableRows[index]
                                spacing: 2
                                Repeater {
                                    model: root.tableHeaders.length
                                    delegate: TextField {
                                        required property int index
                                        width: 160; height: 35
                                        text: rowData[index] !== undefined ? String(rowData[index]) : ""
                                        color: Theme.textPrimary; placeholderText: root.tableHeaders[index]
                                        background: Rectangle { color: Theme.background; border.color: Theme.border }
                                        onTextChanged: { root.tableRows[rowIndex][index] = text }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Card {
                SplitView.minimumHeight: 120; SplitView.preferredHeight: 150
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: Theme.spacingMedium; spacing: Theme.spacingSmall
                    Text { text: "Validation Feedback"; color: Theme.textPrimary; font.bold: true }
                    ListView {
                        Layout.fillWidth: true; Layout.fillHeight: true; model: findingsModel; clip: true; spacing: 2
                        delegate: Rectangle {
                            required property string msg
                            required property string sev
                            width: ListView.view.width; height: 32
                            color: sev === "ERROR" ? "#421820" : (sev === "WARNING" ? "#433614" : Theme.surfaceHover)
                            border.color: Theme.border
                            Text {
                                anchors.fill: parent; anchors.margins: 6
                                text: msg; color: Theme.textPrimary; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }
}
