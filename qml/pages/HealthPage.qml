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

    property var statsData: ({})
    property var healthData: ({})

    property int totalRows: 0
    property int displayedRows: 0
    property bool truncated: false

    property string selectedColumn: ""
    property string selectedOperation: "count"
    property string groupColumn: ""

    function backendAvailable() {
        return typeof backend !== "undefined" &&
               backend !== null &&
               backend.health !== undefined &&
               backend.health !== null
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

    function loadData() {
        if (!root.backendAvailable() ||
                root.sourcePath === "")
            return

        backend.health.load_data(
            root.sourcePath
        )
    }

    function calculateStats() {
        if (!root.backendAvailable() ||
                root.selectedColumn === "")
            return

        backend.health.stats(
            root.selectedColumn,
            root.selectedOperation,
            root.groupColumn
        )
    }

    function rowValue(row, column) {
        if (row === null ||
                row === undefined)
            return ""

        if (Array.isArray(row))
            return ""

        if (typeof row === "object") {
            var value = row[column]

            if (value === null ||
                    value === undefined)
                return ""

            return String(value)
        }

        return ""
    }

    function formatStatValue(value) {
        if (value === null ||
                value === undefined)
            return "—"

        if (typeof value === "object")
            return JSON.stringify(value)

        return String(value)
    }

    function statsKeys() {
        var result = []

        if (!root.statsData ||
                typeof root.statsData !== "object")
            return result

        for (var key in root.statsData)
            result.push(key)

        return result
    }

    FileDialog {
        id: fileDialog

        title:
            "Select Dataset"

        nameFilters: [
            "Data Files (*.csv *.xlsx *.xls *.xlsm *.tsv *.txt)",
            "All Files (*)"
        ]

        onAccepted: {
            root.sourcePath =
                root.urlToPath(selectedFile)

            root.loadData()
        }
    }

    FileDialog {
        id: reportDialog

        title:
            "Export Health Report"

        fileMode:
            FileDialog.SaveFile

        currentFile:
            "health_report.html"

        nameFilters: [
            "HTML Files (*.html)",
            "All Files (*)"
        ]

        onAccepted: {
            if (root.backendAvailable()) {
                backend.health.export_health_report(
                    root.urlToPath(selectedFile)
                )
            }
        }
    }

    Connections {
        target:
            root.backendAvailable()
                ? backend.health
                : null

        ignoreUnknownSignals: true

        function onTableReady(payload) {
            try {
                var data =
                    JSON.parse(payload)

                root.columns =
                    data.columns || []

                root.rows =
                    data.rows || []

                root.totalRows =
                    Number(data.total || 0)

                root.displayedRows =
                    Number(
                        data.displayed ||
                        root.rows.length
                    )

                root.truncated =
                    Boolean(data.truncated)

                if (root.selectedColumn === "" &&
                        root.columns.length > 0) {
                    root.selectedColumn =
                        root.columns[0]
                }

            } catch (error) {
                root.columns = []
                root.rows = []
                root.totalRows = 0
                root.displayedRows = 0
                root.truncated = false
            }
        }

        function onStatsReady(payload) {
            try {
                root.statsData =
                    JSON.parse(payload)
            } catch (error) {
                root.statsData = ({})
            }
        }

        function onHealthReady(payload) {
            try {
                root.healthData =
                    JSON.parse(payload)
            } catch (error) {
                root.healthData = ({})
            }
        }
    }

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
                    "Data Health"

                subtitle:
                    "Profile your dataset, calculate statistics, and inspect data quality."
            }

            // =================================================
            // DATASET
            // =================================================

            Card {
                Layout.fillWidth: true

                Layout.leftMargin:
                    Theme.spacingXLarge

                Layout.rightMargin:
                    Theme.spacingXLarge

                Layout.preferredHeight:
                    115

                RowLayout {
                    anchors.fill:
                        parent

                    anchors.margins:
                        Theme.spacingMedium

                    spacing:
                        Theme.spacingSmall

                    Text {
                        text:
                            "Dataset"

                        color:
                            Theme.textSecondary

                        font.bold:
                            true

                        Layout.preferredWidth:
                            75
                    }

                    TextField {
                        Layout.fillWidth:
                            true

                        readOnly:
                            true

                        text:
                            root.sourcePath

                        placeholderText:
                            "Select a dataset"

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
                            fileDialog.open()
                    }

                    PrimaryButton {
                        text:
                            "Analyze"

                        enabled:
                            root.sourcePath !== ""

                        onClicked:
                            root.loadData()
                    }

                    AppButton {
                        text:
                            "Export Report"

                        enabled:
                            root.sourcePath !== ""

                        onClicked:
                            reportDialog.open()
                    }
                }
            }

            // =================================================
            // OVERVIEW
            // =================================================

            RowLayout {
                Layout.fillWidth:
                    true

                Layout.leftMargin:
                    Theme.spacingXLarge

                Layout.rightMargin:
                    Theme.spacingXLarge

                spacing:
                    Theme.spacingMedium

                Card {
                    Layout.fillWidth:
                        true

                    Layout.preferredHeight:
                        82

                    ColumnLayout {
                        anchors.centerIn:
                            parent

                        Text {
                            text:
                                root.totalRows

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
                                "TOTAL ROWS"

                            color:
                                Theme.textSecondary

                            font.pixelSize:
                                10

                            font.bold:
                                true
                        }
                    }
                }

                Card {
                    Layout.fillWidth:
                        true

                    Layout.preferredHeight:
                        82

                    ColumnLayout {
                        anchors.centerIn:
                            parent

                        Text {
                            text:
                                root.columns.length

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
                        }
                    }
                }

                Card {
                    Layout.fillWidth:
                        true

                    Layout.preferredHeight:
                        82

                    ColumnLayout {
                        anchors.centerIn:
                            parent

                        Text {
                            text:
                                root.healthData &&
                                root.healthData.score !== undefined
                                    ? root.healthData.score
                                    : "—"

                            color:
                                Theme.success

                            font.pixelSize:
                                23

                            font.bold:
                                true

                            Layout.alignment:
                                Qt.AlignHCenter
                        }

                        Text {
                            text:
                                "HEALTH SCORE"

                            color:
                                Theme.textSecondary

                            font.pixelSize:
                                10

                            font.bold:
                                true
                        }
                    }
                }

                Card {
                    Layout.fillWidth:
                        true

                    Layout.preferredHeight:
                        82

                    ColumnLayout {
                        anchors.centerIn:
                            parent

                        Text {
                            text:
                                root.truncated
                                    ? "LIMITED"
                                    : "FULL"

                            color:
                                root.truncated
                                    ? Theme.warning
                                    : Theme.success

                            font.pixelSize:
                                16

                            font.bold:
                                true

                            Layout.alignment:
                                Qt.AlignHCenter
                        }

                        Text {
                            text:
                                "PREVIEW"

                            color:
                                Theme.textSecondary

                            font.pixelSize:
                                10

                            font.bold:
                                true
                        }
                    }
                }
            }

            // =================================================
            // STATISTICS
            // =================================================

            Card {
                Layout.fillWidth:
                    true

                Layout.leftMargin:
                    Theme.spacingXLarge

                Layout.rightMargin:
                    Theme.spacingXLarge

                Layout.preferredHeight:
                    170

                ColumnLayout {
                    anchors.fill:
                        parent

                    anchors.margins:
                        Theme.spacingMedium

                    spacing:
                        Theme.spacingSmall

                    Text {
                        text:
                            "Column Statistics"

                        color:
                            Theme.textPrimary

                        font.pixelSize:
                            15

                        font.bold:
                            true
                    }

                    RowLayout {
                        Layout.fillWidth:
                            true

                        ComboBox {
                            id: columnCombo

                            Layout.fillWidth:
                                true

                            model:
                                root.columns

                            currentIndex:
                                root.selectedColumn === ""
                                    ? -1
                                    : root.columns.indexOf(
                                        root.selectedColumn
                                      )

                            onCurrentTextChanged: {
                                if (currentIndex >= 0)
                                    root.selectedColumn =
                                        currentText
                            }

                            background:
                                Rectangle {
                                    color:
                                        Theme.background

                                    border.color:
                                        Theme.border

                                    radius:
                                        Theme.radiusMedium
                                }
                        }

                        ComboBox {
                            id: operationCombo

                            Layout.preferredWidth:
                                170

                            model: [
                                "count",
                                "unique",
                                "nulls",
                                "mean",
                                "median",
                                "min",
                                "max",
                                "sum"
                            ]

                            currentIndex:
                                Math.max(
                                    0,
                                    model.indexOf(
                                        root.selectedOperation
                                    )
                                )

                            onCurrentTextChanged:
                                root.selectedOperation =
                                    currentText

                            background:
                                Rectangle {
                                    color:
                                        Theme.background

                                    border.color:
                                        Theme.border

                                    radius:
                                        Theme.radiusMedium
                                }
                        }

                        ComboBox {
                            id: groupCombo

                            Layout.preferredWidth:
                                190

                            model:
                                ["No Group"].concat(
                                    root.columns
                                )

                            currentIndex:
                                root.groupColumn === ""
                                    ? 0
                                    : root.columns.indexOf(
                                        root.groupColumn
                                      ) + 1

                            onCurrentIndexChanged: {
                                root.groupColumn =
                                    currentIndex <= 0
                                        ? ""
                                        : root.columns[
                                            currentIndex - 1
                                          ]
                            }

                            background:
                                Rectangle {
                                    color:
                                        Theme.background

                                    border.color:
                                        Theme.border

                                    radius:
                                        Theme.radiusMedium
                                }
                        }

                        PrimaryButton {
                            text:
                                "Calculate"

                            enabled:
                                root.selectedColumn !== ""

                            onClicked:
                                root.calculateStats()
                        }
                    }

                    RowLayout {
                        Layout.fillWidth:
                            true

                        Text {
                            text:
                                root.selectedColumn === ""
                                    ? "Select a column to calculate statistics."
                                    : "Column: "
                                      + root.selectedColumn

                            color:
                                Theme.textSecondary

                            font.pixelSize:
                                11

                            Layout.fillWidth:
                                true
                        }

                        Text {
                            visible:
                                root.groupColumn !== ""

                            text:
                                "Grouped by "
                                + root.groupColumn

                            color:
                                Theme.info

                            font.pixelSize:
                                11
                        }
                    }
                }
            }

            // =================================================
            // STATISTICS RESULT
            // =================================================

            Card {
                visible:
                    root.statsKeys().length > 0

                Layout.fillWidth:
                    true

                Layout.leftMargin:
                    Theme.spacingXLarge

                Layout.rightMargin:
                    Theme.spacingXLarge

                Layout.preferredHeight:
                    Math.max(
                        100,
                        Math.min(
                            300,
                            80 +
                            root.statsKeys().length * 45
                        )
                    )

                ColumnLayout {
                    anchors.fill:
                        parent

                    anchors.margins:
                        Theme.spacingMedium

                    spacing:
                        Theme.spacingSmall

                    Text {
                        text:
                            "Statistics Result"

                        color:
                            Theme.textPrimary

                        font.pixelSize:
                            15

                        font.bold:
                            true
                    }

                    ListView {
                        Layout.fillWidth:
                            true

                        Layout.fillHeight:
                            true

                        clip:
                            true

                        model:
                            root.statsKeys()

                        ScrollBar.vertical:
                            ScrollBar {}

                        delegate:
                            Rectangle {
                                required property string modelData

                                width:
                                    parent
                                        ? parent.width
                                        : 0

                                height:
                                    40

                                color:
                                    Theme.background

                                border.color:
                                    Theme.border

                                RowLayout {
                                    anchors.fill:
                                        parent

                                    anchors.leftMargin:
                                        Theme.spacingSmall

                                    anchors.rightMargin:
                                        Theme.spacingSmall

                                    Text {
                                        text:
                                            modelData

                                        color:
                                            Theme.textSecondary

                                        font.bold:
                                            true

                                        Layout.preferredWidth:
                                            180

                                        elide:
                                            Text.ElideRight
                                    }

                                    Text {
                                        text:
                                            root.formatStatValue(
                                                root.statsData[
                                                    modelData
                                                ]
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
            // HEALTH DETAILS
            // =================================================

            Card {
                visible:
                    root.healthData &&
                    Object.keys(root.healthData).length > 0

                Layout.fillWidth:
                    true

                Layout.leftMargin:
                    Theme.spacingXLarge

                Layout.rightMargin:
                    Theme.spacingXLarge

                Layout.preferredHeight:
                    180

                ColumnLayout {
                    anchors.fill:
                        parent

                    anchors.margins:
                        Theme.spacingMedium

                    spacing:
                        Theme.spacingSmall

                    Text {
                        text:
                            "Dataset Health"

                        color:
                            Theme.textPrimary

                        font.pixelSize:
                            15

                        font.bold:
                            true
                    }

                    GridLayout {
                        Layout.fillWidth:
                            true

                        columns:
                            3

                        rowSpacing:
                            Theme.spacingSmall

                        columnSpacing:
                            Theme.spacingLarge

                        Repeater {
                            model:
                                root.healthData
                                    ? Object.keys(
                                        root.healthData
                                      )
                                    : []

                            delegate:
                                Rectangle {
                                    required property string modelData

                                    Layout.fillWidth:
                                        true

                                    height:
                                        42

                                    color:
                                        Theme.background

                                    border.color:
                                        Theme.border

                                    radius:
                                        Theme.radiusMedium

                                    RowLayout {
                                        anchors.fill:
                                            parent

                                        anchors.leftMargin:
                                            Theme.spacingSmall

                                        anchors.rightMargin:
                                            Theme.spacingSmall

                                        Text {
                                            text:
                                                modelData

                                            color:
                                                Theme.textSecondary

                                            font.pixelSize:
                                                10

                                            font.bold:
                                                true

                                            Layout.fillWidth:
                                                true

                                            elide:
                                                Text.ElideRight
                                        }

                                        Text {
                                            text:
                                                root.formatStatValue(
                                                    root.healthData[
                                                        modelData
                                                    ]
                                                )

                                            color:
                                                Theme.textPrimary

                                            font.bold:
                                                true
                                        }
                                    }
                                }
                        }
                    }
                }
            }

            // =================================================
            // DATA PREVIEW
            // =================================================

            Card {
                Layout.fillWidth:
                    true

                Layout.leftMargin:
                    Theme.spacingXLarge

                Layout.rightMargin:
                    Theme.spacingXLarge

                Layout.bottomMargin:
                    Theme.spacingXLarge

                Layout.preferredHeight:
                    620

                ColumnLayout {
                    anchors.fill:
                        parent

                    anchors.margins:
                        Theme.spacingMedium

                    spacing:
                        Theme.spacingSmall

                    RowLayout {
                        Layout.fillWidth:
                            true

                        Text {
                            text:
                                "Data Preview"

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
                            text:
                                root.displayedRows
                                + " displayed"

                            color:
                                Theme.textSecondary

                            font.pixelSize:
                                11
                        }
                    }

                    Flickable {
                        id: tableFlick

                        Layout.fillWidth:
                            true

                        Layout.fillHeight:
                            true

                        clip:
                            true

                        boundsBehavior:
                            Flickable.StopAtBounds

                        contentWidth:
                            Math.max(
                                width,
                                root.columns.length * 160
                            )

                        contentHeight:
                            tableColumn.height

                        ScrollBar.vertical:
                            ScrollBar {}

                        ScrollBar.horizontal:
                            ScrollBar {}

                        Column {
                            id: tableColumn

                            width:
                                tableFlick.contentWidth

                            spacing:
                                1

                            Row {
                                width:
                                    parent.width

                                height:
                                    40

                                spacing:
                                    0

                                Repeater {
                                    model:
                                        root.columns

                                    delegate:
                                        Rectangle {
                                            required property string modelData

                                            width:
                                                160

                                            height:
                                                40

                                            color:
                                                Theme.surfaceHover

                                            border.color:
                                                Theme.border

                                            Text {
                                                anchors.fill:
                                                    parent

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

                            Repeater {
                                model:
                                    root.rows

                                delegate:
                                    Row {
                                        required property var modelData
                                        required property int index

                                        readonly property var rowData:
                                            modelData
                                        readonly property int rowIndex:
                                            index

                                        width:
                                            tableColumn.width

                                        height:
                                            40

                                        spacing:
                                            0

                                        Repeater {
                                            model:
                                                root.columns

                                            delegate:
                                                Rectangle {
                                                    required property string modelData

                                                    width:
                                                        160

                                                    height:
                                                        40

                                                    color:
                                                        parent.rowIndex % 2 === 0
                                                            ? Theme.background
                                                            : Theme.surface

                                                    border.color:
                                                        Theme.border

                                                    Text {
                                                        anchors.fill:
                                                            parent

                                                        anchors.leftMargin:
                                                            Theme.spacingSmall

                                                        anchors.rightMargin:
                                                            Theme.spacingSmall

                                                        text:
                                                            root.rowValue(
                                                                parent.rowData,
                                                                modelData
                                                            )

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

                    Rectangle {
                        visible:
                            root.rows.length === 0

                        Layout.fillWidth:
                            true

                        Layout.fillHeight:
                            true

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
                                    ? "Load a dataset to begin."
                                    : "No preview rows available."

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
