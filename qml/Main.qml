import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

ApplicationWindow {
    id: root

    visible: true
    width: 1500
    height: 920
    minimumWidth: 1150
    minimumHeight: 700

    title: "StoreLens"
    color: "#07111f"

    property color fg: "#f8fafc"
    property color muted: "#8fa8c5"
    property color panel: "#0d1b2d"
    property color panel2: "#13243a"
    property color borderColor: "#29415f"
    property color blue: "#3b82f6"
    property color green: "#22c55e"
    property color amber: "#f59e0b"
    property color red: "#ef4444"

    property int page: 0

    property string masterPath: ""
    property string uploadPath: ""
    property string repairPath: ""
    property string reviewPath: ""
    property string datasetPath: ""

    property int selectedCompareRow: -1
    property bool differencesOnly: true

    property var detectedKeys: []
    property var datasetColumns: []
    property var health: ({})

    property int compareTotal: 0
    property int compareCorrect: 0
    property int compareReview: 0
    property int compareErrors: 0

    property int reviewRecords: 0
    property int reviewAttention: 0

    property int repairRecords: 0
    property int repairExpected: 0
    property int repairHealthy: 0
    property int repairFixed: 0
    property int repairReview: 0

    property int creatorRows: 10
    property var creatorHeaders: [
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

    ListModel { id: compareRows }
    ListModel { id: compareDetails }
    ListModel { id: repairRows }
    ListModel { id: reviewRows }
    ListModel { id: healthRows }
    ListModel { id: statsRows }
    ListModel { id: exploreRows }

    ListModel { id: creatorRowsModel }

    property string statsColumn: ""
    property string statsOperation: "Count"
    property string statsGroup: ""

    function fileName(path) {
        var p = String(path || "").replace(/\\/g, "/").split("/")
        return p.length ? p[p.length - 1] : ""
    }

    function statusColor(status) {
        var s = String(status || "").toUpperCase()

        if (s === "ERROR" || s === "UNRESOLVED")
            return root.red

        if (s === "REVIEW" || s === "REPAIRED" || s === "DIFFERENT")
            return root.amber

        return root.green
    }

    function statusBackground(status) {
        var s = String(status || "").toUpperCase()

        if (s === "ERROR" || s === "UNRESOLVED")
            return "#3b1820"

        if (s === "REVIEW" || s === "REPAIRED" || s === "DIFFERENT")
            return "#3a3017"

        return "#123427"
    }

    function safeValue(value) {
        if (value === undefined || value === null)
            return ""

        return String(value)
    }

    function initializeCreatorRows(count) {
        creatorRowsModel.clear()

        for (var i = 0; i < count; ++i) {
            var row = {
                checked: true,
                rowNumber: i + 1
            }

            for (var c = 0; c < creatorHeaders.length; ++c)
                row["c" + c] = ""

            creatorRowsModel.append(row)
        }
    }

    function addCreatorRow() {
        var row = {
            checked: true,
            rowNumber: creatorRowsModel.count + 1
        }

        for (var c = 0; c < creatorHeaders.length; ++c)
            row["c" + c] = ""

        creatorRowsModel.append(row)
    }

    function creatorRowsJson() {
        var output = []

        for (var i = 0; i < creatorRowsModel.count; ++i) {
            var source = creatorRowsModel.get(i)

            if (!source.checked)
                continue

            var row = {}

            for (var c = 0; c < creatorHeaders.length; ++c)
                row[creatorHeaders[c]] = source["c" + c]

            output.push(row)
        }

        return JSON.stringify(output)
    }

    function clearCreatorRows() {
        initializeCreatorRows(10)
    }

    Component.onCompleted: {
        initializeCreatorRows(10)
    }

    FileDialog {
        id: masterDialog

        title: "Choose Master File"

        nameFilters: [
            "Supported Data (*.csv *.xlsx *.xls *.xlsm *.txt *.tsv *.json *.xml)"
        ]

        onAccepted: {
            root.masterPath = selectedFile.toString()
            backend.loadMaster(root.masterPath)
        }
    }

    FileDialog {
        id: uploadDialog

        title: "Choose Uploaded / Country File"

        nameFilters: [
            "Supported Data (*.csv *.xlsx *.xls *.xlsm *.txt *.tsv *.json *.xml)"
        ]

        onAccepted: {
            root.uploadPath = selectedFile.toString()
            backend.loadUpload(root.uploadPath)
        }
    }

    FileDialog {
        id: repairDialog

        title: "Choose CSV / Text File"

        nameFilters: [
            "CSV / Text (*.csv *.txt *.tsv)"
        ]

        onAccepted: {
            root.repairPath = selectedFile.toString()
            backend.inspectRepair(root.repairPath)
        }
    }

    FileDialog {
        id: reviewDialog

        title: "Choose File for Review"

        nameFilters: [
            "Supported Data (*.csv *.xlsx *.xls *.xlsm *.txt *.tsv *.json *.xml)"
        ]

        onAccepted: {
            root.reviewPath = selectedFile.toString()
            backend.reviewSingleFile(root.reviewPath)
        }
    }

    FileDialog {
        id: datasetDialog

        title: "Choose Dataset"

        nameFilters: [
            "Supported Data (*.csv *.xlsx *.xls *.xlsm *.txt *.tsv *.json *.xml)"
        ]

        onAccepted: {
            root.datasetPath = selectedFile.toString()
            backend.loadData(root.datasetPath)
        }
    }

    FileDialog {
        id: repairSaveDialog

        title: "Save Repaired Copy"
        fileMode: FileDialog.SaveFile

        nameFilters: [
            "CSV (*.csv)"
        ]

        onAccepted: {
            backend.repair(root.repairPath, selectedFile.toString())
        }
    }

    FileDialog {
        id: reviewSaveDialog

        title: "Export Reviewed Copy"
        fileMode: FileDialog.SaveFile

        nameFilters: [
            "CSV (*.csv)"
        ]

        onAccepted: {
            backend.exportSingleReview(root.reviewPath, selectedFile.toString())
        }
    }

    FileDialog {
        id: healthReportDialog

        title: "Export Health Report"
        fileMode: FileDialog.SaveFile

        nameFilters: [
            "HTML Report (*.html)"
        ]

        onAccepted: {
            backend.exportHealthReport(selectedFile.toString())
        }
    }

    FileDialog {
        id: creatorLoadDialog

        title: "Import Store File"

        nameFilters: [
            "Supported Data (*.csv *.xlsx *.xls *.xlsm *.txt *.tsv *.json *.xml)"
        ]

        onAccepted: {
            backend.loadCreatorFile(selectedFile.toString())
        }
    }

    FileDialog {
        id: creatorExportDialog

        title: "Export Store CSV"
        fileMode: FileDialog.SaveFile

        nameFilters: [
            "CSV (*.csv)"
        ]

        onAccepted: {
            backend.exportCreator(root.creatorRowsJson(), selectedFile.toString())
        }
    }

    Connections {
        target: backend

        function onCreatorReady(payload) {
            try {
                var data = JSON.parse(payload)
                creatorValidationText.text = ""

                if (data.findings && data.findings.length > 0) {
                    var lines = []

                    for (var i = 0; i < data.findings.length; ++i) {
                        var f = data.findings[i]
                        lines.push(
                            "Row " +
                            String(f.row || "") +
                            ": " +
                            String(f.message || f.issue || "")
                        )
                    }

                    creatorValidationText.text = lines.join("\n")
                    creatorValidationTitle.text =
                        "Validation Feedback — " +
                        String(data.findings.length) +
                        " finding(s)"
                } else {
                    creatorValidationTitle.text = "Validation Feedback"
                    creatorValidationText.text =
                        "✓ All selected rows passed validation."
                }
            } catch (e) {
                creatorValidationText.text = payload
            }
        }

        function onCreatorLoaded(payload) {
            try {
                var data = JSON.parse(payload)

                creatorRowsModel.clear()

                var rows = data.rows || []

                for (var i = 0; i < rows.length; ++i) {
                    var source = rows[i]
                    var item = {
                        checked: true,
                        rowNumber: i + 1
                    }

                    for (var c = 0; c < creatorHeaders.length; ++c) {
                        var field = creatorHeaders[c]
                        item["c" + c] =
                            source[field] === undefined ||
                            source[field] === null
                            ? ""
                            : String(source[field])
                    }

                    creatorRowsModel.append(item)
                }

                if (creatorRowsModel.count === 0)
                    initializeCreatorRows(10)
            } catch (e) {
                backend.notify(
                    "Import Error",
                    "Unable to populate the Store Builder grid.",
                    "error"
                )
            }
        }

        function onMappingReady(payload) {
            try {
                var data = JSON.parse(payload)
                root.detectedKeys = data.suggestedKeys || []
            } catch (e) {
                root.detectedKeys = []
            }

            key1Combo.model = root.detectedKeys.length > 0
                ? root.detectedKeys
                : ["SID"]

            key2Combo.model = root.detectedKeys.length > 1
                ? ["(None)"].concat(root.detectedKeys)
                : ["(None)", "Nielsen Store Code"]

            if (root.detectedKeys.length > 0)
                key1Combo.currentIndex = 0

            if (root.detectedKeys.length > 1)
                key2Combo.currentIndex = 1
            else
                key2Combo.currentIndex = 0
        }

        function onValidationReady(payload) {
            try {
                var data = JSON.parse(payload)

                root.compareTotal = Number(data.total || 0)
                root.compareCorrect = Number(data.correct || 0)
                root.compareReview = Number(data.review || 0)
                root.compareErrors = Number(data.errors || 0)

                compareRows.clear()
                compareDetails.clear()
                root.selectedCompareRow = -1

                var rows = data.rows || data.results || []

                for (var i = 0; i < rows.length; ++i) {
                    var item = rows[i]

                    compareRows.append({
                        rowValue: String(item.row || i + 1),
                        sidValue: String(item.sid || ""),
                        storeValue: String(item.storeName || ""),
                        statusValue: String(item.status || ""),
                        problemValue: String(
                            item.problem ||
                            item.message ||
                            item.summary ||
                            ""
                        )
                    })
                }
            } catch (e) {
                backend.notify(
                    "Validation Error",
                    "The validation result could not be displayed.",
                    "error"
                )
            }
        }

        function onDetailReady(payload) {
            try {
                var data = JSON.parse(payload)

                compareDetails.clear()

                var rows = data.rows || data.details || []

                for (var i = 0; i < rows.length; ++i) {
                    var item = rows[i]

                    var severity =
                        String(
                            item.severity ||
                            item.status ||
                            item.result ||
                            ""
                        )

                    if (
                        root.differencesOnly &&
                        String(item.result || "").toUpperCase() === "MATCH"
                    ) {
                        continue
                    }

                    compareDetails.append({
                        fieldValue: String(item.field || ""),
                        masterValue: String(
                            item.master === undefined ||
                            item.master === null
                            ? ""
                            : item.master
                        ),
                        uploadValue: String(
                            item.uploaded === undefined ||
                            item.uploaded === null
                            ? ""
                            : item.uploaded
                        ),
                        resultValue: String(item.result || ""),
                        severityValue: severity
                    })
                }
            } catch (e) {
                compareDetails.clear()
            }
        }

        function onRepairReady(payload) {
            try {
                var data = JSON.parse(payload)

                var issues = data.issues || data.problems || []

                repairRows.clear()

                root.repairRecords = Number(
                    data.recordCount ||
                    data.records ||
                    data.totalRecords ||
                    0
                )

                root.repairExpected = Number(
                    data.expectedColumns ||
                    data.expectedFields ||
                    0
                )

                root.repairHealthy = Number(
                    data.healthy ||
                    data.healthyCount ||
                    0
                )

                root.repairFixed = Number(
                    data.autoFixed ||
                    data.fixed ||
                    data.repaired ||
                    0
                )

                root.repairReview = Number(
                    data.needsReview ||
                    data.review ||
                    issues.length ||
                    0
                )

                for (var i = 0; i < issues.length; ++i) {
                    var item = issues[i]

                    repairRows.append({
                        issueIndex: i,
                        lineValue: String(
                            item.line ||
                            item.record ||
                            item.row ||
                            ""
                        ),
                        expectedValue: String(
                            item.expectedColumns ||
                            item.expected ||
                            ""
                        ),
                        actualValue: String(
                            item.actualColumns ||
                            item.actual ||
                            ""
                        ),
                        statusValue: String(
                            item.status ||
                            item.severity ||
                            "REVIEW"
                        ),
                        repairValue: String(
                            item.repair ||
                            item.diagnosis ||
                            item.message ||
                            ""
                        ),
                        contentValue: String(
                            item.content ||
                            item.original ||
                            item.raw ||
                            ""
                        )
                    })
                }
            } catch (e) {
                repairRows.clear()
            }
        }

        function onSingleReviewReady(payload) {
            try {
                var data = JSON.parse(payload)

                root.reviewRecords = Number(
                    data.totalRecords ||
                    data.recordCount ||
                    0
                )

                root.reviewAttention = Number(
                    data.attentionCount ||
                    data.issueCount ||
                    0
                )

                reviewRows.clear()

                var findings = data.findings || []

                for (var i = 0; i < findings.length; ++i) {
                    var item = findings[i]

                    reviewRows.append({
                        messageValue: String(
                            item.message ||
                            item.issue ||
                            item
                        )
                    })
                }

                reviewPreviewColumns.model =
                    data.previewColumns || []

                reviewPreviewModel.clear()

                var previewRows = data.previewRows || []

                for (var r = 0; r < previewRows.length; ++r) {
                    var row = previewRows[r]
                    reviewPreviewModel.append({
                        rowJson: JSON.stringify(row)
                    })
                }
            } catch (e) {
                reviewRows.clear()
            }
        }

        function onHealthReady(payload) {
            try {
                var data = JSON.parse(payload)

                root.health = data

                root.datasetColumns =
                    data.columnNames ||
                    data.columns ||
                    []

                healthRows.clear()

                var columns =
                    data.columnStats ||
                    data.columnsStats ||
                    []

                for (var i = 0; i < columns.length; ++i) {
                    var item = columns[i]

                    healthRows.append({
                        columnValue: String(item.column || ""),
                        nonBlankValue: String(
                            item.nonBlank ||
                            item.non_blank ||
                            0
                        ),
                        blankValue: String(
                            item.blank ||
                            0
                        ),
                        uniqueValue: String(
                            item.unique ||
                            0
                        ),
                        duplicateValue: String(
                            item.duplicateValues ||
                            item.duplicates ||
                            0
                        ),
                        numericValue: String(
                            item.numericCount ||
                            item.numeric ||
                            0
                        )
                    })
                }

                statColumnCombo.model = root.datasetColumns
                statGroupCombo.model =
                    ["(None)"].concat(root.datasetColumns)
                exploreColumnCombo.model =
                    ["All columns"].concat(root.datasetColumns)
            } catch (e) {
                root.health = ({})
            }
        }

        function onStatsReady(payload) {
            try {
                var data = JSON.parse(payload)

                statsRows.clear()

                var rows = data.rows || []

                if (rows.length === 0 && data.value !== undefined) {
                    statsRows.append({
                        groupValue: "Overall",
                        resultValue: String(data.value)
                    })
                }

                for (var i = 0; i < rows.length; ++i) {
                    var item = rows[i]

                    statsRows.append({
                        groupValue: String(
                            item.group ||
                            item.key ||
                            "Overall"
                        ),
                        resultValue: String(
                            item.value === undefined
                            ? ""
                            : item.value
                        )
                    })
                }
            } catch (e) {
                statsRows.clear()
            }
        }

        function onTableReady(payload) {
            try {
                var data = JSON.parse(payload)

                exploreColumnsModel.clear()
                exploreRows.clear()

                var columns = data.columns || []

                for (var c = 0; c < columns.length; ++c) {
                    exploreColumnsModel.append({
                        columnName: String(columns[c])
                    })
                }

                var rows = data.rows || []

                for (var r = 0; r < rows.length; ++r) {
                    exploreRows.append({
                        rowJson: JSON.stringify(rows[r])
                    })
                }

                exploreResultInfo.text =
                    String(data.total || 0) +
                    " rows • showing " +
                    String(
                        data.displayed ||
                        rows.length
                    )
            } catch (e) {
                exploreRows.clear()
            }
        }
    }

    component Panel: Rectangle {
        radius: 10
        color: root.panel
        border.width: 1
        border.color: root.borderColor
    }

    component PageTitle: Text {
        color: root.fg
        font.pixelSize: 27
        font.bold: true
    }

    component Description: Text {
        color: root.muted
        font.pixelSize: 12
        wrapMode: Text.WordWrap
    }

    component StandardButton: Button {
        implicitHeight: 38

        palette.button: root.panel2
        palette.buttonText: root.fg

        contentItem: Text {
            text: parent.text
            color: root.fg
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            radius: 5
            color: parent.down
                   ? "#1a304c"
                   : root.panel2
            border.width: 1
            border.color: root.borderColor
        }
    }

    component PrimaryButton: Button {
        implicitHeight: 38

        palette.button: root.blue
        palette.buttonText: "white"

        font.bold: true

        contentItem: Text {
            text: parent.text
            color: "white"
            font.bold: true
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            radius: 5
            color: parent.enabled
                   ? (parent.down ? "#2869cf" : root.blue)
                   : "#26364b"
        }
    }

    component HeaderCell: Rectangle {
        property string label: ""

        implicitHeight: 34
        color: root.panel2

        Text {
            anchors.fill: parent
            anchors.margins: 8
            text: parent.label
            color: root.muted
            font.pixelSize: 10
            font.bold: true
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }

    component MetricCard: Panel {
        property string numberText: "0"
        property string labelText: ""
        property color numberColor: root.blue

        implicitHeight: 78

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 3

            Text {
                text: parent.parent.numberText
                color: parent.parent.numberColor
                font.pixelSize: 23
                font.bold: true
            }

            Text {
                text: parent.parent.labelText
                color: root.muted
                font.pixelSize: 9
                font.bold: true
            }
        }
    }

    component SectionTitle: Text {
        color: root.fg
        font.pixelSize: 14
        font.bold: true
    }

    header: Rectangle {
        height: 58
        color: "#081321"
        border.width: 1
        border.color: root.borderColor

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 13
            anchors.rightMargin: 13
            spacing: 10

            Rectangle {
                width: 36
                height: 36
                radius: 8
                color: root.blue

                Text {
                    anchors.centerIn: parent
                    text: "SL"
                    color: "white"
                    font.bold: true
                    font.pixelSize: 12
                }
            }

            Column {
                spacing: 1

                Text {
                    text: "StoreLens"
                    color: root.fg
                    font.pixelSize: 16
                    font.bold: true
                }

                Text {
                    text: "Local data quality, repair, comparison and analysis"
                    color: root.muted
                    font.pixelSize: 9
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: "● LOCAL ONLY"
                color: "#86efac"
                font.bold: true
                font.pixelSize: 10
            }
        }
    }

    footer: Rectangle {
        height: 30
        color: "#081321"
        border.width: 1
        border.color: root.borderColor

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12

            Text {
                text: backend.message
                color: root.muted
                font.pixelSize: 10
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: "StoreLens"
                color: root.muted
                font.pixelSize: 9
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.preferredWidth: 230
            Layout.fillHeight: true

            color: "#0b1728"
            border.width: 1
            border.color: root.borderColor

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 4

                Text {
                    text: "WORKSPACE"
                    color: root.muted
                    font.pixelSize: 9
                    font.bold: true
                    Layout.leftMargin: 8
                    Layout.topMargin: 8
                    Layout.bottomMargin: 6
                }

                Repeater {
                    model: [
                        "Dashboard",
                        "Compare & Validate",
                        "Record Repair",
                        "Single File Review",
                        "Create Store",
                        "Explore Data",
                        "Health & Statistics"
                    ]

                    delegate: Button {
                        required property string modelData
                        required property int index

                        Layout.fillWidth: true
                        implicitHeight: 42

                        text: modelData

                        contentItem: Text {
                            text: parent.text
                            color: root.fg
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 14
                        }

                        background: Rectangle {
                            radius: 4

                            color: root.page === index
                                   ? "#1d4f82"
                                   : "transparent"

                            border.width:
                                root.page === index ? 1 : 0

                            border.color: "#3169a0"
                        }

                        onClicked: root.page = index
                    }
                }

                Item {
                    Layout.fillHeight: true
                }

                Panel {
                    Layout.fillWidth: true
                    implicitHeight: 80

                    Column {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 4

                        Text {
                            text: "Local-first"
                            color: root.fg
                            font.bold: true
                            font.pixelSize: 10
                        }

                        Text {
                            width: parent.width
                            text: "Source files remain unchanged until an explicit export or save-copy action."
                            color: root.muted
                            font.pixelSize: 9
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }

        StackLayout {
            currentIndex: root.page

            Layout.fillWidth: true
            Layout.fillHeight: true

            /* =========================================================
               0 — DASHBOARD
               ========================================================= */

            Item {
                ScrollView {
                    anchors.fill: parent
                    contentWidth: availableWidth

                    ColumnLayout {
                        width: parent.width
                        spacing: 13

                        Item {
                            implicitHeight: 14
                        }

                        PageTitle {
                            text: "StoreLens Workspace"
                            Layout.leftMargin: 27
                            Layout.rightMargin: 27
                        }

                        Description {
                            text:
                                "Compare, repair, review, create, explore and analyze store datasets locally."
                            Layout.leftMargin: 27
                            Layout.rightMargin: 27
                            Layout.fillWidth: true
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 27
                            Layout.rightMargin: 27

                            columns: width > 1000 ? 2 : 1

                            columnSpacing: 12
                            rowSpacing: 12

                            Repeater {
                                model: [
                                    [
                                        "Compare & Validate",
                                        "Master vs uploaded store comparison with identity-based matching, duplicate detection and field-level inspection.",
                                        1
                                    ],
                                    [
                                        "Record Repair",
                                        "Inspect broken CSV/TXT structures, reconstruct shifted records and export a repaired copy.",
                                        2
                                    ],
                                    [
                                        "Single File Review",
                                        "Review one dataset without a Master file and identify quality and structural findings.",
                                        3
                                    ],
                                    [
                                        "Create Store",
                                        "Build standardized store records, validate the 14-column schema and export CSV.",
                                        4
                                    ],
                                    [
                                        "Explore Data",
                                        "Search records, inspect table results and run read-only SQL queries.",
                                        5
                                    ],
                                    [
                                        "Health & Statistics",
                                        "Profile dataset quality and run statistical operations with optional grouping.",
                                        6
                                    ]
                                ]

                                delegate: Panel {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    implicitHeight: 155

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 16
                                        spacing: 7

                                        Text {
                                            text: modelData[0]
                                            color: root.fg
                                            font.pixelSize: 16
                                            font.bold: true
                                        }

                                        Description {
                                            text: modelData[1]
                                            Layout.fillWidth: true
                                        }

                                        Item {
                                            Layout.fillHeight: true
                                        }

                                        PrimaryButton {
                                            text: "Open"
                                            onClicked: root.page = modelData[2]
                                        }
                                    }
                                }
                            }
                        }

                        Panel {
                            Layout.fillWidth: true
                            Layout.leftMargin: 27
                            Layout.rightMargin: 27
                            implicitHeight: 100

                            Column {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 6

                                Text {
                                    text: "Workflow"
                                    color: root.fg
                                    font.bold: true
                                    font.pixelSize: 13
                                }

                                Text {
                                    text:
                                        "Load → inspect → validate → repair → review → export"
                                    color: root.muted
                                    font.pixelSize: 11
                                }
                            }
                        }

                        Item {
                            implicitHeight: 20
                        }
                    }
                }
            }

            /* =========================================================
               1 — COMPARE & VALIDATE
               ========================================================= */

            Item {
                ScrollView {
                    anchors.fill: parent
                    contentWidth: availableWidth

                    ColumnLayout {
                        width: parent.width
                        spacing: 10

                        Item {
                            implicitHeight: 10
                        }

                        PageTitle {
                            text: "Compare & Validate"
                            Layout.leftMargin: 25
                            Layout.rightMargin: 25
                        }

                        Description {
                            text:
                                "Compare an uploaded or country file against the authoritative Master file. Matching is identity-based and does not depend on row order."
                            Layout.leftMargin: 25
                            Layout.rightMargin: 25
                            Layout.fillWidth: true
                        }

                        Panel {
                            Layout.fillWidth: true
                            Layout.leftMargin: 25
                            Layout.rightMargin: 25
                            implicitHeight: 150

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true

                                    TextField {
                                        Layout.fillWidth: true
                                        readOnly: true
                                        placeholderText: "Master file"
                                        text: root.fileName(root.masterPath)
                                    }

                                    StandardButton {
                                        text: "Browse"
                                        onClicked: masterDialog.open()
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true

                                    TextField {
                                        Layout.fillWidth: true
                                        readOnly: true
                                        placeholderText: "Uploaded / country file"
                                        text: root.fileName(root.uploadPath)
                                    }

                                    StandardButton {
                                        text: "Browse"
                                        onClicked: uploadDialog.open()
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        text: "Match by"
                                        color: root.muted
                                        font.pixelSize: 11
                                    }

                                    ComboBox {
                                        id: key1Combo
                                        Layout.preferredWidth: 190
                                        model: ["SID"]

                                        onCurrentTextChanged: {
                                            if (currentText === key2Combo.currentText)
                                                key2Combo.currentIndex = 0
                                        }
                                    }

                                    Text {
                                        text: "+"
                                        color: root.muted
                                        font.bold: true
                                    }

                                    ComboBox {
                                        id: key2Combo
                                        Layout.preferredWidth: 210
                                        model: [
                                            "(None)",
                                            "Nielsen Store Code"
                                        ]
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    StandardButton {
                                        text: "Detect Columns"
                                        enabled:
                                            root.masterPath !== "" &&
                                            root.uploadPath !== ""

                                        onClicked: backend.detect()
                                    }

                                    PrimaryButton {
                                        text: "Validate"
                                        enabled:
                                            root.masterPath !== "" &&
                                            root.uploadPath !== ""

                                        onClicked: {
                                            var keys = []

                                            if (key1Combo.currentText !== "")
                                                keys.push(key1Combo.currentText)

                                            if (
                                                key2Combo.currentText !== "" &&
                                                key2Combo.currentText !== "(None)" &&
                                                key2Combo.currentText !== key1Combo.currentText
                                            ) {
                                                keys.push(key2Combo.currentText)
                                            }

                                            backend.validate(
                                                JSON.stringify(keys)
                                            )
                                        }
                                    }
                                }
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 25
                            Layout.rightMargin: 25

                            columns: 4
                            columnSpacing: 8

                            MetricCard {
                                numberText: String(root.compareTotal)
                                labelText: "TOTAL"
                                Layout.fillWidth: true
                            }

                            MetricCard {
                                numberText: String(root.compareCorrect)
                                labelText: "CORRECT"
                                numberColor: root.green
                                Layout.fillWidth: true
                            }

                            MetricCard {
                                numberText: String(root.compareReview)
                                labelText: "REVIEW"
                                numberColor: root.amber
                                Layout.fillWidth: true
                            }

                            MetricCard {
                                numberText: String(root.compareErrors)
                                labelText: "ERROR"
                                numberColor: root.red
                                Layout.fillWidth: true
                            }
                        }

                        Panel {
                            Layout.fillWidth: true
                            Layout.leftMargin: 25
                            Layout.rightMargin: 25
                            implicitHeight: 330

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 11
                                spacing: 6

                                RowLayout {
                                    Layout.fillWidth: true

                                    SectionTitle {
                                        text: "Validation Results"
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    CheckBox {
                                        text: "Differences only"
                                        checked: root.differencesOnly

                                        contentItem: Text {
                                            text: parent.text
                                            color: root.muted
                                            font.pixelSize: 10
                                            leftPadding: 6
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        onToggled: {
                                            root.differencesOnly = checked

                                            if (root.selectedCompareRow >= 0) {
                                                backend.detail(
                                                    root.selectedCompareRow,
                                                    checked
                                                )
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    HeaderCell {
                                        label: "Row"
                                        Layout.preferredWidth: 55
                                    }

                                    HeaderCell {
                                        label: "SID"
                                        Layout.preferredWidth: 115
                                    }

                                    HeaderCell {
                                        label: "Store Name"
                                        Layout.preferredWidth: 190
                                    }

                                    HeaderCell {
                                        label: "Status"
                                        Layout.preferredWidth: 90
                                    }

                                    HeaderCell {
                                        label: "Problem / Summary"
                                        Layout.fillWidth: true
                                    }
                                }

                                ListView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    model: compareRows
                                    clip: true

                                    delegate: Rectangle {
                                        required property int index
                                        required property string rowValue
                                        required property string sidValue
                                        required property string storeValue
                                        required property string statusValue
                                        required property string problemValue

                                        width: ListView.view.width
                                        height: 34

                                        color:
                                            root.selectedCompareRow === index
                                            ? "#17375f"
                                            : index % 2
                                            ? "#0d1b2e"
                                            : "#0b1829"

                                        MouseArea {
                                            anchors.fill: parent

                                            onClicked: {
                                                root.selectedCompareRow = index
                                                backend.detail(
                                                    index,
                                                    root.differencesOnly
                                                )
                                            }
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            spacing: 1

                                            Text {
                                                text: rowValue
                                                color: root.muted
                                                leftPadding: 7
                                                Layout.preferredWidth: 55
                                            }

                                            Text {
                                                text: sidValue
                                                color: root.fg
                                                leftPadding: 7
                                                Layout.preferredWidth: 115
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text: storeValue
                                                color: root.fg
                                                leftPadding: 7
                                                Layout.preferredWidth: 190
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text: statusValue
                                                color: root.statusColor(statusValue)
                                                font.bold: true
                                                leftPadding: 7
                                                Layout.preferredWidth: 90
                                            }

                                            Text {
                                                text: problemValue
                                                color: root.fg
                                                leftPadding: 7
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Panel {
                            Layout.fillWidth: true
                            Layout.leftMargin: 25
                            Layout.rightMargin: 25
                            implicitHeight: 360

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 11
                                spacing: 6

                                SectionTitle {
                                    text: root.selectedCompareRow >= 0
                                          ? "Error-aware Comparison Inspector"
                                          : "Comparison Inspector"
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    HeaderCell {
                                        label: "Field"
                                        Layout.preferredWidth: 190
                                    }

                                    HeaderCell {
                                        label: "Master Value"
                                        Layout.fillWidth: true
                                    }

                                    HeaderCell {
                                        label: "Uploaded / Updated Value"
                                        Layout.fillWidth: true
                                    }

                                    HeaderCell {
                                        label: "Result"
                                        Layout.preferredWidth: 120
                                    }
                                }

                                ListView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    model: compareDetails
                                    clip: true

                                    delegate: Rectangle {
                                        required property int index
                                        required property string fieldValue
                                        required property string masterValue
                                        required property string uploadValue
                                        required property string resultValue
                                        required property string severityValue

                                        width: ListView.view.width
                                        height: 35

                                        color: root.statusBackground(
                                            severityValue
                                        )

                                        RowLayout {
                                            anchors.fill: parent
                                            spacing: 1

                                            Text {
                                                text: fieldValue
                                                color: root.fg
                                                font.bold: true
                                                leftPadding: 7
                                                Layout.preferredWidth: 190
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text:
                                                    masterValue === ""
                                                    ? "—"
                                                    : masterValue
                                                color:
                                                    masterValue === ""
                                                    ? root.muted
                                                    : root.fg
                                                leftPadding: 7
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text:
                                                    uploadValue === ""
                                                    ? "—"
                                                    : uploadValue
                                                color:
                                                    uploadValue === ""
                                                    ? root.muted
                                                    : root.fg
                                                leftPadding: 7
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text: resultValue
                                                color:
                                                    root.statusColor(
                                                        severityValue
                                                    )
                                                font.bold: true
                                                leftPadding: 7
                                                Layout.preferredWidth: 120
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            implicitHeight: 20
                        }
                    }
                }
            }

            /* =========================================================
               2 — RECORD REPAIR
               ========================================================= */

            Item {
                ScrollView {
                    anchors.fill: parent
                    contentWidth: availableWidth

                    ColumnLayout {
                        width: parent.width
                        spacing: 10

                        Item {
                            implicitHeight: 10
                        }

                        PageTitle {
                            text: "Record Repair"
                            Layout.leftMargin: 25
                            Layout.rightMargin: 25
                        }

                        Description {
                            text:
                                "Detect broken delimited records, reconstruct shifted lines and resolve structural overflow without modifying the source file."
                            Layout.leftMargin: 25
                            Layout.rightMargin: 25
                            Layout.fillWidth: true
                        }

                        Panel {
                            Layout.fillWidth: true
                            Layout.leftMargin: 25
                            Layout.rightMargin: 25
                            implicitHeight: 90

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12

                                TextField {
                                    Layout.fillWidth: true
                                    readOnly: true
                                    placeholderText: "CSV / TXT / TSV file"
                                    text: root.fileName(root.repairPath)
                                }

                                StandardButton {
                                    text: "Choose File"
                                    onClicked: repairDialog.open()
                                }

                                StandardButton {
                                    text: "Undo Last Action"
                                    enabled: repairRows.count > 0
                                    onClicked: backend.undoRepairAction()
                                }

                                PrimaryButton {
                                    text: "Save Repaired Copy"
                                    enabled:
                                        root.repairPath !== ""

                                    onClicked:
                                        repairSaveDialog.open()
                                }
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 25
                            Layout.rightMargin: 25

                            columns: 5
                            columnSpacing: 7

                            MetricCard {
                                numberText: String(root.repairRecords)
                                labelText: "RECORDS"
                                Layout.fillWidth: true
                            }

                            MetricCard {
                                numberText: String(root.repairExpected)
                                labelText: "EXPECTED FIELDS"
                                Layout.fillWidth: true
                            }

                            MetricCard {
                                numberText: String(root.repairHealthy)
                                labelText: "HEALTHY"
                                numberColor: root.green
                                Layout.fillWidth: true
                            }

                            MetricCard {
                                numberText: String(root.repairFixed)
                                labelText: "AUTO FIXED"
                                numberColor: root.green
                                Layout.fillWidth: true
                            }

                            MetricCard {
                                numberText: String(root.repairReview)
                                labelText: "NEEDS REVIEW"
                                numberColor: root.amber
                                Layout.fillWidth: true
                            }
                        }

                        Panel {
                            Layout.fillWidth: true
                            Layout.leftMargin: 25
                            Layout.rightMargin: 25
                            implicitHeight: 350

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 11

                                SectionTitle {
                                    text:
                                        "Repair Queue — " +
                                        repairRows.count +
                                        " issue(s)"
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    HeaderCell {
                                        label: "Record"
                                        Layout.preferredWidth: 80
                                    }

                                    HeaderCell {
                                        label: "Expected"
                                        Layout.preferredWidth: 85
                                    }

                                    HeaderCell {
                                        label: "Actual"
                                        Layout.preferredWidth: 85
                                    }

                                    HeaderCell {
                                        label: "Status"
                                        Layout.preferredWidth: 105
                                    }

                                    HeaderCell {
                                        label: "Diagnosis"
                                        Layout.preferredWidth: 300
                                    }

                                    HeaderCell {
                                        label: "Original Information"
                                        Layout.fillWidth: true
                                    }
                                }

                                ListView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    model: repairRows
                                    clip: true

                                    delegate: Rectangle {
                                        required property int issueIndex
                                        required property string lineValue
                                        required property string expectedValue
                                        required property string actualValue
                                        required property string statusValue
                                        required property string repairValue
                                        required property string contentValue

                                        width: ListView.view.width
                                        height: 46

                                        color:
                                            root.statusBackground(
                                                statusValue
                                            )

                                        RowLayout {
                                            anchors.fill: parent
                                            spacing: 1

                                            Text {
                                                text: lineValue
                                                color: root.fg
                                                leftPadding: 7
                                                Layout.preferredWidth: 80
                                            }

                                            Text {
                                                text: expectedValue
                                                color: root.muted
                                                leftPadding: 7
                                                Layout.preferredWidth: 85
                                            }

                                            Text {
                                                text: actualValue
                                                color: root.red
                                                leftPadding: 7
                                                Layout.preferredWidth: 85
                                            }

                                            Text {
                                                text: statusValue
                                                color:
                                                    root.statusColor(
                                                        statusValue
                                                    )
                                                font.bold: true
                                                leftPadding: 7
                                                Layout.preferredWidth: 105
                                            }

                                            Text {
                                                text: repairValue
                                                color: root.fg
                                                leftPadding: 7
                                                Layout.preferredWidth: 300
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text: contentValue
                                                color: root.fg
                                                leftPadding: 7
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Panel {
                            visible: repairRows.count > 0
                            Layout.fillWidth: true
                            Layout.leftMargin: 25
                            Layout.rightMargin: 25
                            implicitHeight: 130

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 11

                                SectionTitle {
                                    text: "Repair Actions"
                                }

                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        text:
                                            "Select an issue from the Repair Queue above to apply reconstruction actions."
                                        color: root.muted
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                    }

                                    StandardButton {
                                        text: "Join Shifted Rows"
                                        enabled: repairRows.count > 0
                                        onClicked:
                                            backend.joinRepairRows(0)
                                    }

                                    StandardButton {
                                        text: "Keep Unresolved"
                                        enabled: repairRows.count > 0
                                        onClicked:
                                            backend.keepRepairUnresolved(
                                                0,
                                                0
                                            )
                                    }

                                    StandardButton {
                                        text: "Keep As-Is"
                                        enabled: repairRows.count > 0
                                        onClicked:
                                            backend.keepRepairIssue(0)
                                    }
                                }
                            }
                        }

                        Item {
                            implicitHeight: 20
                        }
                    }
                }
            }

            /* =========================================================
               3 — SINGLE FILE REVIEW
               ========================================================= */

            Item {
                ScrollView {
                    anchors.fill: parent
                    contentWidth: availableWidth

                    ColumnLayout {
                        width: parent.width
                        spacing: 10

                        Item {
                            implicitHeight: 10
                        }

                        PageTitle {
                            text: "Single File Review"
                            Layout.leftMargin: 25
                            Layout.rightMargin: 25
                        }

                        Description {
                            text:
                                "Analyze a dataset without a Master file and identify structural and data-quality findings."
                            Layout.leftMargin: 25
                            Layout.rightMargin: 25
                            Layout.fillWidth: true
                        }

                        Panel {
                            Layout.fillWidth: true
                            Layout.leftMargin: 25
                            Layout.rightMargin: 25
                            implicitHeight: 90

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12

                                TextField {
                                    Layout.fillWidth: true
                                    readOnly: true
                                    placeholderText: "Select file to inspect"
                                    text: root.fileName(root.reviewPath)
                                }

                                StandardButton {
                                    text: "Browse"
                                    onClicked: reviewDialog.open()
                                }

                                PrimaryButton {
                                    text: "Export Reviewed"
                                    enabled:
                                        root.reviewPath !== ""

                                    onClicked:
                                        reviewSaveDialog.open()
                                }
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 25
                            Layout.rightMargin: 25

                            columns: 2
                            columnSpacing: 8

                            MetricCard {
                                numberText: String(root.reviewRecords)
                                labelText: "TOTAL RECORDS"
                                Layout.fillWidth: true
                            }

                            MetricCard {
                                numberText: String(root.reviewAttention)
                                labelText: "ATTENTION FINDINGS"
                                numberColor:
                                    root.reviewAttention > 0
                                    ? root.amber
                                    : root.green
                                Layout.fillWidth: true
                            }
                        }

                        Panel {
                            Layout.fillWidth: true
                            Layout.leftMargin: 25
                            Layout.rightMargin: 25
                            implicitHeight: 350

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 11

                                RowLayout {
                                    Layout.fillWidth: true

                                    SectionTitle {
                                        text: "Data Preview"
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text:
                                            root.reviewPath === ""
                                            ? "No preview loaded"
                                            : root.fileName(
                                                root.reviewPath
                                              )
                                        color: root.muted
                                        font.pixelSize: 10
                                    }
                                }

                                RowLayout {
                                    visible:
                                        reviewPreviewColumns.count > 0
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Repeater {
                                        model: reviewPreviewColumns

                                        delegate: HeaderCell {
                                            required property var modelData

                                            label: String(modelData)
                                            Layout.preferredWidth: 160
                                        }
                                    }
                                }

                                ListView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    model: reviewPreviewModel

                                    delegate: Rectangle {
                                        required property string rowJson

                                        width: ListView.view.width
                                        height: 34

                                        color:
                                            index % 2
                                            ? "#0d1b2e"
                                            : "#0b1829"

                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 7

                                            text: rowJson
                                            color: root.fg
                                            font.pixelSize: 10

                                            verticalAlignment:
                                                Text.AlignVCenter

                                            elide:
                                                Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }

                        Panel {
                            Layout.fillWidth: true
                            Layout.leftMargin: 25
                            Layout.rightMargin: 25
                            implicitHeight: 230

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 11

                                RowLayout {
                                    Layout.fillWidth: true

                                    SectionTitle {
                                        text: "Quality Findings"
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text:
                                            reviewRows.count === 0
                                            ? "No findings"
                                            : reviewRows.count +
                                              " finding(s)"
                                        color:
                                            reviewRows.count === 0
                                            ? root.green
                                            : root.amber
                                        font.bold: true
                                    }
                                }

                                ListView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    model: reviewRows
                                    clip: true

                                    delegate: Rectangle {
                                        required property string messageValue

                                        width: ListView.view.width
                                        height: 34

                                        color:
                                            index % 2
                                            ? "#0d1b2e"
                                            : "#0b1829"

                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            text: "• " + messageValue
                                            color: root.amber
                                            font.pixelSize: 10
                                            verticalAlignment:
                                                Text.AlignVCenter
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            implicitHeight: 20
                        }
                    }
                }
            }

            /* =========================================================
               4 — CREATE STORE
               ========================================================= */

            Item {
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 9

                    RowLayout {
                        Layout.fillWidth: true

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            PageTitle {
                                text: "Create Store Record"
                            }

                            Description {
                                text:
                                    "Build, validate and export store records using the standardized 14-column StoreLens schema."
                                Layout.fillWidth: true
                            }
                        }

                        Rectangle {
                            width: 145
                            height: 36
                            radius: 18
                            color: "#0c3025"

                            Text {
                                anchors.centerIn: parent
                                text: "✓ READY"
                                color: "#86efac"
                                font.bold: true
                                font.pixelSize: 11
                            }
                        }
                    }

                    Panel {
                        Layout.fillWidth: true
                        implicitHeight: 72

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 7

                            StandardButton {
                                text: "Import File"
                                onClicked:
                                    creatorLoadDialog.open()
                            }

                            StandardButton {
                                text: "Add Row"
                                onClicked:
                                    addCreatorRow()
                            }

                            StandardButton {
                                text: "Select All"

                                onClicked: {
                                    for (
                                        var i = 0;
                                        i < creatorRowsModel.count;
                                        ++i
                                    ) {
                                        creatorRowsModel.setProperty(
                                            i,
                                            "checked",
                                            true
                                        )
                                    }
                                }
                            }

                            StandardButton {
                                text: "Deselect All"

                                onClicked: {
                                    for (
                                        var i = 0;
                                        i < creatorRowsModel.count;
                                        ++i
                                    ) {
                                        creatorRowsModel.setProperty(
                                            i,
                                            "checked",
                                            false
                                        )
                                    }
                                }
                            }

                            StandardButton {
                                text: "Clear"
                                onClicked:
                                    clearCreatorRows()
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Text {
                                text:
                                    creatorRowsModel.count +
                                    " rows • " +
                                    creatorHeaders.length +
                                    " fields"
                                color: root.muted
                                font.pixelSize: 10
                            }

                            StandardButton {
                                text: "Validate"

                                onClicked:
                                    backend.validateCreator(
                                        root.creatorRowsJson()
                                    )
                            }

                            PrimaryButton {
                                text: "Export CSV"

                                onClicked:
                                    creatorExportDialog.open()
                            }
                        }
                    }

                    Panel {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        clip: true

                        Flickable {
                            id: creatorFlick

                            anchors.fill: parent
                            anchors.margins: 8

                            clip: true

                            contentWidth:
                                Math.max(
                                    width,
                                    70 +
                                    65 +
                                    creatorHeaders.length * 175
                                )

                            contentHeight:
                                creatorTable.height

                            Column {
                                id: creatorTable

                                width: creatorFlick.contentWidth
                                spacing: 1

                                Row {
                                    width: parent.width
                                    height: 38

                                    Rectangle {
                                        width: 55
                                        height: parent.height
                                        color: root.panel2

                                        Text {
                                            anchors.centerIn: parent
                                            text: "USE"
                                            color: root.muted
                                            font.bold: true
                                            font.pixelSize: 10
                                        }
                                    }

                                    Rectangle {
                                        width: 45
                                        height: parent.height
                                        color: root.panel2

                                        Text {
                                            anchors.centerIn: parent
                                            text: "#"
                                            color: root.muted
                                            font.bold: true
                                            font.pixelSize: 10
                                        }
                                    }

                                    Repeater {
                                        model: creatorHeaders

                                        delegate: HeaderCell {
                                            required property var modelData

                                            width: 175
                                            height: 38
                                            label: String(modelData)
                                        }
                                    }
                                }

                                Repeater {
                                    model: creatorRowsModel

                                    delegate: Item {
                                        required property int index

                                        width: creatorTable.width
                                        height: 39

                                        Row {
                                            anchors.fill: parent
                                            spacing: 1

                                            Rectangle {
                                                width: 55
                                                height: parent.height

                                                color:
                                                    index % 2
                                                    ? "#0d1b2e"
                                                    : "#0b1829"

                                                CheckBox {
                                                    anchors.centerIn: parent
                                                    checked:
                                                        creatorRowsModel.get(
                                                            index
                                                        ).checked

                                                    onToggled:
                                                        creatorRowsModel.setProperty(
                                                            index,
                                                            "checked",
                                                            checked
                                                        )
                                                }
                                            }

                                            Rectangle {
                                                width: 45
                                                height: parent.height
                                                color:
                                                    index % 2
                                                    ? "#0d1b2e"
                                                    : "#0b1829"

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: index + 1
                                                    color: root.muted
                                                    font.pixelSize: 10
                                                }
                                            }

                                            Repeater {
                                                model: creatorHeaders.length

                                                delegate: Rectangle {
                                                    required property int index

                                                    width: 175
                                                    height: 39

                                                    color:
                                                        index % 2
                                                        ? "#0d1b2e"
                                                        : "#0b1829"

                                                    border.width: 1
                                                    border.color:
                                                        "#203751"

                                                    TextField {
                                                        anchors.fill: parent
                                                        anchors.margins: 2

                                                        text:
                                                            creatorRowsModel.get(
                                                                modelData
                                                            )["c" + index]

                                                        color: root.fg
                                                        font.pixelSize: 10

                                                        background:
                                                            Rectangle {
                                                                color:
                                                                    "transparent"
                                                            }

                                                        onEditingFinished:
                                                            creatorRowsModel.setProperty(
                                                                modelData,
                                                                "c" + index,
                                                                text
                                                            )
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            ScrollBar.horizontal: ScrollBar {}
                            ScrollBar.vertical: ScrollBar {}
                        }
                    }

                    Panel {
                        Layout.fillWidth: true
                        implicitHeight: 120

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 5

                            Text {
                                id: creatorValidationTitle

                                text: "Validation Feedback"
                                color: root.fg
                                font.bold: true
                                font.pixelSize: 12
                            }

                            TextArea {
                                id: creatorValidationText

                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                readOnly: true
                                wrapMode: TextEdit.Wrap

                                color: root.fg
                                font.pixelSize: 10

                                background:
                                    Rectangle {
                                        color: "#071321"
                                        radius: 5
                                        border.width: 1
                                        border.color: root.borderColor
                                    }
                            }
                        }
                    }
                }
            }

            /* =========================================================
               5 — EXPLORE DATA
               ========================================================= */

            Item {
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 9

                    RowLayout {
                        Layout.fillWidth: true

                        ColumnLayout {
                            Layout.fillWidth: true

                            PageTitle {
                                text: "Explore Data"
                            }

                            Description {
                                text:
                                    "Search, query and visually inspect the loaded dataset."
                                Layout.fillWidth: true
                            }
                        }

                        PrimaryButton {
                            text: "Load Dataset"
                            onClicked:
                                datasetDialog.open()
                        }
                    }

                    Panel {
                        Layout.fillWidth: true
                        implicitHeight: 125

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true

                                TextField {
                                    id: exploreSearch

                                    Layout.fillWidth: true
                                    placeholderText:
                                        "Quick search..."

                                    color: root.fg
                                }

                                ComboBox {
                                    id: exploreColumnCombo

                                    Layout.preferredWidth: 190

                                    model: [
                                        "All columns"
                                    ]
                                }

                                PrimaryButton {
                                    text: "Search"

                                    enabled:
                                        root.datasetPath !== ""

                                    onClicked: {
                                        backend.search(
                                            exploreSearch.text,
                                            exploreColumnCombo.currentIndex <= 0
                                            ? ""
                                            : exploreColumnCombo.currentText
                                        )
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true

                                TextArea {
                                    id: exploreSql

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 58

                                    text:
                                        "SELECT * FROM data LIMIT 100"

                                    color: root.fg

                                    wrapMode:
                                        TextEdit.NoWrap

                                    background:
                                        Rectangle {
                                            radius: 5
                                            color: "#071321"
                                            border.width: 1
                                            border.color:
                                                root.borderColor
                                        }
                                }

                                PrimaryButton {
                                    text: "Run SQL"

                                    enabled:
                                        root.datasetPath !== ""

                                    onClicked:
                                        backend.sql(
                                            exploreSql.text
                                        )
                                }
                            }
                        }
                    }

                    Panel {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 9

                            RowLayout {
                                Layout.fillWidth: true

                                SectionTitle {
                                    text: "Result Table"
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                Text {
                                    id: exploreResultInfo

                                    text: "0 rows"
                                    color: root.muted
                                    font.pixelSize: 10
                                }
                            }

                            Flickable {
                                id: exploreFlick

                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                clip: true

                                contentWidth:
                                    Math.max(
                                        width,
                                        exploreColumnsModel.count * 180
                                    )

                                contentHeight:
                                    exploreTable.height

                                Column {
                                    id: exploreTable

                                    width: exploreFlick.contentWidth
                                    spacing: 1

                                    Row {
                                        width: parent.width
                                        height: 34

                                        Repeater {
                                            model:
                                                exploreColumnsModel

                                            delegate: HeaderCell {
                                                required property string columnName

                                                width: 180
                                                height: 34
                                                label: columnName
                                            }
                                        }
                                    }

                                    Repeater {
                                        model: exploreRows

                                        delegate: Rectangle {
                                            required property string rowJson

                                            width: exploreTable.width
                                            height: 34

                                            color:
                                                index % 2
                                                ? "#0d1b2e"
                                                : "#0b1829"

                                            Text {
                                                anchors.fill: parent
                                                anchors.margins: 7

                                                text: rowJson
                                                color: root.fg
                                                font.pixelSize: 10

                                                verticalAlignment:
                                                    Text.AlignVCenter

                                                elide:
                                                    Text.ElideRight
                                            }
                                        }
                                    }
                                }

                                ScrollBar.horizontal: ScrollBar {}
                                ScrollBar.vertical: ScrollBar {}
                            }
                        }
                    }
                }
            }

            /* =========================================================
               6 — HEALTH & STATISTICS
               ========================================================= */

            Item {
                ScrollView {
                    anchors.fill: parent
                    contentWidth: availableWidth

                    ColumnLayout {
                        width: parent.width
                        spacing: 10

                        Item {
                            implicitHeight: 10
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 25
                            Layout.rightMargin: 25

                            ColumnLayout {
                                Layout.fillWidth: true

                                PageTitle {
                                    text: "Health & Statistics"
                                }

                                Description {
                                    text:
                                        "Profile dataset health and run statistical operations."
                                    Layout.fillWidth: true
                                }
                            }

                            StandardButton {
                                text: "Export Report"

                                enabled:
                                    root.datasetPath !== ""

                                onClicked:
                                    healthReportDialog.open()
                            }
                        }

                        Panel {
                            Layout.fillWidth: true
                            Layout.leftMargin: 25
                            Layout.rightMargin: 25
                            implicitHeight: 105

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12

                                PrimaryButton {
                                    text: "Load Dataset"

                                    onClicked:
                                        datasetDialog.open()
                                }

                                Text {
                                    text:
                                        root.datasetPath !== ""
                                        ? root.fileName(
                                            root.datasetPath
                                          )
                                        : "No dataset loaded"

                                    color: root.fg
                                    font.bold: true
                                    Layout.fillWidth: true
                                    elide: Text.ElideMiddle
                                }
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 25
                            Layout.rightMargin: 25

                            columns: 5
                            columnSpacing: 7

                            MetricCard {
                                numberText:
                                    root.health.rows !== undefined
                                    ? String(root.health.rows)
                                    : "0"
                                labelText: "ROWS"
                                Layout.fillWidth: true
                            }

                            MetricCard {
                                numberText:
                                    root.health.columns !== undefined
                                    ? String(root.health.columns)
                                    : "0"
                                labelText: "COLUMNS"
                                Layout.fillWidth: true
                            }

                            MetricCard {
                                numberText:
                                    root.health.completeness !== undefined
                                    ? String(
                                        root.health.completeness
                                      ) + "%"
                                    : "0%"
                                labelText: "COMPLETENESS"
                                numberColor: root.green
                                Layout.fillWidth: true
                            }

                            MetricCard {
                                numberText:
                                    root.health.duplicateRows !== undefined
                                    ? String(
                                        root.health.duplicateRows
                                      )
                                    : "0"
                                labelText: "DUPLICATES"
                                numberColor: root.amber
                                Layout.fillWidth: true
                            }

                            MetricCard {
                                numberText:
                                    root.health.healthScore !== undefined
                                    ? String(
                                        root.health.healthScore
                                      ) + "/100"
                                    : "0/100"
                                labelText: "HEALTH"
                                numberColor: root.green
                                Layout.fillWidth: true
                            }
                        }

                        Panel {
                            Layout.fillWidth: true
                            Layout.leftMargin: 25
                            Layout.rightMargin: 25
                            implicitHeight: 390

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10

                                SectionTitle {
                                    text: "Column Quality"
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    HeaderCell {
                                        label: "Column"
                                        Layout.fillWidth: true
                                    }

                                    HeaderCell {
                                        label: "Type"
                                        Layout.preferredWidth: 100
                                    }

                                    HeaderCell {
                                        label: "Non-Blank"
                                        Layout.preferredWidth: 95
                                    }

                                    HeaderCell {
                                        label: "Blank"
                                        Layout.preferredWidth: 75
                                    }

                                    HeaderCell {
                                        label: "Unique"
                                        Layout.preferredWidth: 75
                                    }

                                    HeaderCell {
                                        label: "Duplicate"
                                        Layout.preferredWidth: 90
                                    }

                                    HeaderCell {
                                        label: "Numeric"
                                        Layout.preferredWidth: 80
                                    }
                                }

                                ListView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    model: healthRows
                                    clip: true

                                    delegate: Rectangle {
                                        required property int index
                                        required property string columnValue
                                        required property string nonBlankValue
                                        required property string blankValue
                                        required property string uniqueValue
                                        required property string duplicateValue
                                        required property string numericValue

                                        width: ListView.view.width
                                        height: 32

                                        color:
                                            index % 2
                                            ? "#0d1b2e"
                                            : "#0b1829"

                                        RowLayout {
                                            anchors.fill: parent
                                            spacing: 1

                                            Text {
                                                text: columnValue
                                                color: root.fg
                                                leftPadding: 7
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text: "—"
                                                color: root.muted
                                                Layout.preferredWidth: 100
                                            }

                                            Text {
                                                text: nonBlankValue
                                                color: root.green
                                                Layout.preferredWidth: 95
                                            }

                                            Text {
                                                text: blankValue
                                                color:
                                                    Number(blankValue) > 0
                                                    ? root.amber
                                                    : root.muted
                                                Layout.preferredWidth: 75
                                            }

                                            Text {
                                                text: uniqueValue
                                                color: root.muted
                                                Layout.preferredWidth: 75
                                            }

                                            Text {
                                                text: duplicateValue
                                                color: root.muted
                                                Layout.preferredWidth: 90
                                            }

                                            Text {
                                                text: numericValue
                                                color: root.muted
                                                Layout.preferredWidth: 80
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Panel {
                            Layout.fillWidth: true
                            Layout.leftMargin: 25
                            Layout.rightMargin: 25
                            implicitHeight: 300

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10

                                SectionTitle {
                                    text: "Statistics Analysis"
                                }

                                RowLayout {
                                    Layout.fillWidth: true

                                    ComboBox {
                                        id: statColumnCombo

                                        Layout.fillWidth: true

                                        model: root.datasetColumns
                                    }

                                    ComboBox {
                                        id: statOperationCombo

                                        Layout.preferredWidth: 180

                                        model: [
                                            "Count",
                                            "Distinct Count",
                                            "Blank Count",
                                            "Sum",
                                            "Average",
                                            "Minimum",
                                            "Maximum",
                                            "Median",
                                            "Frequency Distribution",
                                            "Quick Summary",
                                            "IQR Outlier Detection"
                                        ]
                                    }

                                    ComboBox {
                                        id: statGroupCombo

                                        Layout.fillWidth: true

                                        model:
                                            ["(None)"].concat(
                                                root.datasetColumns
                                            )
                                    }

                                    PrimaryButton {
                                        text: "Calculate"

                                        enabled:
                                            root.datasetPath !== "" &&
                                            statColumnCombo.currentText !== ""

                                        onClicked: {
                                            backend.stats(
                                                statColumnCombo.currentText,
                                                statOperationCombo.currentText,
                                                statGroupCombo.currentIndex <= 0
                                                ? ""
                                                : statGroupCombo.currentText
                                            )
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    HeaderCell {
                                        label: "Value / Metric"
                                        Layout.fillWidth: true
                                    }

                                    HeaderCell {
                                        label: "Result"
                                        Layout.fillWidth: true
                                    }
                                }

                                ListView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    model: statsRows
                                    clip: true

                                    delegate: Rectangle {
                                        required property int index
                                        required property string groupValue
                                        required property string resultValue

                                        width: ListView.view.width
                                        height: 32

                                        color:
                                            index % 2
                                            ? "#0d1b2e"
                                            : "#0b1829"

                                        RowLayout {
                                            anchors.fill: parent
                                            spacing: 1

                                            Text {
                                                text: groupValue
                                                color: root.fg
                                                leftPadding: 7
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text: resultValue
                                                color: root.green
                                                leftPadding: 7
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            implicitHeight: 20
                        }
                    }
                }
            }
        }
    }

    ListModel {
        id: reviewPreviewColumns
    }

    ListModel {
        id: reviewPreviewModel
    }

    ListModel {
        id: exploreColumnsModel
    }
}
