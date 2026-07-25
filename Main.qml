import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

ApplicationWindow {
    id: root
    visible: true
    width: 1440
    height: 900
    minimumWidth: 1050
    minimumHeight: 680
    title: "Store Data Assistant 6.1"
    color: "#07111f"

    property color fg: "#f8fafc"
    property color muted: "#94a3b8"
    property color panel: "#0e1b2d"
    property color panel2: "#132238"
    property color borderColor: "#263850"
    property color blue: "#3b82f6"
    property color green: "#22c55e"
    property color amber: "#f59e0b"
    property color red: "#ef4444"

    property int page: 0
    property string masterPath: ""
    property string mappingPath: ""
    property string repairPath: ""
    property string analysisPath: ""

    property int total: 0
    property int correct: 0
    property int review: 0
    property int errors: 0

    property var health: ({})

    ListModel { id: mapRows }
    ListModel { id: valRows }
    ListModel { id: fixRows }
    ListModel { id: healthRows }
    ListModel { id: sqlRows }

    function fileName(path) {
        var parts = String(path || "").replace(/\\/g, "/").split("/")
        return parts.length ? parts[parts.length - 1] : ""
    }

    FileDialog {
        id: masterDialog
        title: "Choose Master File"
        nameFilters: ["Supported data (*.csv *.xlsx *.xls *.xlsm *.txt *.tsv *.json *.xml)"]
        onAccepted: {
            root.masterPath = selectedFile.toString()
            backend.loadMaster(root.masterPath)
        }
    }

    FileDialog {
        id: mappingDialog
        title: "Choose Mapping / Country File"
        nameFilters: ["Supported data (*.csv *.xlsx *.xls *.xlsm *.txt *.tsv *.json *.xml)"]
        onAccepted: {
            root.mappingPath = selectedFile.toString()
            backend.loadMapping(root.mappingPath)
        }
    }

    FileDialog {
        id: repairDialog
        title: "Choose CSV / Text File"
        nameFilters: ["CSV / Text (*.csv *.txt *.tsv)"]
        onAccepted: {
            root.repairPath = selectedFile.toString()
            backend.inspectCSV(root.repairPath)
        }
    }

    FileDialog {
        id: analysisDialog
        title: "Choose Dataset"
        nameFilters: ["Supported data (*.csv *.xlsx *.xls *.xlsm *.txt *.tsv *.json *.xml)"]
        onAccepted: {
            root.analysisPath = selectedFile.toString()
            backend.loadFile(root.analysisPath)
        }
    }

    FileDialog {
        id: repairSaveDialog
        title: "Save Repaired Copy"
        fileMode: FileDialog.SaveFile
        nameFilters: ["CSV (*.csv)"]
        onAccepted: backend.repairCSV(root.repairPath, selectedFile.toString())
    }

    FileDialog {
        id: reportSaveDialog
        title: "Export Validation Report"
        fileMode: FileDialog.SaveFile
        nameFilters: ["Excel (*.xlsx)", "CSV (*.csv)"]
        onAccepted: backend.exportValidationReport(selectedFile.toString())
    }

    FileDialog {
        id: dataSaveDialog
        title: "Export Dataset"
        fileMode: FileDialog.SaveFile
        nameFilters: ["Excel (*.xlsx)", "CSV (*.csv)", "JSON (*.json)"]
        onAccepted: backend.exportCurrentData(selectedFile.toString())
    }

    Connections {
        target: backend

        function onColumnMappingReady(payload) {
            var data = JSON.parse(payload)
            var fields = [
                "Store Name", "SID", "Banner", "Nielsen Store Code",
                "Trip Received", "Last Trip", "Address 1", "Address 2",
                "Address 3", "ZIP", "Active / Inactive", "Is Census",
                "Is Exceptions", "Updated By"
            ]

            mapRows.clear()

            for (var i = 0; i < fields.length; ++i) {
                var field = fields[i]
                var masterItem = data.master[field] || {}
                var mappingItem = data.mapping[field] || {}

                var masterConfidence = Number(masterItem.confidence || 0)
                var mappingConfidence = Number(mappingItem.confidence || 0)
                var confidence = 0

                if (masterConfidence > 0 && mappingConfidence > 0)
                    confidence = Math.min(masterConfidence, mappingConfidence)
                else
                    confidence = Math.max(masterConfidence, mappingConfidence)

                mapRows.append({
                    "field": field,
                    "masterColumn": String(masterItem.column || ""),
                    "mappingColumn": String(mappingItem.column || ""),
                    "confidenceValue": confidence
                })
            }
        }

        function onValidationReady(payload) {
            var data = JSON.parse(payload)

            root.total = Number(data.total || 0)
            root.correct = Number(data.correct || 0)
            root.review = Number(data.review || 0)
            root.errors = Number(data.errors || 0)

            valRows.clear()

            for (var i = 0; i < data.results.length; ++i) {
                var item = data.results[i]
                valRows.append({
                    "rowValue": String(item.row || ""),
                    "sidValue": String(item.sid || ""),
                    "storeValue": String(item.storeName || ""),
                    "statusValue": String(item.status || ""),
                    "problemValue": String(item.problem || "")
                })
            }
        }

        function onCsvInspectionReady(payload) {
            var data = JSON.parse(payload)
            fixRows.clear()

            for (var i = 0; i < data.problems.length; ++i) {
                var item = data.problems[i]
                fixRows.append({
                    "lineValue": String(item.line || ""),
                    "expectedValue": String(item.expectedColumns || ""),
                    "actualValue": String(item.actualColumns || ""),
                    "contentValue": String(item.content || "")
                })
            }
        }

        function onAnalysisReady(payload) {
            var data = JSON.parse(payload)
            root.health = data
            healthRows.clear()

            for (var i = 0; i < data.columnStats.length; ++i) {
                var item = data.columnStats[i]
                healthRows.append({
                    "columnValue": String(item.column || ""),
                    "blankValue": String(item.blank || 0),
                    "nonBlankValue": String(item.nonBlank || 0),
                    "uniqueValue": String(item.unique || 0),
                    "duplicateValue": String(item.duplicateValues || 0)
                })
            }
        }

        function onSqlResultReady(payload) {
            var data = JSON.parse(payload)
            sqlRows.clear()

            for (var i = 0; i < data.rows.length; ++i) {
                sqlRows.append({
                    "rowText": JSON.stringify(data.rows[i])
                })
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
        font.pixelSize: 24
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
    }

    component PrimaryButton: Button {
        implicitHeight: 38
        palette.button: root.blue
        palette.buttonText: "white"
        font.bold: true
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

        implicitHeight: 80

        Column {
            anchors.fill: parent
            anchors.margins: 13
            spacing: 5

            Text {
                text: parent.parent.numberText
                color: parent.parent.numberColor
                font.pixelSize: 23
                font.bold: true
            }

            Text {
                text: parent.parent.labelText
                color: root.muted
                font.pixelSize: 10
                font.bold: true
            }
        }
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
                width: 34
                height: 34
                radius: 8
                color: root.blue

                Text {
                    anchors.centerIn: parent
                    text: "DA"
                    color: "white"
                    font.bold: true
                }
            }

            Column {
                spacing: 1

                Text {
                    text: "Store Data Assistant"
                    color: root.fg
                    font.pixelSize: 15
                    font.bold: true
                }

                Text {
                    text: "Data validation, repair and analysis workspace"
                    color: root.muted
                    font.pixelSize: 9
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                width: 100
                height: 28
                radius: 14
                color: "#0c3025"
                border.color: "#1f6549"

                Text {
                    anchors.centerIn: parent
                    text: "●  LOCAL ONLY"
                    color: "#86efac"
                    font.pixelSize: 9
                    font.bold: true
                }
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
            spacing: 12

            Text {
                text: backend.message
                color: root.muted
                font.pixelSize: 10
                elide: Text.ElideRight
                Layout.fillWidth: true
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
                color: root.muted
                font.pixelSize: 9
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.preferredWidth: 210
            Layout.fillHeight: true
            color: "#0b1728"
            border.width: 1
            border.color: root.borderColor

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 5

                Text {
                    text: "WORKSPACE"
                    color: root.muted
                    font.pixelSize: 9
                    font.bold: true
                    Layout.leftMargin: 8
                    Layout.topMargin: 7
                    Layout.bottomMargin: 5
                }

                Repeater {
                    model: [
                        "Home",
                        "Compare & Validate",
                        "Repair CSV / Text",
                        "Data Health Check",
                        "Explore & Analyze"
                    ]

                    delegate: Button {
                        required property string modelData
                        required property int index

                        Layout.fillWidth: true
                        implicitHeight: 42
                        text: modelData
                        palette.button: root.page === index ? "#1d4777" : "#0b1728"
                        palette.buttonText: root.fg
                        onClicked: root.page = index
                    }
                }

                Item { Layout.fillHeight: true }

                Panel {
                    Layout.fillWidth: true
                    implicitHeight: 72

                    Column {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 5

                        Text {
                            text: "Privacy"
                            color: root.fg
                            font.bold: true
                            font.pixelSize: 10
                        }

                        Text {
                            width: parent.width
                            text: "Files are processed locally by the application."
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

            Item {
                ScrollView {
                    anchors.fill: parent
                    contentWidth: availableWidth

                    ColumnLayout {
                        width: parent.width
                        spacing: 15

                        Item { implicitHeight: 12 }

                        PageTitle {
                            text: "Welcome"
                            Layout.leftMargin: 25
                            Layout.rightMargin: 25
                        }

                        Description {
                            text: "Choose a workspace. Store comparison remains purpose-built, while repair and analysis can be used for other structured business data."
                            Layout.fillWidth: true
                            Layout.leftMargin: 25
                            Layout.rightMargin: 25
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 25
                            Layout.rightMargin: 25
                            columns: width > 1000 ? 2 : 1
                            columnSpacing: 12
                            rowSpacing: 12

                            Repeater {
                                model: [
                                    ["Compare & Validate", "Compare a country/store file against a trusted master and review only exceptions.", 1],
                                    ["Repair CSV / Text", "Find malformed records, show the affected line and preserve a repaired copy.", 2],
                                    ["Data Health Check", "Measure rows, columns, completeness, blanks, uniqueness and duplicates.", 3],
                                    ["Explore & Analyze", "Use read-only SQL for flexible local analysis and export the resulting dataset.", 4]
                                ]

                                delegate: Panel {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    implicitHeight: 140

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 16
                                        spacing: 8

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

                                        Item { Layout.fillHeight: true }

                                        PrimaryButton {
                                            text: "Open Workspace"
                                            onClicked: root.page = modelData[2]
                                        }
                                    }
                                }
                            }
                        }

                        Item { implicitHeight: 20 }
                    }
                }
            }

            Item {
                ScrollView {
                    anchors.fill: parent
                    contentWidth: availableWidth

                    ColumnLayout {
                        width: parent.width
                        spacing: 13

                        Item { implicitHeight: 10 }

                        PageTitle {
                            text: "Compare & Validate"
                            Layout.leftMargin: 23
                            Layout.rightMargin: 23
                        }

                        Description {
                            text: "Automatically map country-specific headers to the approved 14 standard fields, then compare records against the master."
                            Layout.fillWidth: true
                            Layout.leftMargin: 23
                            Layout.rightMargin: 23
                        }

                        Panel {
                            Layout.fillWidth: true
                            Layout.leftMargin: 23
                            Layout.rightMargin: 23
                            implicitHeight: 160

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 9

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
                                        placeholderText: "Mapping / country file"
                                        text: root.fileName(root.mappingPath)
                                    }

                                    StandardButton {
                                        text: "Browse"
                                        onClicked: mappingDialog.open()
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true

                                    StandardButton {
                                        text: "Detect Columns"
                                        enabled: root.masterPath !== "" && root.mappingPath !== ""
                                        onClicked: backend.detectStoreColumns()
                                    }

                                    PrimaryButton {
                                        text: "Validate Stores"
                                        Layout.fillWidth: true
                                        enabled: root.masterPath !== "" && root.mappingPath !== ""
                                        onClicked: backend.validateStores()
                                    }
                                }
                            }
                        }

                        Panel {
                            Layout.fillWidth: true
                            Layout.leftMargin: 23
                            Layout.rightMargin: 23
                            implicitHeight: 320

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 2

                                Text {
                                    text: "Smart Column Mapping"
                                    color: root.fg
                                    font.pixelSize: 14
                                    font.bold: true
                                    Layout.bottomMargin: 7
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    HeaderCell { label: "Standard Field"; Layout.preferredWidth: 190 }
                                    HeaderCell { label: "Master Column"; Layout.fillWidth: true }
                                    HeaderCell { label: "Mapping Column"; Layout.fillWidth: true }
                                    HeaderCell { label: "Confidence"; Layout.preferredWidth: 95 }
                                }

                                ListView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    model: mapRows
                                    clip: true

                                    delegate: Rectangle {
                                        required property int index
                                        required property string field
                                        required property string masterColumn
                                        required property string mappingColumn
                                        required property real confidenceValue

                                        width: ListView.view.width
                                        height: 28
                                        color: index % 2 ? "#0d1b2e" : "#0b1829"

                                        RowLayout {
                                            anchors.fill: parent
                                            spacing: 1

                                            Text {
                                                text: field
                                                color: root.fg
                                                leftPadding: 7
                                                Layout.preferredWidth: 190
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text: masterColumn !== "" ? masterColumn : "Not detected"
                                                color: masterColumn !== "" ? root.fg : root.red
                                                leftPadding: 7
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text: mappingColumn !== "" ? mappingColumn : "Not detected"
                                                color: mappingColumn !== "" ? root.fg : root.red
                                                leftPadding: 7
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text: Math.round(confidenceValue) + "%"
                                                color: confidenceValue >= 90 ? root.green :
                                                       confidenceValue >= 70 ? root.amber : root.red
                                                Layout.preferredWidth: 95
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 23
                            Layout.rightMargin: 23
                            columns: 4
                            columnSpacing: 9

                            MetricCard {
                                numberText: String(root.total)
                                labelText: "TOTAL"
                                Layout.fillWidth: true
                            }

                            MetricCard {
                                numberText: String(root.correct)
                                labelText: "CORRECT"
                                numberColor: root.green
                                Layout.fillWidth: true
                            }

                            MetricCard {
                                numberText: String(root.review)
                                labelText: "REVIEW"
                                numberColor: root.amber
                                Layout.fillWidth: true
                            }

                            MetricCard {
                                numberText: String(root.errors)
                                labelText: "ERROR"
                                numberColor: root.red
                                Layout.fillWidth: true
                            }
                        }

                        Panel {
                            Layout.fillWidth: true
                            Layout.leftMargin: 23
                            Layout.rightMargin: 23
                            implicitHeight: 390

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 7

                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        text: "Validation Results"
                                        color: root.fg
                                        font.pixelSize: 14
                                        font.bold: true
                                    }

                                    Item { Layout.fillWidth: true }

                                    StandardButton {
                                        text: "Export Report"
                                        enabled: valRows.count > 0
                                        onClicked: reportSaveDialog.open()
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    HeaderCell { label: "Row"; Layout.preferredWidth: 55 }
                                    HeaderCell { label: "SID"; Layout.preferredWidth: 110 }
                                    HeaderCell { label: "Store Name"; Layout.preferredWidth: 190 }
                                    HeaderCell { label: "Status"; Layout.preferredWidth: 85 }
                                    HeaderCell { label: "Problem"; Layout.fillWidth: true }
                                }

                                ListView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    model: valRows
                                    clip: true

                                    delegate: Rectangle {
                                        required property int index
                                        required property string rowValue
                                        required property string sidValue
                                        required property string storeValue
                                        required property string statusValue
                                        required property string problemValue

                                        width: ListView.view.width
                                        height: 31
                                        color: index % 2 ? "#0d1b2e" : "#0b1829"

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
                                                Layout.preferredWidth: 110
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
                                                color: statusValue === "ERROR" ? root.red :
                                                       statusValue === "REVIEW" ? root.amber : root.green
                                                font.bold: true
                                                leftPadding: 7
                                                Layout.preferredWidth: 85
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

                        Item { implicitHeight: 20 }
                    }
                }
            }

            Item {
                ScrollView {
                    anchors.fill: parent
                    contentWidth: availableWidth

                    ColumnLayout {
                        width: parent.width
                        spacing: 13

                        Item { implicitHeight: 10 }

                        PageTitle {
                            text: "Repair CSV / Text"
                            Layout.leftMargin: 23
                            Layout.rightMargin: 23
                        }

                        Description {
                            text: "Inspect malformed records before repair. The repaired version is saved separately so the source file remains untouched."
                            Layout.fillWidth: true
                            Layout.leftMargin: 23
                            Layout.rightMargin: 23
                        }

                        Panel {
                            Layout.fillWidth: true
                            Layout.leftMargin: 23
                            Layout.rightMargin: 23
                            implicitHeight: 100

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 14

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

                                PrimaryButton {
                                    text: "Repair & Save Copy"
                                    enabled: root.repairPath !== ""
                                    onClicked: repairSaveDialog.open()
                                }
                            }
                        }

                        Panel {
                            Layout.fillWidth: true
                            Layout.leftMargin: 23
                            Layout.rightMargin: 23
                            implicitHeight: 520

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 7

                                Text {
                                    text: "Broken Record Inspector — " + fixRows.count + " issue(s)"
                                    color: root.fg
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    HeaderCell { label: "Record"; Layout.preferredWidth: 70 }
                                    HeaderCell { label: "Expected"; Layout.preferredWidth: 85 }
                                    HeaderCell { label: "Actual"; Layout.preferredWidth: 85 }
                                    HeaderCell { label: "Original Information"; Layout.fillWidth: true }
                                }

                                ListView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    model: fixRows
                                    clip: true

                                    delegate: Rectangle {
                                        required property int index
                                        required property string lineValue
                                        required property string expectedValue
                                        required property string actualValue
                                        required property string contentValue

                                        width: ListView.view.width
                                        height: 31
                                        color: index % 2 ? "#0d1b2e" : "#0b1829"

                                        RowLayout {
                                            anchors.fill: parent
                                            spacing: 1

                                            Text {
                                                text: lineValue
                                                color: root.amber
                                                leftPadding: 7
                                                Layout.preferredWidth: 70
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

                        Item { implicitHeight: 20 }
                    }
                }
            }

            Item {
                ScrollView {
                    anchors.fill: parent
                    contentWidth: availableWidth

                    ColumnLayout {
                        width: parent.width
                        spacing: 13

                        Item { implicitHeight: 10 }

                        PageTitle {
                            text: "Data Health Check"
                            Layout.leftMargin: 23
                            Layout.rightMargin: 23
                        }

                        Description {
                            text: "Profile a structured dataset locally and surface actionable quality statistics."
                            Layout.fillWidth: true
                            Layout.leftMargin: 23
                            Layout.rightMargin: 23
                        }

                        Panel {
                            Layout.fillWidth: true
                            Layout.leftMargin: 23
                            Layout.rightMargin: 23
                            implicitHeight: 95

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 14

                                Text {
                                    text: root.analysisPath !== "" ? root.fileName(root.analysisPath) : "No dataset selected"
                                    color: root.fg
                                    font.bold: true
                                    Layout.fillWidth: true
                                    elide: Text.ElideMiddle
                                }

                                PrimaryButton {
                                    text: "Choose Dataset"
                                    onClicked: analysisDialog.open()
                                }
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 23
                            Layout.rightMargin: 23
                            columns: 4
                            columnSpacing: 9

                            MetricCard {
                                numberText: root.health.rows !== undefined ? String(root.health.rows) : "0"
                                labelText: "ROWS"
                                Layout.fillWidth: true
                            }

                            MetricCard {
                                numberText: root.health.columns !== undefined ? String(root.health.columns) : "0"
                                labelText: "COLUMNS"
                                Layout.fillWidth: true
                            }

                            MetricCard {
                                numberText: root.health.completeness !== undefined ? String(root.health.completeness) + "%" : "0%"
                                labelText: "COMPLETENESS"
                                numberColor: root.green
                                Layout.fillWidth: true
                            }

                            MetricCard {
                                numberText: root.health.duplicateRows !== undefined ? String(root.health.duplicateRows) : "0"
                                labelText: "DUPLICATE ROWS"
                                numberColor: root.amber
                                Layout.fillWidth: true
                            }
                        }

                        Panel {
                            Layout.fillWidth: true
                            Layout.leftMargin: 23
                            Layout.rightMargin: 23
                            implicitHeight: 490

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 7

                                Text {
                                    text: "Column Quality"
                                    color: root.fg
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    HeaderCell { label: "Column"; Layout.fillWidth: true }
                                    HeaderCell { label: "Non-Blank"; Layout.preferredWidth: 100 }
                                    HeaderCell { label: "Blank"; Layout.preferredWidth: 85 }
                                    HeaderCell { label: "Unique"; Layout.preferredWidth: 85 }
                                    HeaderCell { label: "Duplicate Values"; Layout.preferredWidth: 120 }
                                }

                                ListView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    model: healthRows
                                    clip: true

                                    delegate: Rectangle {
                                        required property int index
                                        required property string columnValue
                                        required property string blankValue
                                        required property string nonBlankValue
                                        required property string uniqueValue
                                        required property string duplicateValue

                                        width: ListView.view.width
                                        height: 31
                                        color: index % 2 ? "#0d1b2e" : "#0b1829"

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
                                                text: nonBlankValue
                                                color: root.green
                                                leftPadding: 7
                                                Layout.preferredWidth: 100
                                            }

                                            Text {
                                                text: blankValue
                                                color: Number(blankValue) > 0 ? root.amber : root.muted
                                                leftPadding: 7
                                                Layout.preferredWidth: 85
                                            }

                                            Text {
                                                text: uniqueValue
                                                color: root.muted
                                                leftPadding: 7
                                                Layout.preferredWidth: 85
                                            }

                                            Text {
                                                text: duplicateValue
                                                color: root.muted
                                                leftPadding: 7
                                                Layout.preferredWidth: 120
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Item { implicitHeight: 20 }
                    }
                }
            }

            Item {
                ScrollView {
                    anchors.fill: parent
                    contentWidth: availableWidth

                    ColumnLayout {
                        width: parent.width
                        spacing: 13

                        Item { implicitHeight: 10 }

                        PageTitle {
                            text: "Explore & Analyze"
                            Layout.leftMargin: 23
                            Layout.rightMargin: 23
                        }

                        Description {
                            text: "Analyze general structured data locally. SQL is deliberately restricted to this workspace and to read-only queries."
                            Layout.fillWidth: true
                            Layout.leftMargin: 23
                            Layout.rightMargin: 23
                        }

                        Panel {
                            Layout.fillWidth: true
                            Layout.leftMargin: 23
                            Layout.rightMargin: 23
                            implicitHeight: 95

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 14

                                Text {
                                    text: root.analysisPath !== "" ? root.fileName(root.analysisPath) : "No dataset loaded"
                                    color: root.fg
                                    font.bold: true
                                    Layout.fillWidth: true
                                    elide: Text.ElideMiddle
                                }

                                StandardButton {
                                    text: "Load Dataset"
                                    onClicked: analysisDialog.open()
                                }

                                StandardButton {
                                    text: "Export Data"
                                    enabled: root.analysisPath !== ""
                                    onClicked: dataSaveDialog.open()
                                }
                            }
                        }

                        Panel {
                            Layout.fillWidth: true
                            Layout.leftMargin: 23
                            Layout.rightMargin: 23
                            implicitHeight: 220

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 7

                                Text {
                                    text: "SQL Workspace"
                                    color: root.fg
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                Description {
                                    text: "Table name: data    •    Example: SELECT * FROM data LIMIT 100"
                                }

                                TextArea {
                                    id: sqlEditor
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    color: root.fg
                                    placeholderText: "SELECT * FROM data LIMIT 100"
                                    wrapMode: TextEdit.NoWrap

                                    background: Rectangle {
                                        radius: 6
                                        color: "#071321"
                                        border.width: 1
                                        border.color: root.borderColor
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Item { Layout.fillWidth: true }

                                    PrimaryButton {
                                        text: "Run SQL"
                                        enabled: root.analysisPath !== "" && sqlEditor.text.trim() !== ""
                                        onClicked: backend.runSQL(sqlEditor.text)
                                    }
                                }
                            }
                        }

                        Panel {
                            Layout.fillWidth: true
                            Layout.leftMargin: 23
                            Layout.rightMargin: 23
                            implicitHeight: 450

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 7

                                Text {
                                    text: "Query Results — " + sqlRows.count + " row(s)"
                                    color: root.fg
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                ListView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    model: sqlRows
                                    clip: true

                                    delegate: Rectangle {
                                        required property int index
                                        required property string rowText

                                        width: ListView.view.width
                                        height: 33
                                        color: index % 2 ? "#0d1b2e" : "#0b1829"

                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 7
                                            text: rowText
                                            color: root.fg
                                            font.pixelSize: 10
                                            elide: Text.ElideRight
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }
                            }
                        }

                        Item { implicitHeight: 20 }
                    }
                }
            }
        }
    }
}
