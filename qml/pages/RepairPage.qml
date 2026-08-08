import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"
import "../theme"

Item {
    id: root
    property string currentFile: ""
    property int selectedIssue: -1
    property var activeIssueData: null

    ListModel { id: issuesModel }
    
    function urlToPath(urlStr) {
        var s = urlStr.toString();
        if (s.indexOf("file:///") === 0) {
            s = s.substring(8);
            if (Qt.platform.os === "windows" && s.charAt(0) === '/' && s.charAt(2) === ':') { s = s.substring(1); }
        }
        return s;
    }

    FileDialog {
        id: fileDialog
        title: "Select CSV for Repair"
        nameFilters: ["CSV Data (*.csv)"]
        onAccepted: {
            currentFile = urlToPath(selectedFile)
            if (typeof backend !== "undefined" && backend.repair) { backend.repair.inspect_repair(currentFile) }
        }
    }

    FileDialog {
        id: saveDialog
        title: "Export Repaired CSV"
        fileMode: FileDialog.SaveFile
        nameFilters: ["CSV Data (*.csv)"]
        onAccepted: {
            if (typeof backend !== "undefined" && backend.repair) { backend.repair.repair(currentFile, urlToPath(selectedFile)) }
        }
    }

    Connections {
        target: typeof backend !== "undefined" ? backend.repair : null
        ignoreUnknownSignals: true

        function onRepairReady(payload) {
            try {
                var data = JSON.parse(payload)
                issuesModel.clear()
                var issuesList = data.issues || []
                for (var i = 0; i < issuesList.length; i++) {
                    var issue = issuesList[i]
                    issuesModel.append({
                        issueIndex: i, // Assuming ordered lists since index not guaranteed
                        rowNum: String(issue.row !== undefined ? issue.row : "N/A"),
                        issueType: String(issue.type || "Unknown"),
                        issueMsg: String(issue.message || "Structural Issue")
                    })
                }
                
                if (selectedIssue >= 0 && selectedIssue < issuesModel.count) {
                    activeIssueData = { index: selectedIssue, type: issuesModel.get(selectedIssue).issueType, message: issuesModel.get(selectedIssue).issueMsg }
                } else {
                    activeIssueData = null
                }
            } catch (e) { }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingXLarge
        spacing: Theme.spacingLarge

        PageTitle {
            title: "Record Repair"
            subtitle: "Fix structural CSV issues, join shifted rows, and safely map unknown columns."
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true; spacing: Theme.spacingMedium
            TextField {
                Layout.fillWidth: true
                readOnly: true
                text: root.currentFile
                placeholderText: "Select file to inspect..."
                color: Theme.textPrimary
                background: Rectangle { color: Theme.background; border.color: Theme.border; radius: Theme.radiusMedium }
            }
            AppButton { text: "Browse"; onClicked: fileDialog.open() }
            PrimaryButton { 
                text: "Export Repaired"
                enabled: root.currentFile !== "" && issuesModel.count > 0
                onClicked: saveDialog.open()
            }
        }

        SplitView {
            Layout.fillWidth: true; Layout.fillHeight: true; orientation: Qt.Horizontal

            Card {
                SplitView.minimumWidth: 280; SplitView.preferredWidth: 350; SplitView.fillHeight: true
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: Theme.spacingMedium; spacing: Theme.spacingSmall
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Detected Issues (" + issuesModel.count + ")"; color: Theme.textPrimary; font.bold: true; Layout.fillWidth: true }
                        AppButton { 
                            text: "Undo Action"
                            enabled: typeof backend !== "undefined" && backend.repair
                            onClicked: backend.repair.undo_repair_action()
                        }
                    }
                    ListView {
                        id: issuesListView
                        Layout.fillWidth: true; Layout.fillHeight: true; model: issuesModel; clip: true; spacing: 2
                        delegate: Rectangle {
                            required property int index
                            required property string rowNum
                            required property string issueType
                            required property string issueMsg

                            width: issuesListView.width; height: 60
                            color: selectedIssue === index ? Theme.surfaceHover : Theme.surface
                            border.color: selectedIssue === index ? Theme.primary : Theme.border
                            border.width: 1; radius: Theme.radiusSmall
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    selectedIssue = index
                                    activeIssueData = { index: index, type: issueType, message: issueMsg }
                                }
                            }
                            RowLayout {
                                anchors.fill: parent; anchors.margins: Theme.spacingSmall
                                Text { text: "Row " + rowNum; font.bold: true; color: Theme.textPrimary; Layout.preferredWidth: 60 }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 2
                                    Text { text: issueType; color: Theme.warning; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                                    Text { text: issueMsg; color: Theme.textSecondary; elide: Text.ElideRight; Layout.fillWidth: true }
                                }
                            }
                        }
                    }
                }
            }

            Card {
                SplitView.fillWidth: true; SplitView.fillHeight: true; visible: selectedIssue >= 0
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: Theme.spacingMedium; spacing: Theme.spacingLarge
                    Text { text: "Issue Resolution"; color: Theme.textPrimary; font.bold: true; font.pixelSize: 18 }
                    
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 60; color: Theme.surfaceHover; border.color: Theme.border; radius: Theme.radiusMedium
                        Text {
                            anchors.fill: parent; anchors.margins: Theme.spacingMedium
                            text: activeIssueData ? activeIssueData.message : ""
                            color: Theme.warning; wrapMode: Text.WordWrap; verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Flow {
                        Layout.fillWidth: true; spacing: Theme.spacingMedium
                        AppButton { text: "Join Shifted Rows"; onClicked: { if(backend.repair && activeIssueData) backend.repair.join_repair_rows(activeIssueData.index) } }
                        AppButton { text: "Keep Issue As-Is"; onClicked: { if(backend.repair && activeIssueData) backend.repair.keep_repair_issue(activeIssueData.index) } }
                        AppButton { text: "Keep Unresolved"; onClicked: { if(backend.repair && activeIssueData) backend.repair.keep_repair_unresolved(activeIssueData.index, 0) } }
                        AppButton { text: "Delete Record"; onClicked: { if(backend.repair && activeIssueData) backend.repair.delete_repair_record(activeIssueData.index) } }
                        AppButton { text: "Create Record"; onClicked: { if(backend.repair && activeIssueData) backend.repair.create_repair_record(activeIssueData.index, "{}") } }
                    }

                    Item { Layout.fillHeight: true } 
                }
            }
        }
    }
}
