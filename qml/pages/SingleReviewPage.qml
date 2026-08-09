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
        } catch (e) {
            return text
        }
    }

    function reviewFile() {
        if (!root.backendAvailable())
            return

        if (root.sourcePath === "")
            return

        backend.review.review_single_file(
            root.sourcePath
        )
    }

    function exportReview() {
        if (!root.backendAvailable())
            return

        if (root.sourcePath === "" ||
                root.destinationPath === "")
            return

        backend.review.export_single_review(
            root.sourcePath,
            root.destinationPath
        )
    }

    // =========================================================
    // FILE DIALOGS
    // =========================================================

    FileDialog {
        id: sourceDialog

        title: "Select File to Review"

        nameFilters: [
            "Data Files (*.csv *.xlsx *.xls *.xlsm *.txt *.tsv)",
            "All Files (*)"
        ]

        onAccepted: {
            root.sourcePath =
                root.urlToPath(selectedFile)

            root.reviewFile()
        }
    }

    FileDialog {
        id: destinationDialog

        title: "Export Review"

        fileMode:
            FileDialog.SaveFile

        currentFile:
            "single_file_review.csv"

        nameFilters: [
            "CSV Files (*.csv)",
            "All Files (*)"
        ]

        onAccepted: {
            root.destinationPath =
                root.urlToPath(selectedFile)
        }
    }

    // =========================================================
    // BACKEND
    // =========================================================

    Connections {
        target:
            root.backendAvailable()
                ? backend.review
                : null

        ignoreUnknownSignals: true

        function onSingleReviewReady(payload) {
            try {
                var data = JSON.parse(payload)

                root.totalRecords =
                    Number(data.totalRecords || 0)

                root.attentionCount =
                    Number(data.attentionCount || 0)

                root.previewColumns =
                    data.previewColumns || []

                root.previewRows =
                    data.previewRows || []

                root.findings =
                    data.findings || []

            } catch (error) {
                root.totalRecords = 0
                root.attentionCount = 0
                root.previewColumns = []
                root.previewRows = []
                root.findings = []
            }
        }
    }

    // =========================================================
    // PAGE
    // =========================================================

    ScrollView {
        anchors.fill: parent

        clip: true

        ScrollBar.vertical.policy:
            ScrollBar.AsNeeded

        ColumnLayout {
            id: page

            width:
                parent.width

            spacing:
                Theme.spacingLarge

            // =================================================
            // TITLE
            // =================================================

            PageTitle {
                Layout.fillWidth: true

                Layout.leftMargin:
                    Theme.spacingXLarge

                Layout.rightMargin:
                    Theme.spacingXLarge

                Layout.topMargin:
                    Theme.spacingLarge

                title:
                    "Single File Review"

                subtitle:
                    "Inspect a single dataset, identify quality issues, and review a representative preview."
            }

            // =================================================
            // FILE CARD
            // =================================================

            Card {
                Layout.fillWidth: true

                Layout.leftMargin:
                    Theme.spacingXLarge

                Layout.rightMargin:
                    Theme.spacingXLarge

                Layout.preferredHeight:
                    145

                ColumnLayout {
                    anchors.fill: parent

                    anchors.margins:
                        Theme.spacingMedium

                    spacing:
                        Theme.spacingMedium

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text:
                                "Dataset"

                            color:
                                Theme.textSecondary

                            font.bold: true

                            Layout.preferredWidth:
                                100
                        }

                        TextField {
                            Layout.fillWidth: true

                            readOnly: true

                            text:
                                root.sourcePath

                            placeholderText:
                                "Select a dataset to review"

                            color:
                                Theme.textPrimary

                            background:
                                Rectangle {
                                    color:
                                        Theme.background

                                    border.color:
                                        root.sourcePath !== ""
                                            ? Theme.primary
                                            : Theme.border

                                    radius:
                                        Theme.radiusMedium
                                }
                        }

                        AppButton {
                            text:
                                "Browse"

                            onClicked:
                                sourceDialog.open()
                        }

                        PrimaryButton {
                            text:
                                "Review"

                            enabled:
                                root.sourcePath !== ""

                            onClicked:
                                root.reviewFile()
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text:
                                "Export"

                            color:
                                Theme.textSecondary

                            font.bold: true

                            Layout.preferredWidth:
                                100
                        }

                        TextField {
                            Layout.fillWidth: true

                            readOnly: true

                            text:
                                root.destinationPath

                            placeholderText:
                                "Choose destination"

                            color:
                                Theme.textPrimary

                            background:
                                Rectangle {
                                    color:
                                        Theme.background

                                    border.color:
                                        root.destinationPath !== ""
                                            ? Theme.primary
                                            : Theme.border

                                    radius:
                                        Theme.radiusMedium
                                }
                        }

                        AppButton {
                            text:
                                "Browse"

                            enabled:
                                root.sourcePath !== ""

                            onClicked:
                                destinationDialog.open()
                        }

                        PrimaryButton {
                            text:
                                "Export"

                            enabled:
                                root.sourcePath !== "" &&
                                root.destinationPath !== ""

                            onClicked:
                                root.exportReview()
                        }
                    }
                }
            }

            // =================================================
            // METRICS
            // =================================================

            RowLayout {
                Layout.fillWidth: true

                Layout.leftMargin:
                    Theme.spacingXLarge

                Layout.rightMargin:
                    Theme.spacingXLarge

                spacing:
                    Theme.spacingMedium

                Card {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 82

                    ColumnLayout {
                        anchors.centerIn: parent

                        Text {
                            text:
                                root.totalRecords

                            color:
                                Theme.primary

                            font.pixelSize:
                                23

                            font.bold:
                                true

                            Layout.alignment:
                                Qt.AlignHCenter
                        }

                        Text {
                            text:
                                "TOTAL RECORDS"

                            color:
                                Theme.textSecondary

                            font.pixelSize:
                                10

                            font.bold:
                                true

                            Layout.alignment:
                                Qt.AlignHCenter
                        }
                    }
                }

                Card {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 82

                    ColumnLayout {
                        anchors.centerIn: parent

                        Text {
                            text:
                                root.previewColumns.length

                            color:
                                Theme.info

                            font.pixelSize:
                                23

                            font.bold:
                                true

                            Layout.alignment:
                                Qt.AlignHCenter
                        }

                        Text {
                            text:
                                "COLUMNS"

                            color:
                                Theme.textSecondary

                            font.pixelSize:
                                10

                            font.bold:
                                true

                            Layout.alignment:
                                Qt.AlignHCenter
                        }
                    }
                }

                Card {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 82

                    ColumnLayout {
                        anchors.centerIn: parent

                        Text {
                            text:
                                root.attentionCount

                            color:
                                root.attentionCount > 0
                                    ? Theme.error
                                    : Theme.success

                            font.pixelSize:
                                23

                            font.bold:
                                true

                            Layout.alignment:
                                Qt.AlignHCenter
                        }

                        Text {
                            text:
                                "ATTENTION"

                            color:
                                Theme.textSecondary

                            font.pixelSize:
                                10

                            font.bold:
                                true

                            Layout.alignment:
                                Qt.AlignHCenter
                        }
                    }
                }

                Card {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 82

                    ColumnLayout {
                        anchors.centerIn: parent

                        Text {
                            text:
                                root.findings.length

                            color:
                                root.findings.length > 0
                                    ? Theme.warning
                                    : Theme.success

                            font.pixelSize:
                                23

                            font.bold:
                                true

                            Layout.alignment:
                                Qt.AlignHCenter
                        }

                        Text {
                            text:
                                "FINDINGS"

                            color:
                                Theme.textSecondary

                            font.pixelSize:
                                10

                            font.bold:
                                true

                            Layout.alignment:
                                Qt.AlignHCenter
                        }
                    }
                }
            }

            // =================================================
            // FINDINGS
            // =================================================

            Card {
                visible:
                    root.findings.length > 0

                Layout.fillWidth: true

                Layout.leftMargin:
                    Theme.spacingXLarge

                Layout.rightMargin:
                    Theme.spacingXLarge

                Layout.preferredHeight:
                    visible
                        ? Math.min(
                            220,
                            70 +
                            root.findings.length * 48
                          )
                        : 0

                ColumnLayout {
                    anchors.fill: parent

                    anchors.margins:
                        Theme.spacingMedium

                    spacing:
                        Theme.spacingSmall

                    Text {
                        text:
                            "Data Quality Findings"

                        color:
                            Theme.textPrimary

                        font.pixelSize:
                            15

                        font.bold:
                            true
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        clip: true

                        spacing:
                            Theme.spacingSmall

                        model:
                            root.findings

                        ScrollBar.vertical:
                            ScrollBar {}

                        delegate:
                            Rectangle {
                                required property var modelData

                                width:
                                    parent
                                        ? parent.width
                                        : 0

                                height:
                                    42

                                radius:
                                    Theme.radiusMedium

                                color:
                                    String(
                                        modelData.severity || ""
                                    ).toUpperCase() === "ERROR"
                                        ? "#421820"
                                        : "#433614"

                                border.color:
                                    Theme.border

                                RowLayout {
                                    anchors.fill: parent

                                    anchors.margins:
                                        Theme.spacingSmall

                                    spacing:
                                        Theme.spacingSmall

                                    Rectangle {
                                        width: 7
                                        height: 7

                                        radius: 4

                                        color:
                                            String(
                                                modelData.severity || ""
                                            ).toUpperCase() === "ERROR"
                                                ? Theme.error
                                                : Theme.warning
                                    }

                                    Text {
                                        text:
                                            String(
                                                modelData.severity ||
                                                "WARNING"
                                            ).toUpperCase()

                                        color:
                                            String(
                                                modelData.severity || ""
                                            ).toUpperCase() === "ERROR"
                                                ? Theme.error
                                                : Theme.warning

                                        font.bold:
                                            true

                                        Layout.preferredWidth:
                                            80
                                    }

                                    Text {
                                        text:
                                            String(
                                                modelData.message || ""
                                            )

                                        color:
                                            Theme.textPrimary

                                        Layout.fillWidth:
                                            true

                                        elide:
                                            Text.ElideRight
                                    }
                                }
                            }
                    }
                }
            }

            // =================================================
            // PREVIEW
            // =================================================

            Card {
                Layout.fillWidth: true

                Layout.leftMargin:
                    Theme.spacingXLarge

                Layout.rightMargin:
                    Theme.spacingXLarge

                Layout.bottomMargin:
                    Theme.spacingXLarge

                Layout.preferredHeight:
                    610

                ColumnLayout {
                    anchors.fill: parent

                    anchors.margins:
                        Theme.spacingMedium

                    spacing:
                        Theme.spacingSmall

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text:
                                "Dataset Preview"

                            color:
                                Theme.textPrimary

                            font.pixelSize:
                                15

                            font.bold:
                                true
                        }

                        Item {
                            Layout.fillWidth:
                                true
                        }

                        Text {
                            visible:
                                root.totalRecords > 50

                            text:
                                "Showing first "
                                + root.previewRows.length
                                + " of "
                                + root.totalRecords
                                + " records"

                            color:
                                Theme.textSecondary

                            font.pixelSize:
                                11
                        }
                    }

                    // -------------------------------------------------
                    // COLUMN HEADER
                    // -------------------------------------------------

                    Rectangle {
                        Layout.fillWidth: true

                        height:
                            root.previewColumns.length > 0
                                ? 38
                                : 0

                        color:
                            Theme.surfaceHover

                        border.color:
                            Theme.border

                        clip: true

                        Row {
                            anchors.fill: parent

                            spacing: 0

                            Repeater {
                                model:
                                    root.previewColumns

                                delegate:
                                    Rectangle {
                                        required property string modelData

                                        width:
                                            Math.max(
                                                145,
                                                Math.min(
                                                    260,
                                                    root.previewColumns.length > 0
                                                        ? 850 /
                                                          root.previewColumns.length
                                                        : 145
                                                )
                                            )

                                        height:
                                            38

                                        color:
                                            "transparent"

                                        border.color:
                                            Theme.border

                                        Text {
                                            anchors.fill: parent

                                            anchors.leftMargin:
                                                Theme.spacingSmall

                                            anchors.rightMargin:
                                                Theme.spacingSmall

                                            text:
                                                modelData

                                            color:
                                                Theme.textSecondary

                                            font.bold:
                                                true

                                            font.pixelSize:
                                                11

                                            elide:
                                                Text.ElideRight

                                            verticalAlignment:
                                                Text.AlignVCenter
                                        }
                                    }
                            }
                        }
                    }

                    // -------------------------------------------------
                    // DATA
                    // -------------------------------------------------

                    Flickable {
                        id: previewFlick

                        Layout.fillWidth: true

                        Layout.fillHeight: true

                        clip: true

                        contentWidth:
                            Math.max(
                                width,
                                root.previewColumns.length *
                                160
                            )

                        contentHeight:
                            previewColumn.height

                        boundsBehavior:
                            Flickable.StopAtBounds

                        ScrollBar.vertical:
                            ScrollBar {}

                        ScrollBar.horizontal:
                            ScrollBar {}

                        Column {
                            id: previewColumn

                            width:
                                Math.max(
                                    previewFlick.width,
                                    root.previewColumns.length *
                                    160
                                )

                            spacing: 1

                            Repeater {
                                model:
                                    root.previewRows

                                delegate:
                                    Rectangle {
                                        required property var modelData
                                        required property int index

                                        width:
                                            previewColumn.width

                                        height:
                                            40

                                        color:
                                            index % 2 === 0
                                                ? Theme.background
                                                : Theme.surface

                                        border.color:
                                            Theme.border

                                        Row {
                                            anchors.fill: parent

                                            spacing: 0

                                            Repeater {
                                                model:
                                                    root.previewColumns

                                                delegate:
                                                    Rectangle {
                                                        required property string modelData

                                                        width:
                                                            160

                                                        height:
                                                            40

                                                        color:
                                                            "transparent"

                                                        border.color:
                                                            Theme.border

                                                        Text {
                                                            anchors.fill:
                                                                parent

                                                            anchors.leftMargin:
                                                                Theme.spacingSmall

                                                            anchors.rightMargin:
                                                                Theme.spacingSmall

                                                            text: {
                                                                var row =
                                                                    modelData

                                                                if (row === null ||
                                                                        row === undefined) {
                                                                    return ""
                                                                }

                                                                if (Array.isArray(row)) {
                                                                    return ""
                                                                }

                                                                return String(
                                                                    row[
                                                                        parent
                                                                            .parent
                                                                            .modelData
                                                                            ? modelData
                                                                            : ""
                                                                    ] || ""
                                                                )
                                                            }

                                                            color:
                                                                Theme.textPrimary

                                                            font.pixelSize:
                                                                11

                                                            elide:
                                                                Text.ElideRight

                                                            verticalAlignment:
                                                                Text.AlignVCenter
                                                        }
                                                    }
                                            }
                                        }
                                    }
                            }
                        }

                        // Dictionary-row rendering is handled
                        // explicitly below for predictable QML
                        // property access.
                        Column {
                            visible: false
                        }
                    }

                    // =================================================
                    // EMPTY STATE
                    // =================================================

                    Rectangle {
                        visible:
                            root.previewColumns.length === 0

                        Layout.fillWidth: true

                        Layout.fillHeight: true

                        color:
                            Theme.background

                        border.color:
                            Theme.border

                        radius:
                            Theme.radiusMedium

                        Text {
                            anchors.centerIn:
                                parent

                            text:
                                root.sourcePath === ""
                                    ? "Select a file to begin the review."
                                    : "No preview data available."

                            color:
                                Theme.textMuted

                            font.pixelSize:
                                13
                        }
                    }
                }
            }
        }
    }
}
