import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

ApplicationWindow {
    id: root

    visible: true
    width: 1500
    height: 900
    minimumWidth: 1100
    minimumHeight: 700

    title: "Store Data Assistant 6.1"

    // ============================================================
    // THEME
    // ============================================================

    property color bg: "#07111f"
    property color sidebar: "#0b1728"
    property color panel: "#0e1b2d"
    property color panel2: "#111f33"
    property color border: "#23344c"

    property color primary: "#3b82f6"
    property color primaryHover: "#2563eb"

    property color textPrimary: "#f8fafc"
    property color textSecondary: "#94a3b8"
    property color textMuted: "#64748b"

    property color success: "#22c55e"
    property color warning: "#f59e0b"
    property color danger: "#ef4444"

    property int currentPage: 0

    property string masterPath: ""
    property string mappingPath: ""
    property string repairPath: ""
    property string analysisPath: ""

    property var masterMapping: ({})
    property var mappingMapping: ({})

    property int validationTotal: 0
    property int validationCorrect: 0
    property int validationReview: 0
    property int validationErrors: 0

    property var healthData: ({})
    property var sqlColumns: []

    color: bg

    // ============================================================
    // HELPERS
    // ============================================================

    function fileName(path) {
        if (!path)
            return ""

        var normalized = path.replace(/\\/g, "/")
        var parts = normalized.split("/")
        return parts[parts.length - 1]
    }

    function clearList(model) {
        if (model)
            model.clear()
    }

    function mappingConfidenceColor(confidence) {
        if (confidence >= 90)
            return success
        if (confidence >= 70)
            return warning
        return danger
    }

    // ============================================================
    // MODELS
    // ============================================================

    ListModel {
        id: columnMappingModel
    }

    ListModel {
        id: validationModel
    }

    ListModel {
        id: csvProblemModel
    }

    ListModel {
        id: healthColumnModel
    }

    ListModel {
        id: sqlResultModel
    }

    // ============================================================
    // FILE DIALOGS
    // ============================================================

    FileDialog {
        id: masterDialog

        title: "Select Master Store File"

        nameFilters: [
            "Data files (*.csv *.xlsx *.xls *.xlsm *.txt *.tsv *.json *.xml)",
            "All files (*)"
        ]

        onAccepted: {
            root.masterPath = selectedFile.toString()
            backend.loadMaster(root.masterPath)
        }
    }

    FileDialog {
        id: mappingDialog

        title: "Select Mapping / Country File"

        nameFilters: [
            "Data files (*.csv *.xlsx *.xls *.xlsm *.txt *.tsv *.json *.xml)",
            "All files (*)"
        ]

        onAccepted: {
            root.mappingPath = selectedFile.toString()
            backend.loadMapping(root.mappingPath)
        }
    }

    FileDialog {
        id: repairDialog

        title: "Select CSV / Text File"

        nameFilters: [
            "CSV / text files (*.csv *.txt *.tsv)",
            "All files (*)"
        ]

        onAccepted: {
            root.repairPath = selectedFile.toString()
            backend.inspectCSV(root.repairPath)
        }
    }

    FileDialog {
        id: analysisDialog

        title: "Select File to Analyze"

        nameFilters: [
            "Supported files (*.csv *.xlsx *.xls *.xlsm *.txt *.tsv *.json *.xml)",
            "All files (*)"
        ]

        onAccepted: {
            root.analysisPath = selectedFile.toString()
            backend.loadFile(root.analysisPath)
        }
    }

    FileDialog {
        id: repairSaveDialog

        title: "Save Repaired File"

        fileMode: FileDialog.SaveFile

        nameFilters: [
            "CSV files (*.csv)"
        ]

        onAccepted: {
            backend.repairCSV(
                root.repairPath,
                selectedFile.toString()
            )
        }
    }

    FileDialog {
        id: validationExportDialog

        title: "Export Validation Report"

        fileMode: FileDialog.SaveFile

        nameFilters: [
            "Excel Workbook (*.xlsx)",
            "CSV File (*.csv)"
        ]

        onAccepted: {
            backend.exportValidationReport(
                selectedFile.toString()
            )
        }
    }

    FileDialog {
        id: dataExportDialog

        title: "Export Dataset"

        fileMode: FileDialog.SaveFile

        nameFilters: [
            "Excel Workbook (*.xlsx)",
            "CSV File (*.csv)",
            "JSON File (*.json)"
        ]

        onAccepted: {
            backend.exportCurrentData(
                selectedFile.toString()
            )
        }
    }

    // ============================================================
    // BACKEND CONNECTIONS
    // ============================================================

    Connections {
        target: backend

        function onColumnMappingReady(jsonText) {
            try {
                var data = JSON.parse(jsonText)

                if (data.type === "master") {
                    root.masterMapping = data.mapping
                } else if (data.type === "mapping") {
                    root.mappingMapping = data.mapping
                } else {
                    root.masterMapping = data.master
                    root.mappingMapping = data.mapping
                }

                columnMappingModel.clear()

                var fields = [
                    "Store Name",
                    "SID",
                    "Banner",
                    "Nielsen Store Code",
                    "Trip Received",
                    "Last Trip",
                    "Address 1",
                    "Address 2",
                    "Address 3",
                    "ZIP",
                    "Active / Inactive",
                    "Is Census",
                    "Is Exceptions",
                    "Updated By"
                ]

                for (var i = 0; i < fields.length; i++) {
                    var field = fields[i]

                    var master = root.masterMapping[field]
                    var mapping = root.mappingMapping[field]

                    columnMappingModel.append({
                        standardField: field,
                        masterColumn: master ? master.column : "",
                        mappingColumn: mapping ? mapping.column : "",
                        masterConfidence: master ? master.confidence : 0,
                        mappingConfidence: mapping ? mapping.confidence : 0
                    })
                }
            } catch (e) {
                console.log("Mapping parse error:", e)
            }
        }

        function onValidationReady(jsonText) {
            try {
                var data = JSON.parse(jsonText)

                root.validationTotal = data.total
                root.validationCorrect = data.correct
                root.validationReview = data.review
                root.validationErrors = data.errors

                validationModel.clear()

                for (var i = 0; i < data.results.length; i++) {
                    var item = data.results[i]

                    validationModel.append({
                        sourceRow: String(item.row),
                        sid: String(item.sid || ""),
                        storeName: String(item.storeName || ""),
                        status: String(item.status || ""),
                        problem: String(item.problem || "")
                    })
                }
            } catch (e) {
                console.log("Validation parse error:", e)
            }
        }

        function onCsvInspectionReady(jsonText) {
            try {
                var data = JSON.parse(jsonText)

                csvProblemModel.clear()

                for (var i = 0; i < data.problems.length; i++) {
                    var item = data.problems[i]

                    csvProblemModel.append({
                        lineNumber: String(item.line),
                        expectedColumns: String(item.expectedColumns),
                        actualColumns: String(item.actualColumns),
                        content: String(item.content || ""),
                        problemText:
                            item.actualColumns < item.expectedColumns
                            ? "Missing columns"
                            : "Extra / broken columns"
                    })
                }
            } catch (e) {
                console.log("CSV inspection parse error:", e)
            }
        }

        function onAnalysisReady(jsonText) {
            try {
                var data = JSON.parse(jsonText)

                root.healthData = data

                healthColumnModel.clear()

                if (data.columnStats) {
                    for (var i = 0; i < data.columnStats.length; i++) {
                        var item = data.columnStats[i]

                        healthColumnModel.append({
                            columnName: String(item.column),
                            blankCount: String(item.blank),
                            nonBlankCount: String(item.nonBlank),
                            uniqueCount: String(item.unique),
                            duplicateCount: String(item.duplicateValues)
                        })
                    }
                }
            } catch (e) {
                console.log("Analysis parse error:", e)
            }
        }

        function onSqlResultReady(jsonText) {
            try {
                var data = JSON.parse(jsonText)

                root.sqlColumns = data.columns

                sqlResultModel.clear()

                for (var i = 0; i < data.rows.length; i++) {
                    sqlResultModel.append({
                        rowData: data.rows[i]
                    })
                }
            } catch (e) {
                console.log("SQL parse error:", e)
            }
        }
    }

    // ============================================================
    // REUSABLE COMPONENTS
    // ============================================================

    component AppButton: Button {
        id: control

        property bool primaryButton: false
        property bool dangerButton: false

        implicitHeight: 40
        leftPadding: 18
        rightPadding: 18

        contentItem: Text {
            text: control.text
            color: textPrimary
            font.pixelSize: 13
            font.bold: control.primaryButton
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            radius: 7

            color: {
                if (!control.enabled)
                    return "#253247"

                if (control.dangerButton)
                    return control.hovered ? "#dc2626" : danger

                if (control.primaryButton)
                    return control.hovered ? primaryHover : primary

                return control.hovered ? "#24344d" : panel2
            }

            border.color:
                control.primaryButton || control.dangerButton
                ? "transparent"
                : border
        }
    }

    component SectionCard: Rectangle {
        radius: 10
        color: panel
        border.color: border
        border.width: 1
    }

    component SectionTitle: Text {
        color: textPrimary
        font.pixelSize: 16
        font.bold: true
    }

    component MutedText: Text {
        color: textSecondary
        font.pixelSize: 12
    }

    component MetricCard: Rectangle {
        property string valueText: "0"
        property string labelText: ""
        property color accentColor: primary

        radius: 9
        color: panel
        border.color: border

        implicitHeight: 90

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 15
            spacing: 4

            Text {
                text: parent.parent.valueText
                color: parent.parent.accentColor
                font.pixelSize: 25
                font.bold: true
            }

            Text {
                text: parent.parent.labelText
                color: textSecondary
                font.pixelSize: 11
                font.bold: true
            }
        }
    }

    component PageHeading: ColumnLayout {
        property string titleText: ""
        property string subtitleText: ""

        spacing: 4

        Text {
            text: parent.titleText
            color: textPrimary
            font.pixelSize: 24
            font.bold: true
        }

        Text {
            text: parent.subtitleText
            color: textSecondary
            font.pixelSize: 13
        }
    }

    component TableHeaderCell: Rectangle {
        property string label: ""

        color: "#132238"
        implicitHeight: 38

        Text {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10

            text: parent.label
            color: "#cbd5e1"
            font.pixelSize: 11
            font.bold: true

            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }

    // ============================================================
    // HEADER
    // ============================================================

    header: Rectangle {
        height: 62
        color: "#081321"
        border.color: border

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18

            spacing: 12

            Rectangle {
                width: 34
                height: 34
                radius: 8
                color: primary

                Text {
                    anchors.centerIn: parent
                    text: "DA"
                    color: "white"
                    font.bold: true
                    font.pixelSize: 12
                }
            }

            ColumnLayout {
                spacing: 0

                Text {
                    text: "Store Data Assistant"
                    color: textPrimary
                    font.bold: true
                    font.pixelSize: 16
                }

                Text {
                    text: "Data validation, repair and analysis workspace"
                    color: textSecondary
                    font.pixelSize: 10
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Rectangle {
                width: 108
                height: 28
                radius: 14
                color: "#0b2b22"
                border.color: "#17633f"

                Row {
                    anchors.centerIn: parent
                    spacing: 7

                    Rectangle {
                        width: 7
                        height: 7
                        radius: 4
                        color: success
                    }

                    Text {
                        text: "LOCAL ONLY"
                        color: "#86efac"
                        font.pixelSize: 10
                        font.bold: true
                    }
                }
            }
        }
    }

    // ============================================================
    // MAIN LAYOUT
    // ============================================================

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ========================================================
        // SIDEBAR
        // ========================================================

        Rectangle {
            Layout.preferredWidth: 215
            Layout.fillHeight: true

            color: sidebar
            border.color: border

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10

                spacing: 6

                Text {
                    text: "WORKSPACE"
                    color: textMuted
                    font.pixelSize: 10
                    font.bold: true

                    Layout.leftMargin: 8
                    Layout.topMargin: 8
                    Layout.bottomMargin: 8
                }

                Repeater {
                    model: [
                        ["⌂", "Home"],
                        ["✓", "Compare & Validate"],
                        ["↻", "Repair CSV / Text"],
                        ["▤", "Data Health Check"],
                        ["⌕", "Explore & Analyze"]
                    ]

                    delegate: Button {
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        implicitHeight: 45

                        contentItem: RowLayout {
                            spacing: 10

                            Text {
                                text: modelData[0]
                                color:
                                    root.currentPage === index
                                    ? "white"
                                    : textSecondary

                                font.pixelSize: 15
                            }

                            Text {
                                text: modelData[1]
                                color:
                                    root.currentPage === index
                                    ? "white"
                                    : "#cbd5e1"

                                font.pixelSize: 12
                                font.bold:
                                    root.currentPage === index

                                Layout.fillWidth: true
                            }
                        }

                        background: Rectangle {
                            radius: 7

                            color:
                                root.currentPage === index
                                ? "#1d4777"
                                : parent.hovered
                                  ? "#13243a"
                                  : "transparent"

                            border.color:
                                root.currentPage === index
                                ? "#356da8"
                                : "transparent"
                        }

                        onClicked:
                            root.currentPage = index
                    }
                }

                Item {
                    Layout.fillHeight: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 82

                    radius: 8
                    color: "#0d1a2c"
                    border.color: border

                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 7

                        Text {
                            text: "Privacy"
                            color: textPrimary
                            font.pixelSize: 11
                            font.bold: true
                        }

                        Text {
                            width: parent.width

                            text:
                                "Files are processed locally by the application."

                            color: textSecondary
                            font.pixelSize: 9
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }

        // ========================================================
        // PAGE CONTENT
        // ========================================================

        StackLayout {
            id: pages

            currentIndex: root.currentPage

            Layout.fillWidth: true
            Layout.fillHeight: true

            // ====================================================
            // HOME
            // ====================================================

            Item {
                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 28

                    contentWidth: availableWidth

                    ColumnLayout {
                        width: parent.width
                        spacing: 18

                        PageHeading {
                            titleText: "Welcome"
                            subtitleText:
                                "Choose a workspace based on what you need to do with your data."
                        }

                        GridLayout {
                            Layout.fillWidth: true

                            columns:
                                root.width > 1350
                                ? 2
                                : 1

                            columnSpacing: 14
                            rowSpacing: 14

                            Repeater {
                                model: [
                                    [
                                        "Compare & Validate",
                                        "Compare a store mapping file with a trusted master and investigate exceptions.",
                                        1
                                    ],
                                    [
                                        "Repair CSV / Text",
                                        "Find malformed rows, delimiter problems and broken CSV records without silently dropping data.",
                                        2
                                    ],
                                    [
                                        "Data Health Check",
                                        "Inspect any supported dataset for blanks, duplicates, completeness and structural problems.",
                                        3
                                    ],
                                    [
                                        "Explore & Analyze",
                                        "Analyze a dataset, export it and run local SQL queries against the loaded data.",
                                        4
                                    ]
                                ]

                                delegate: SectionCard {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 145

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 20

                                        SectionTitle {
                                            text: modelData[0]
                                        }

                                        MutedText {
                                            text: modelData[1]
                                            wrapMode: Text.WordWrap
                                            Layout.fillWidth: true
                                        }

                                        Item {
                                            Layout.fillHeight: true
                                        }

                                        AppButton {
                                            text: "Open Workspace"
                                            primaryButton: true

                                            onClicked:
                                                root.currentPage =
                                                    modelData[2]
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ====================================================
            // COMPARE & VALIDATE
            // ====================================================

            Item {
                ScrollView {
                    anchors.fill: parent

                    contentWidth: availableWidth

                    ColumnLayout {
                        width: parent.width

                        spacing: 15

                        anchors.left: parent.left
                        anchors.right: parent.right

                        anchors.leftMargin: 28
                        anchors.rightMargin: 28
                        anchors.topMargin: 26
                        anchors.bottomMargin: 26

                        PageHeading {
                            titleText: "Compare & Validate"

                            subtitleText:
                                "Compare store mapping data against a trusted master dataset and investigate only the exceptions."
                        }

                        // ----------------------------------------
                        // FILE SELECTION
                        // ----------------------------------------

                        SectionCard {
                            Layout.fillWidth: true
                            implicitHeight: 185

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 18

                                spacing: 12

                                RowLayout {
                                    Layout.fillWidth: true

                                    SectionTitle {
                                        text: "Files"
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    MutedText {
                                        text:
                                            masterPath && mappingPath
                                            ? "2 files selected"
                                            : "Select both files"
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true

                                    spacing: 12

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Text {
                                            text: "MASTER STORE FILE"
                                            color: textSecondary
                                            font.pixelSize: 10
                                            font.bold: true
                                        }

                                        TextField {
                                            Layout.fillWidth: true

                                            text:
                                                root.masterPath
                                                ? root.fileName(root.masterPath)
                                                : ""

                                            placeholderText:
                                                "Select the trusted master file"

                                            readOnly: true
                                        }
                                    }

                                    AppButton {
                                        text: "Browse"
                                        onClicked: masterDialog.open()
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true

                                    spacing: 12

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Text {
                                            text: "MAPPING / COUNTRY FILE"
                                            color: textSecondary
                                            font.pixelSize: 10
                                            font.bold: true
                                        }

                                        TextField {
                                            Layout.fillWidth: true

                                            text:
                                                root.mappingPath
                                                ? root.fileName(root.mappingPath)
                                                : ""

                                            placeholderText:
                                                "Select the file to validate"

                                            readOnly: true
                                        }
                                    }

                                    AppButton {
                                        text: "Browse"
                                        onClicked: mappingDialog.open()
                                    }
                                }
                            }
                        }

                        // ----------------------------------------
                        // ACTIONS
                        // ----------------------------------------

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            AppButton {
                                text: "Detect & Review Columns"

                                enabled:
                                    root.masterPath !== ""
                                    && root.mappingPath !== ""

                                Layout.preferredWidth: 220

                                onClicked:
                                    backend.detectStoreColumns()
                            }

                            AppButton {
                                text: "Validate Stores"
                                primaryButton: true

                                enabled:
                                    root.masterPath !== ""
                                    && root.mappingPath !== ""

                                Layout.fillWidth: true

                                onClicked:
                                    backend.validateStores()
                            }
                        }

                        // ----------------------------------------
                        // SMART COLUMN MAPPING
                        // ----------------------------------------

                        SectionCard {
                            Layout.fillWidth: true

                            implicitHeight:
                                columnMappingModel.count > 0
                                ? 460
                                : 110

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 18
                                spacing: 12

                                RowLayout {
                                    Layout.fillWidth: true

                                    ColumnLayout {
                                        spacing: 3

                                        SectionTitle {
                                            text: "Smart Column Mapping"
                                        }

                                        MutedText {
                                            text:
                                                "Automatically matches country-specific headers to the 14 standard fields."
                                        }
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    Rectangle {
                                        width: 105
                                        height: 27
                                        radius: 13
                                        color: "#102943"

                                        Text {
                                            anchors.centerIn: parent

                                            text:
                                                columnMappingModel.count
                                                + " / 14 fields"

                                            color: "#93c5fd"
                                            font.pixelSize: 10
                                            font.bold: true
                                        }
                                    }
                                }

                                Text {
                                    visible:
                                        columnMappingModel.count === 0

                                    text:
                                        "Select both files and choose Detect & Review Columns."

                                    color: textSecondary
                                    font.pixelSize: 12
                                }

                                ColumnLayout {
                                    visible:
                                        columnMappingModel.count > 0

                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    spacing: 1

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        TableHeaderCell {
                                            label: "Standard Field"
                                            Layout.preferredWidth: 210
                                        }

                                        TableHeaderCell {
                                            label: "Master Column"
                                            Layout.fillWidth: true
                                        }

                                        TableHeaderCell {
                                            label: "Mapping Column"
                                            Layout.fillWidth: true
                                        }

                                        TableHeaderCell {
                                            label: "Confidence"
                                            Layout.preferredWidth: 120
                                        }
                                    }

                                    ListView {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        clip: true
                                        spacing: 1

                                        model: columnMappingModel

                                        delegate: Rectangle {
                                            width: ListView.view.width
                                            height: 29

                                            color:
                                                index % 2 === 0
                                                ? "#0b1829"
                                                : "#0d1b2e"

                                            RowLayout {
                                                anchors.fill: parent
                                                spacing: 1

                                                Text {
                                                    text: standardField
                                                    color: textPrimary
                                                    font.pixelSize: 11

                                                    leftPadding: 10

                                                    Layout.preferredWidth: 210
                                                    Layout.fillHeight: true

                                                    verticalAlignment:
                                                        Text.AlignVCenter
                                                }

                                                Text {
                                                    text:
                                                        masterColumn || "Not detected"

                                                    color:
                                                        masterColumn
                                                        ? "#cbd5e1"
                                                        : danger

                                                    font.pixelSize: 11
                                                    leftPadding: 10

                                                    Layout.fillWidth: true
                                                    Layout.fillHeight: true

                                                    verticalAlignment:
                                                        Text.AlignVCenter
                                                }

                                                Text {
                                                    text:
                                                        mappingColumn || "Not detected"

                                                    color:
                                                        mappingColumn
                                                        ? "#cbd5e1"
                                                        : danger

                                                    font.pixelSize: 11
                                                    leftPadding: 10

                                                    Layout.fillWidth: true
                                                    Layout.fillHeight: true

                                                    verticalAlignment:
                                                        Text.AlignVCenter
                                                }

                                                Text {
                                                    text:
                                                        Math.round(
                                                            Math.min(
                                                                masterConfidence,
                                                                mappingConfidence
                                                            )
                                                        )
                                                        + "%"

                                                    color:
                                                        root.mappingConfidenceColor(
                                                            Math.min(
                                                                masterConfidence,
                                                                mappingConfidence
                                                            )
                                                        )

                                                    font.bold: true
                                                    font.pixelSize: 11

                                                    Layout.preferredWidth: 120
                                                    Layout.fillHeight: true

                                                    verticalAlignment:
                                                        Text.AlignVCenter
                                                    horizontalAlignment:
                                                        Text.AlignHCenter
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ----------------------------------------
                        // SUMMARY
                        // ----------------------------------------

                        GridLayout {
                            Layout.fillWidth: true

                            columns:
                                root.width > 1200
                                ? 4
                                : 2

                            columnSpacing: 12
                            rowSpacing: 12

                            MetricCard {
                                valueText:
                                    root.validationTotal.toLocaleString()

                                labelText: "TOTAL CHECKED"
                                accentColor: primary
                                Layout.fillWidth: true
                            }

                            MetricCard {
                                valueText:
                                    root.validationCorrect.toLocaleString()

                                labelText: "CORRECT"
                                accentColor: success
                                Layout.fillWidth: true
                            }

                            MetricCard {
                                valueText:
                                    root.validationReview.toLocaleString()

                                labelText: "REVIEW"
                                accentColor: warning
                                Layout.fillWidth: true
                            }

                            MetricCard {
                                valueText:
                                    root.validationErrors.toLocaleString()

                                labelText: "ERRORS"
                                accentColor: danger
                                Layout.fillWidth: true
                            }
                        }

                        // ----------------------------------------
                        // RESULTS
                        // ----------------------------------------

                        SectionCard {
                            Layout.fillWidth: true
                            implicitHeight: 460

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 18
                                spacing: 12

                                RowLayout {
                                    Layout.fillWidth: true

                                    ColumnLayout {
                                        spacing: 3

                                        SectionTitle {
                                            text: "Validation Exceptions"
                                        }

                                        MutedText {
                                            text:
                                                "Review incorrect or suspicious records and export the report for correction."
                                        }
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    AppButton {
                                        text: "Export Report"

                                        enabled:
                                            validationModel.count > 0

                                        onClicked:
                                            validationExportDialog.open()
                                    }
                                }

                                Text {
                                    visible:
                                        validationModel.count === 0

                                    text:
                                        "Validation results will appear here."

                                    color: textSecondary
                                    font.pixelSize: 12
                                }

                                ColumnLayout {
                                    visible:
                                        validationModel.count > 0

                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    spacing: 1

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        TableHeaderCell {
                                            label: "Row"
                                            Layout.preferredWidth: 65
                                        }

                                        TableHeaderCell {
                                            label: "SID"
                                            Layout.preferredWidth: 130
                                        }

                                        TableHeaderCell {
                                            label: "Store Name"
                                            Layout.preferredWidth: 230
                                        }

                                        TableHeaderCell {
                                            label: "Status"
                                            Layout.preferredWidth: 100
                                        }

                                        TableHeaderCell {
                                            label: "Problem"
                                            Layout.fillWidth: true
                                        }
                                    }

                                    ListView {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        clip: true
                                        spacing: 1

                                        model: validationModel

                                        delegate: Rectangle {
                                            width: ListView.view.width
                                            height: 34

                                            color:
                                                index % 2 === 0
                                                ? "#0b1829"
                                                : "#0d1b2e"

                                            RowLayout {
                                                anchors.fill: parent
                                                spacing: 1

                                                Text {
                                                    text: sourceRow
                                                    color: textSecondary
                                                    font.pixelSize: 11
                                                    leftPadding: 10

                                                    Layout.preferredWidth: 65
                                                }

                                                Text {
                                                    text: sid
                                                    color: textPrimary
                                                    font.pixelSize: 11
                                                    leftPadding: 10

                                                    Layout.preferredWidth: 130

                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    text: storeName
                                                    color: textPrimary
                                                    font.pixelSize: 11
                                                    leftPadding: 10

                                                    Layout.preferredWidth: 230

                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    text: status

                                                    color:
                                                        status === "ERROR"
                                                        ? danger
                                                        : status === "REVIEW"
                                                          ? warning
                                                          : success

                                                    font.pixelSize: 10
                                                    font.bold: true
                                                    leftPadding: 10

                                                    Layout.preferredWidth: 100
                                                }

                                                Text {
                                                    text: problem
                                                    color: "#cbd5e1"
                                                    font.pixelSize: 11
                                                    leftPadding: 10

                                                    Layout.fillWidth: true

                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            Layout.preferredHeight: 20
                        }
                    }
                }
            }

            // ====================================================
            // CSV REPAIR
            // ====================================================

            Item {
                ScrollView {
                    anchors.fill: parent
                    contentWidth: availableWidth

                    ColumnLayout {
                        width: parent.width

                        anchors.left: parent.left
                        anchors.right: parent.right

                        anchors.margins: 28

                        spacing: 16

                        PageHeading {
                            titleText: "Repair CSV / Text"

                            subtitleText:
                                "Inspect malformed rows and repair structural problems without silently deleting records."
                        }

                        SectionCard {
                            Layout.fillWidth: true
                            implicitHeight: 135

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 18

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Text {
                                        text: "SOURCE FILE"
                                        color: textSecondary
                                        font.pixelSize: 10
                                        font.bold: true
                                    }

                                    TextField {
                                        Layout.fillWidth: true

                                        text:
                                            root.repairPath
                                            ? root.fileName(root.repairPath)
                                            : ""

                                        placeholderText:
                                            "Choose a CSV, TXT or TSV file"

                                        readOnly: true
                                    }
                                }

                                AppButton {
                                    text: "Choose File"
                                    onClicked: repairDialog.open()
                                }

                                AppButton {
                                    text: "Inspect Again"

                                    enabled:
                                        root.repairPath !== ""

                                    onClicked:
                                        backend.inspectCSV(
                                            root.repairPath
                                        )
                                }
                            }
                        }

                        SectionCard {
                            Layout.fillWidth: true
                            implicitHeight: 500

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 18

                                spacing: 12

                                RowLayout {
                                    Layout.fillWidth: true

                                    ColumnLayout {
                                        spacing: 3

                                        SectionTitle {
                                            text: "Broken Row Inspector"
                                        }

                                        MutedText {
                                            text:
                                                csvProblemModel.count
                                                + " suspicious row(s) detected"
                                        }
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    AppButton {
                                        text: "Repair & Save Copy"
                                        primaryButton: true

                                        enabled:
                                            root.repairPath !== ""

                                        onClicked:
                                            repairSaveDialog.open()
                                    }
                                }

                                Text {
                                    visible:
                                        csvProblemModel.count === 0

                                    text:
                                        root.repairPath
                                        ? "No structural line problems were detected."
                                        : "Choose a file to inspect its rows."

                                    color:
                                        root.repairPath
                                        ? success
                                        : textSecondary
                                }

                                ColumnLayout {
                                    visible:
                                        csvProblemModel.count > 0

                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    spacing: 1

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        TableHeaderCell {
                                            label: "Line"
                                            Layout.preferredWidth: 70
                                        }

                                        TableHeaderCell {
                                            label: "Problem"
                                            Layout.preferredWidth: 170
                                        }

                                        TableHeaderCell {
                                            label: "Expected"
                                            Layout.preferredWidth: 90
                                        }

                                        TableHeaderCell {
                                            label: "Actual"
                                            Layout.preferredWidth: 90
                                        }

                                        TableHeaderCell {
                                            label: "Original Information"
                                            Layout.fillWidth: true
                                        }
                                    }

                                    ListView {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        clip: true
                                        spacing: 1

                                        model: csvProblemModel

                                        delegate: Rectangle {
                                            width: ListView.view.width
                                            height: 38

                                            color:
                                                index % 2 === 0
                                                ? "#0b1829"
                                                : "#0d1b2e"

                                            RowLayout {
                                                anchors.fill: parent
                                                spacing: 1

                                                Text {
                                                    text: lineNumber
                                                    color: warning
                                                    leftPadding: 10

                                                    Layout.preferredWidth: 70
                                                }

                                                Text {
                                                    text: problemText
                                                    color: textPrimary
                                                    leftPadding: 10

                                                    Layout.preferredWidth: 170
                                                }

                                                Text {
                                                    text: expectedColumns
                                                    color: textSecondary
                                                    leftPadding: 10

                                                    Layout.preferredWidth: 90
                                                }

                                                Text {
                                                    text: actualColumns
                                                    color: danger
                                                    leftPadding: 10

                                                    Layout.preferredWidth: 90
                                                }

                                                Text {
                                                    text: content
                                                    color: "#cbd5e1"
                                                    leftPadding: 10

                                                    Layout.fillWidth: true

                                                    elide: Text.ElideRight
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

            // ====================================================
            // DATA HEALTH
            // ====================================================

            Item {
                ScrollView {
                    anchors.fill: parent
                    contentWidth: availableWidth

                    ColumnLayout {
                        width: parent.width

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 28

                        spacing: 16

                        PageHeading {
                            titleText: "Data Health Check"

                            subtitleText:
                                "Understand the structure, completeness, duplicates and quality of a dataset before using it."
                        }

                        SectionCard {
                            Layout.fillWidth: true
                            implicitHeight: 125

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 18

                                ColumnLayout {
                                    Layout.fillWidth: true

                                    SectionTitle {
                                        text:
                                            root.analysisPath
                                            ? root.fileName(root.analysisPath)
                                            : "No dataset selected"
                                    }

                                    MutedText {
                                        text:
                                            root.analysisPath
                                            ? "Dataset loaded locally"
                                            : "Choose any supported tabular dataset."
                                    }
                                }

                                AppButton {
                                    text: "Choose Dataset"
                                    primaryButton: true

                                    onClicked:
                                        analysisDialog.open()
                                }
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true

                            columns:
                                root.width > 1200
                                ? 4
                                : 2

                            columnSpacing: 12
                            rowSpacing: 12

                            MetricCard {
                                valueText:
                                    root.healthData.rows !== undefined
                                    ? Number(root.healthData.rows).toLocaleString()
                                    : "0"

                                labelText: "ROWS"
                                Layout.fillWidth: true
                            }

                            MetricCard {
                                valueText:
                                    root.healthData.columns !== undefined
                                    ? String(root.healthData.columns)
                                    : "0"

                                labelText: "COLUMNS"
                                Layout.fillWidth: true
                            }

                            MetricCard {
                                valueText:
                                    root.healthData.completeness !== undefined
                                    ? String(root.healthData.completeness) + "%"
                                    : "0%"

                                labelText: "COMPLETENESS"
                                accentColor: success
                                Layout.fillWidth: true
                            }

                            MetricCard {
                                valueText:
                                    root.healthData.duplicateRows !== undefined
                                    ? Number(root.healthData.duplicateRows).toLocaleString()
                                    : "0"

                                labelText: "DUPLICATE ROWS"
                                accentColor: warning
                                Layout.fillWidth: true
                            }
                        }

                        SectionCard {
                            Layout.fillWidth: true
                            implicitHeight: 480

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 18
                                spacing: 12

                                SectionTitle {
                                    text: "Column Quality"
                                }

                                Text {
                                    visible:
                                        healthColumnModel.count === 0

                                    text:
                                        "Column statistics will appear after a dataset is loaded."

                                    color: textSecondary
                                }

                                ColumnLayout {
                                    visible:
                                        healthColumnModel.count > 0

                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    spacing: 1

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        TableHeaderCell {
                                            label: "Column"
                                            Layout.fillWidth: true
                                        }

                                        TableHeaderCell {
                                            label: "Non-Blank"
                                            Layout.preferredWidth: 130
                                        }

                                        TableHeaderCell {
                                            label: "Blank"
                                            Layout.preferredWidth: 110
                                        }

                                        TableHeaderCell {
                                            label: "Unique"
                                            Layout.preferredWidth: 110
                                        }

                                        TableHeaderCell {
                                            label: "Duplicate Values"
                                            Layout.preferredWidth: 140
                                        }
                                    }

                                    ListView {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        clip: true
                                        spacing: 1

                                        model: healthColumnModel

                                        delegate: Rectangle {
                                            width: ListView.view.width
                                            height: 34

                                            color:
                                                index % 2 === 0
                                                ? "#0b1829"
                                                : "#0d1b2e"

                                            RowLayout {
                                                anchors.fill: parent

                                                Text {
                                                    text: columnName
                                                    color: textPrimary
                                                    leftPadding: 10

                                                    Layout.fillWidth: true

                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    text: nonBlankCount
                                                    color: success
                                                    leftPadding: 10

                                                    Layout.preferredWidth: 130
                                                }

                                                Text {
                                                    text: blankCount
                                                    color:
                                                        Number(blankCount) > 0
                                                        ? warning
                                                        : textSecondary

                                                    leftPadding: 10

                                                    Layout.preferredWidth: 110
                                                }

                                                Text {
                                                    text: uniqueCount
                                                    color: textSecondary
                                                    leftPadding: 10

                                                    Layout.preferredWidth: 110
                                                }

                                                Text {
                                                    text: duplicateCount
                                                    color: textSecondary
                                                    leftPadding: 10

                                                    Layout.preferredWidth: 140
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

            // ====================================================
            // EXPLORE & ANALYZE
            // ====================================================

            Item {
                ScrollView {
                    anchors.fill: parent
                    contentWidth: availableWidth

                    ColumnLayout {
                        width: parent.width

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 28

                        spacing: 16

                        PageHeading {
                            titleText: "Explore & Analyze"

                            subtitleText:
                                "Explore a local dataset, perform SQL analysis and export the resulting data."
                        }

                        SectionCard {
                            Layout.fillWidth: true
                            implicitHeight: 120

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 18

                                ColumnLayout {
                                    Layout.fillWidth: true

                                    SectionTitle {
                                        text:
                                            root.analysisPath
                                            ? root.fileName(root.analysisPath)
                                            : "Analysis Dataset"
                                    }

                                    MutedText {
                                        text:
                                            root.analysisPath
                                            ? "Ready for local analysis"
                                            : "Load a dataset to begin."
                                    }
                                }

                                AppButton {
                                    text: "Load Dataset"

                                    onClicked:
                                        analysisDialog.open()
                                }

                                AppButton {
                                    text: "Export Data"

                                    enabled:
                                        root.analysisPath !== ""

                                    onClicked:
                                        dataExportDialog.open()
                                }
                            }
                        }

                        SectionCard {
                            Layout.fillWidth: true
                            implicitHeight: 225

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 18

                                spacing: 10

                                SectionTitle {
                                    text: "SQL Workspace"
                                }

                                MutedText {
                                    text:
                                        "The loaded dataset is available as the table named data. Example: SELECT * FROM data LIMIT 100"
                                }

                                TextArea {
                                    id: sqlEditor

                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    placeholderText:
                                        "SELECT * FROM data LIMIT 100"

                                    color: textPrimary

                                    background: Rectangle {
                                        radius: 7
                                        color: "#071321"
                                        border.color: border
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    AppButton {
                                        text: "Run SQL"
                                        primaryButton: true

                                        enabled:
                                            root.analysisPath !== ""
                                            && sqlEditor.text.trim() !== ""

                                        onClicked:
                                            backend.runSQL(
                                                sqlEditor.text
                                            )
                                    }
                                }
                            }
                        }

                        SectionCard {
                            Layout.fillWidth: true
                            implicitHeight: 450

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 18

                                spacing: 12

                                RowLayout {
                                    Layout.fillWidth: true

                                    SectionTitle {
                                        text: "Query Results"
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    MutedText {
                                        text:
                                            sqlResultModel.count
                                            + " row(s)"
                                    }
                                }

                                Text {
                                    visible:
                                        sqlResultModel.count === 0

                                    text:
                                        "Run a SQL query to view matching records."

                                    color: textSecondary
                                }

                                ListView {
                                    visible:
                                        sqlResultModel.count > 0

                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    model: sqlResultModel

                                    clip: true
                                    spacing: 1

                                    delegate: Rectangle {
                                        width: ListView.view.width
                                        height: 44

                                        color:
                                            index % 2 === 0
                                            ? "#0b1829"
                                            : "#0d1b2e"

                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 10

                                            text:
                                                JSON.stringify(rowData)

                                            color: "#cbd5e1"
                                            font.pixelSize: 11

                                            verticalAlignment:
                                                Text.AlignVCenter

                                            elide:
                                                Text.ElideRight
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

    // ============================================================
    // STATUS BAR
    // ============================================================

    footer: Rectangle {
        height: 30
        color: "#081321"
        border.color: border

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14

            Text {
                text: backend.message
                color: textSecondary
                font.pixelSize: 10

                Layout.fillWidth: true

                elide: Text.ElideRight
            }

            ProgressBar {
                visible: backend.busy

                from: 0
                to: 100
                value: backend.progress

                Layout.preferredWidth: 160
            }

            Text {
                text: "Store Data Assistant 6.1"
                color: textMuted
                font.pixelSize: 9
            }
        }
    }
}
