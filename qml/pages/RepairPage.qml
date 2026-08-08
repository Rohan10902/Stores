// qml/pages/RepairPage.qml
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
            if (typeof backend !== "undefined" && backend.repair) {
                backend.repair.inspect_repair(currentFile)
            }
        }
    }

    FileDialog {
        id: saveDialog
        title: "Export Repaired CSV"
        fileMode: FileDialog.SaveFile
        nameFilters: ["CSV Data (*.csv)"]
        onAccepted: {
            if (typeof backend !== "undefined" && backend.repair) {
                backend.repair.repair(currentFile, urlToPath(selectedFile))
            }
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
                        issueIndex: issue.index !== undefined ? issue.index : i,
                        rowNumber: String(issue.row || "N/A"),
                        description: String(issue.description || "Structural Issue"),
                        resolved: !!issue.resolved,
                        rawJson: JSON.stringify(issue)
                    })
                }
                
                if (selectedIssue >= 0 && selectedIssue < issuesModel.count) {
                    activeIssueData = JSON.parse(issuesModel.get(selectedIssue).rawJson)
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
            Layout.fillWidth: true
            spacing: Theme.spacingMedium

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
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: Qt.Horizontal

            Card {
                SplitView.minimumWidth: 280
                SplitView.preferredWidth: 350
                SplitView.fillHeight: true
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMedium
                    spacing: Theme.spacingSmall

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
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: issuesModel
                        clip: true
                        spacing: 2

                        delegate: Rectangle {
                            required property int index
                            required property string rowNumber
                            required property string description
                            required property bool resolved

                            width: issuesListView.width
                            height: 60
                            color: selectedIssue === index ? Theme.surfaceHover : Theme.surface
                            border.color: resolved ? Theme.success : (selectedIssue === index ? Theme.primary : Theme.border)
                            border.width: 1
                            radius: Theme.radiusSmall

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    selectedIssue = index
                                    activeIssueData = JSON.parse(issuesModel.get(index).rawJson)
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingSmall
                                Text { text: "Row " + rowNumber; font.bold: true; color: Theme.textPrimary; Layout.preferredWidth: 60 }
                                Text { text: description; color: Theme.textSecondary; Layout.fillWidth: true; elide: Text.ElideRight; wrapMode: Text.WordWrap }
                                Text { text: resolved ? "✓" : "!"; color: resolved ? Theme.success : Theme.warning; font.bold: true }
                            }
                        }
                    }
                }
            }

            Card {
                SplitView.fillWidth: true
                SplitView.fillHeight: true
                visible: selectedIssue >= 0

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMedium
                    spacing: Theme.spacingLarge

                    Text { text: "Issue Resolution"; color: Theme.textPrimary; font.bold: true; font.pixelSize: 18 }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 60
                        color: Theme.surfaceHover
                        border.color: Theme.border
                        radius: Theme.radiusMedium
                        
                        Text {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingMedium
                            text: activeIssueData ? String(activeIssueData.description) : ""
                            color: Theme.warning
                            wrapMode: Text.WordWrap
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    // Resolution Action Tools
                    Flow {
                        Layout.fillWidth: true
                        spacing: Theme.spacingMedium

                        AppButton {
                            text: "Join Shifted Rows"
                            onClicked: { if(backend.repair && activeIssueData) backend.repair.join_repair_rows(activeIssueData.index) }
                        }
                        AppButton {
                            text: "Keep Issue As-Is"
                            onClicked: { if(backend.repair && activeIssueData) backend.repair.keep_repair_issue(activeIssueData.index) }
                        }
                        AppButton {
                            text: "Keep Unresolved"
                            onClicked: { if(backend.repair && activeIssueData) backend.repair.keep_repair_unresolved(activeIssueData.index, 0) } // Default col 0
                        }
                        AppButton {
                            text: "Delete Record"
                            onClicked: { if(backend.repair && activeIssueData) backend.repair.delete_repair_record(activeIssueData.index) }
                        }
                        AppButton {
                            text: "Create Record"
                            onClicked: { if(backend.repair && activeIssueData) backend.repair.create_repair_record(activeIssueData.index, "{}") }
                        }
                    }

                    Text { text: "Data Preview"; color: Theme.textSecondary; font.bold: true }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: Theme.background
                        border.color: Theme.border
                        radius: Theme.radiusMedium
                        
                        ScrollView {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingSmall
                            clip: true
                            Text {
                                text: activeIssueData ? JSON.stringify(activeIssueData.data || {}, null, 2) : "No data to preview."
                                color: Theme.textMuted
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }
        }
    }
}
