import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"
import "../theme"

Item {
    id: root
    property string currentFile: ""
    property int totalRecords: 0
    property int attentionCount: 0
    property var previewCols: []
    property var previewRows: []
    
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
        title: "Select File to Review"
        nameFilters: ["Data (*.csv *.xlsx)"]
        onAccepted: {
            currentFile = urlToPath(selectedFile)
            if (typeof backend !== "undefined" && backend.review) { backend.review.review_single_file(currentFile) }
        }
    }

    FileDialog {
        id: saveDialog
        title: "Export Reviewed CSV"
        fileMode: FileDialog.SaveFile
        nameFilters: ["CSV Data (*.csv)"]
        onAccepted: {
            if (typeof backend !== "undefined" && backend.review) { backend.review.export_single_review(currentFile, urlToPath(selectedFile)) }
        }
    }

    Connections {
        target: typeof backend !== "undefined" ? backend.review : null
        ignoreUnknownSignals: true

        function onSingleReviewReady(payload) {
            try {
                var d = JSON.parse(payload)
                totalRecords = d.totalRecords || 0
                attentionCount = d.attentionCount || 0
                previewCols = d.previewColumns || []
                previewRows = d.previewRows || []
                
                findingsModel.clear()
                var findingsList = d.findings || []
                for (var i = 0; i < findingsList.length; i++) {
                    findingsModel.append({ msg: String(findingsList[i].message || ""), sev: String(findingsList[i].severity || "INFO") })
                }
            } catch (e) { }
        }
    }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: Theme.spacingXLarge; spacing: Theme.spacingLarge

        PageTitle { title: "Single File Review"; subtitle: "Analyze and export a single dataset for data quality review."; Layout.fillWidth: true }

        Card {
            Layout.fillWidth: true; Layout.preferredHeight: 90
            RowLayout {
                anchors.fill: parent; anchors.margins: Theme.spacingMedium; spacing: Theme.spacingMedium
                TextField {
                    Layout.fillWidth: true; readOnly: true; text: root.currentFile
                    placeholderText: "Select file..."; color: Theme.textPrimary
                    background: Rectangle { color: Theme.background; border.color: Theme.border; radius: Theme.radiusMedium }
                }
                AppButton { text: "Browse"; onClicked: fileDialog.open() }
                PrimaryButton { 
                    text: "Export Reviewed"
                    enabled: root.currentFile !== "" && totalRecords > 0
                    onClicked: saveDialog.open()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true; spacing: Theme.spacingMedium
            Card {
                Layout.fillWidth: true; Layout.preferredHeight: 80
                ColumnLayout {
                    anchors.centerIn: parent
                    Text { text: root.totalRecords; color: Theme.primary; font.pixelSize: 24; font.bold: true; Layout.alignment: Qt.AlignHCenter }
                    Text { text: "TOTAL RECORDS"; color: Theme.textSecondary; font.pixelSize: 10; font.bold: true; Layout.alignment: Qt.AlignHCenter }
                }
            }
            Card {
                Layout.fillWidth: true; Layout.preferredHeight: 80
                ColumnLayout {
                    anchors.centerIn: parent
                    Text { text: root.attentionCount; color: root.attentionCount > 0 ? Theme.warning : Theme.success; font.pixelSize: 24; font.bold: true; Layout.alignment: Qt.AlignHCenter }
                    Text { text: "ATTENTION FINDINGS"; color: Theme.textSecondary; font.pixelSize: 10; font.bold: true; Layout.alignment: Qt.AlignHCenter }
                }
            }
        }

        SplitView {
            Layout.fillWidth: true; Layout.fillHeight: true; orientation: Qt.Vertical

            Card {
                SplitView.minimumHeight: 150; SplitView.fillHeight: true
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: Theme.spacingMedium; spacing: Theme.spacingSmall
                    Text { text: "Data Preview"; color: Theme.textPrimary; font.bold: true }
                    ScrollView {
                        Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                        ListView {
                            id: previewList
                            width: parent.width; model: root.previewRows.length
                            delegate: RowLayout {
                                required property int index
                                property var rowData: root.previewRows[index]
                                spacing: Theme.spacingSmall
                                Repeater {
                                    model: root.previewCols.length
                                    delegate: Rectangle {
                                        required property int index
                                        property string colName: root.previewCols[index]
                                        width: 150; height: 30
                                        color: index % 2 === 0 ? Theme.background : Theme.surfaceHover
                                        border.color: Theme.border
                                        Text { 
                                            anchors.fill: parent; anchors.margins: 4
                                            text: rowData[colName] !== undefined ? String(rowData[colName]) : (rowData[index] !== undefined ? String(rowData[index]) : "")
                                            color: Theme.textPrimary; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Card {
                SplitView.minimumHeight: 120; SplitView.preferredHeight: 180
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: Theme.spacingMedium; spacing: Theme.spacingSmall
                    Text { text: "Quality Findings"; color: Theme.textPrimary; font.bold: true }
                    ListView {
                        Layout.fillWidth: true; Layout.fillHeight: true; model: findingsModel; clip: true; spacing: 2
                        delegate: Rectangle {
                            required property string msg
                            required property string sev
                            width: ListView.view.width; height: 32
                            color: sev === "ERROR" ? "#421820" : (sev === "WARNING" ? "#433614" : Theme.surfaceHover)
                            border.color: Theme.border
                            Text { anchors.fill: parent; anchors.margins: 6; text: msg; color: Theme.textPrimary; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                        }
                    }
                }
            }
        }
    }
}
