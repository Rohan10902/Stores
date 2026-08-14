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
    property string destinationPath: ""
    property int totalRecords: 0
    property int attentionCount: 0
    property var previewColumns: []
    property var previewRows: []
    property var findings: []

    readonly property int columnWidth: 170

    function backendAvailable() {
        return typeof backend !== "undefined" &&
               backend !== null &&
               backend.review !== undefined &&
               backend.review !== null
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

    function reviewFile() {
        if (root.backendAvailable() && root.sourcePath !== "")
            backend.review.review_single_file(root.sourcePath)
    }

    function exportReview() {
        if (root.backendAvailable() &&
                root.sourcePath !== "" &&
                root.destinationPath !== "") {
            backend.review.export_single_review(
                root.sourcePath,
                root.destinationPath
            )
        }
    }

    function cellValue(row, columnIndex) {
        if (row === null || row === undefined)
            return ""
        if (Array.isArray(row)) {
            if (columnIndex >= 0 && columnIndex < row.length &&
                    row[columnIndex] !== null && row[columnIndex] !== undefined)
                return String(row[columnIndex])
            return ""
        }
        if (typeof row === "object") {
            var column = root.previewColumns[columnIndex]
            var value = row[column]
            return value === null || value === undefined ? "" : String(value)
        }
        return ""
    }

    FileDialog {
        id: sourceDialog
        title: "Select File to Review"
        nameFilters: [
            "Data Files (*.csv *.xlsx *.xls *.xlsm *.txt *.tsv)",
            "All Files (*)"
        ]
        onAccepted: {
            root.sourcePath = root.urlToPath(selectedFile)
            root.reviewFile()
        }
    }

    FileDialog {
        id: destinationDialog
        title: "Export Review"
        fileMode: FileDialog.SaveFile
        currentFile: "single_file_review.csv"
        nameFilters: ["CSV Files (*.csv)", "All Files (*)"]
        onAccepted: root.destinationPath = root.urlToPath(selectedFile)
    }

    Connections {
        target: root.backendAvailable() ? backend.review : null
        ignoreUnknownSignals: true

        function onSingleReviewReady(payload) {
            try {
                var data = JSON.parse(String(payload || "{}"))
                root.totalRecords = Number(data.totalRecords || 0)
                root.attentionCount = Number(data.attentionCount || 0)
                root.previewColumns = Array.isArray(data.previewColumns) ? data.previewColumns : []
                root.previewRows = Array.isArray(data.previewRows) ? data.previewRows : []
                root.findings = Array.isArray(data.findings) ? data.findings : []
            } catch (error) {
                root.totalRecords = 0
                root.attentionCount = 1
                root.previewColumns = []
                root.previewRows = []
                root.findings = [{message: String(error), severity: "ERROR"}]
            }
        }
    }

    ScrollView {
        id: pageScroll
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        ColumnLayout {
            id: pageColumn
            width: pageScroll.availableWidth
            spacing: Theme.spacingLarge

            PageTitle {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacingXLarge
                Layout.rightMargin: Theme.spacingXLarge
                Layout.topMargin: Theme.spacingLarge
                title: "Single File Review"
                subtitle: "Inspect a single dataset, identify quality issues, and review a representative preview."
            }

            Card {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacingXLarge
                Layout.rightMargin: Theme.spacingXLarge
                Layout.preferredHeight: 145
                hoverable: false

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMedium
                    spacing: Theme.spacingMedium

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Dataset"; color: Theme.textSecondary; font.bold: true; Layout.preferredWidth: 80 }
                        TextField {
                            Layout.fillWidth: true
                            readOnly: true
                            text: root.sourcePath
                            placeholderText: "Select a dataset to review"
                            color: Theme.textPrimary
                        }
                        AppButton { text: "Browse"; onClicked: sourceDialog.open() }
                        PrimaryButton {
                            text: "Review"
                            enabled: root.sourcePath !== ""
                            onClicked: root.reviewFile()
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Export"; color: Theme.textSecondary; font.bold: true; Layout.preferredWidth: 80 }
                        TextField {
                            Layout.fillWidth: true
                            readOnly: true
                            text: root.destinationPath
                            placeholderText: "Choose destination"
                            color: Theme.textPrimary
                        }
                        AppButton {
                            text: "Browse"
                            enabled: root.sourcePath !== ""
                            onClicked: destinationDialog.open()
                        }
                        PrimaryButton {
                            text: "Export"
                            enabled: root.sourcePath !== "" && root.destinationPath !== ""
                            onClicked: root.exportReview()
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacingXLarge
                Layout.rightMargin: Theme.spacingXLarge
                spacing: Theme.spacingMedium

                Card {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 82
                    Text { anchors.centerIn: parent; text: root.totalRecords + "\nTOTAL RECORDS"; color: Theme.primary; font.bold: true; horizontalAlignment: Text.AlignHCenter }
                }
                Card {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 82
                    Text { anchors.centerIn: parent; text: root.previewColumns.length + "\nCOLUMNS"; color: Theme.info; font.bold: true; horizontalAlignment: Text.AlignHCenter }
                }
                Card {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 82
                    Text { anchors.centerIn: parent; text: root.attentionCount + "\nATTENTION"; color: root.attentionCount > 0 ? Theme.error : Theme.success; font.bold: true; horizontalAlignment: Text.AlignHCenter }
                }
                Card {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 82
                    Text { anchors.centerIn: parent; text: root.findings.length + "\nFINDINGS"; color: root.findings.length > 0 ? Theme.warning : Theme.success; font.bold: true; horizontalAlignment: Text.AlignHCenter }
                }
            }

            Card {
                visible: root.findings.length > 0
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacingXLarge
                Layout.rightMargin: Theme.spacingXLarge
                Layout.preferredHeight: Math.min(230, 70 + root.findings.length * 48)
                hoverable: false

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMedium
                    spacing: Theme.spacingSmall

                    Text { text: "Data Quality Findings"; color: Theme.textPrimary; font.pixelSize: 15; font.bold: true }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: Theme.spacingSmall
                        model: root.findings
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        delegate: Rectangle {
                            required property var modelData
                            width: ListView.view ? ListView.view.width : 0
                            height: 42
                            radius: Theme.radiusMedium
                            color: String(modelData.severity || "").toUpperCase() === "ERROR" ? "#421820" : "#433614"
                            border.color: Theme.border

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingSmall
                                spacing: Theme.spacingSmall
                                Rectangle {
                                    width: 7
                                    height: 7
                                    radius: 4
                                    color: String(modelData.severity || "").toUpperCase() === "ERROR" ? Theme.error : Theme.warning
                                }
                                Text {
                                    text: String(modelData.severity || "WARNING").toUpperCase()
                                    color: String(modelData.severity || "").toUpperCase() === "ERROR" ? Theme.error : Theme.warning
                                    font.bold: true
                                    Layout.preferredWidth: 80
                                }
                                Text {
                                    text: String(modelData.message || "")
                                    color: Theme.textPrimary
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }

            Card {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacingXLarge
                Layout.rightMargin: Theme.spacingXLarge
                Layout.bottomMargin: Theme.spacingXLarge
                Layout.preferredHeight: 610
                hoverable: false

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMedium
                    spacing: Theme.spacingSmall

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Dataset Preview"; color: Theme.textPrimary; font.pixelSize: 15; font.bold: true }
                        Item { Layout.fillWidth: true }
                        Text {
                            visible: root.totalRecords > root.previewRows.length
                            text: "Showing first " + root.previewRows.length + " of " + root.totalRecords + " records"
                            color: Theme.textSecondary
                            font.pixelSize: 11
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.previewColumns.length > 0 ? 40 : 0
                        visible: root.previewColumns.length > 0
                        color: Theme.surfaceHover
                        border.color: Theme.border
                        clip: true

                        Flickable {
                            anchors.fill: parent
                            contentWidth: Math.max(width, root.previewColumns.length * root.columnWidth)
                            contentHeight: height
                            clip: true
                            interactive: false

                            Row {
                                id: headerRow
                                width: Math.max(headerViewport.width, root.previewColumns.length * root.columnWidth)
                                height: 40
                                spacing: 0
                                Repeater {
                                    model: root.previewColumns
                                    delegate: Rectangle {
                                        required property string modelData
                                        width: root.columnWidth
                                        height: 40
                                        color: "transparent"
                                        border.color: Theme.border
                                        Text {
                                            anchors.fill: parent
                                            anchors.leftMargin: Theme.spacingSmall
                                            anchors.rightMargin: Theme.spacingSmall
                                            text: modelData
                                            color: Theme.textSecondary
                                            font.bold: true
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }
                            }
                            property alias headerViewport: headerRow
                        }
                    }

                    Flickable {
                        id: previewFlick
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: Math.max(width, root.previewColumns.length * root.columnWidth)
                        contentHeight: previewTable.height
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }

                        Column {
                            id: previewTable
                            width: Math.max(previewFlick.width, root.previewColumns.length * root.columnWidth)
                            spacing: 1

                            Repeater {
                                model: root.previewRows
                                delegate: Rectangle {
                                    id: rowDelegate
                                    required property var modelData
                                    required property int index
                                    property var rowData: modelData
                                    width: previewTable.width
                                    height: 40
                                    color: index % 2 === 0 ? Theme.background : Theme.surface
                                    border.color: Theme.border

                                    Row {
                                        anchors.fill: parent
                                        spacing: 0

                                        Repeater {
                                            model: root.previewColumns
                                            delegate: Rectangle {
                                                required property string modelData
                                                required property int index
                                                width: root.columnWidth
                                                height: 40
                                                color: "transparent"
                                                border.color: Theme.border
                                                Text {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: Theme.spacingSmall
                                                    anchors.rightMargin: Theme.spacingSmall
                                                    text: root.cellValue(rowDelegate.rowData, index)
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
                    }

                    Rectangle {
                        visible: root.previewColumns.length === 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: Theme.background
                        border.color: Theme.border
                        radius: Theme.radiusMedium
                        Text {
                            anchors.centerIn: parent
                            text: root.sourcePath === "" ? "Select a file to begin the review." : "No preview data available."
                            color: Theme.textMuted
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }
    }
}
