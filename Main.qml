import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Window

ApplicationWindow {
    id: root

    visible: true
    width: 1500
    height: 900
    minimumWidth: 1100
    minimumHeight: 700

    title: "Store Data Assistant 6.0"

    property color backgroundColor: "#081120"
    property color sidebarColor: "#0D1726"
    property color panelColor: "#111C2D"
    property color panelColor2: "#162235"
    property color borderColor: "#26364D"

    property color primaryColor: "#3B82F6"
    property color primaryHover: "#2563EB"

    property color successColor: "#22C55E"
    property color warningColor: "#F59E0B"
    property color dangerColor: "#EF4444"

    property color textColor: "#F8FAFC"
    property color mutedColor: "#94A3B8"

    property string masterPath: ""
    property string mappingPath: ""
    property string repairPath: ""
    property string analysisPath: ""

    property int currentPage: 0

    /*
        FILE DIALOGS
    */

    FileDialog {
        id: masterDialog
        title: "Choose Master File"
        nameFilters: [
            "Data files (*.csv *.xlsx *.xls *.tsv *.txt)",
            "All files (*)"
        ]

        onAccepted: {
            root.masterPath = selectedFile.toString()
            masterPathText.text = cleanFilePath(root.masterPath)
        }
    }

    FileDialog {
        id: mappingDialog
        title: "Choose File to Compare"
        nameFilters: [
            "Data files (*.csv *.xlsx *.xls *.tsv *.txt)",
            "All files (*)"
        ]

        onAccepted: {
            root.mappingPath = selectedFile.toString()
            mappingPathText.text = cleanFilePath(root.mappingPath)
        }
    }

    FileDialog {
        id: repairDialog
        title: "Choose CSV or Text File"
        nameFilters: [
            "CSV files (*.csv)",
            "Text files (*.txt *.tsv)",
            "All files (*)"
        ]

        onAccepted: {
            root.repairPath = selectedFile.toString()
            repairPathText.text = cleanFilePath(root.repairPath)
        }
    }

    FileDialog {
        id: analysisDialog
        title: "Choose File for Data Analysis"
        nameFilters: [
            "Supported files (*.csv *.tsv *.txt *.xlsx *.xls *.json *.xml)",
            "All files (*)"
        ]

        onAccepted: {
            root.analysisPath = selectedFile.toString()
            analysisPathText.text = cleanFilePath(root.analysisPath)
        }
    }

    /*
        HELPERS
    */

    function cleanFilePath(value) {
        if (!value) {
            return ""
        }

        var result = value.toString()

        if (result.indexOf("file:///") === 0) {
            result = result.substring(8)
        } else if (result.indexOf("file://") === 0) {
            result = result.substring(7)
        }

        return decodeURIComponent(result)
    }

    function fileName(value) {
        var path = cleanFilePath(value)

        if (!path) {
            return "No file selected"
        }

        path = path.replace(/\\/g, "/")

        var parts = path.split("/")
        return parts[parts.length - 1]
    }

    function safeBackendCall(methodName, arg1, arg2) {
        try {
            if (typeof backend === "undefined") {
                statusMessage.text =
                        "Backend is not available. Check app.py."
                statusMessage.color = root.dangerColor
                return
            }

            if (typeof backend[methodName] !== "function") {
                statusMessage.text =
                        "Backend function not available: " + methodName
                statusMessage.color = root.warningColor
                return
            }

            if (arg2 !== undefined) {
                backend[methodName](arg1, arg2)
            } else if (arg1 !== undefined) {
                backend[methodName](arg1)
            } else {
                backend[methodName]()
            }

        } catch (error) {
            statusMessage.text = "Application error: " + error
            statusMessage.color = root.dangerColor
        }
    }

    /*
        REUSABLE COMPONENTS
    */

    component SidebarButton: Button {
        id: sidebarButton

        property int pageIndex: 0
        property string iconText: ""

        Layout.fillWidth: true
        Layout.preferredHeight: 50

        background: Rectangle {
            radius: 8

            color: root.currentPage === sidebarButton.pageIndex
                   ? "#1E3A5F"
                   : sidebarButton.hovered
                     ? "#17263A"
                     : "transparent"

            border.width:
                root.currentPage === sidebarButton.pageIndex ? 1 : 0

            border.color: "#31577E"
        }

        contentItem: RowLayout {
            spacing: 12

            Text {
                text: sidebarButton.iconText
                color: root.textColor
                font.pixelSize: 17
            }

            Text {
                text: sidebarButton.text
                color: root.textColor
                font.pixelSize: 13
                font.weight:
                    root.currentPage === sidebarButton.pageIndex
                    ? Font.DemiBold
                    : Font.Normal

                Layout.fillWidth: true
            }
        }

        onClicked: {
            root.currentPage = pageIndex
            pageStack.currentIndex = pageIndex
        }
    }

    component PrimaryButton: Button {
        id: primaryButton

        implicitHeight: 42

        background: Rectangle {
            radius: 7

            color: primaryButton.down
                   ? "#1D4ED8"
                   : primaryButton.hovered
                     ? root.primaryHover
                     : root.primaryColor
        }

        contentItem: Text {
            text: primaryButton.text
            color: "white"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
    }

    component SecondaryButton: Button {
        id: secondaryButton

        implicitHeight: 42

        background: Rectangle {
            radius: 7

            color: secondaryButton.hovered
                   ? "#22334B"
                   : root.panelColor2

            border.width: 1
            border.color: root.borderColor
        }

        contentItem: Text {
            text: secondaryButton.text
            color: root.textColor
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: 13
        }
    }

    component SectionCard: Rectangle {
        radius: 12
        color: root.panelColor

        border.width: 1
        border.color: root.borderColor
    }

    component MetricCard: Rectangle {
        property string metricTitle: ""
        property string metricValue: "0"
        property string metricDetail: ""

        radius: 10
        color: root.panelColor

        border.width: 1
        border.color: root.borderColor

        implicitHeight: 112

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16

            spacing: 4

            Text {
                text: parent.parent.metricTitle
                color: root.mutedColor
                font.pixelSize: 11
            }

            Text {
                text: parent.parent.metricValue
                color: root.textColor
                font.pixelSize: 26
                font.weight: Font.Bold
            }

            Text {
                text: parent.parent.metricDetail
                color: root.mutedColor
                font.pixelSize: 10
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }

    /*
        MAIN LAYOUT
    */

    Rectangle {
        anchors.fill: parent
        color: root.backgroundColor

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            /*
                HEADER
            */

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 64

                color: "#0B1524"

                border.width: 1
                border.color: root.borderColor

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 22
                    anchors.rightMargin: 22

                    spacing: 12

                    Rectangle {
                        width: 36
                        height: 36
                        radius: 9
                        color: root.primaryColor

                        Text {
                            anchors.centerIn: parent
                            text: "DA"
                            color: "white"
                            font.pixelSize: 13
                            font.weight: Font.Bold
                        }
                    }

                    ColumnLayout {
                        spacing: 1

                        Text {
                            text: "Store Data Assistant"
                            color: root.textColor
                            font.pixelSize: 17
                            font.weight: Font.Bold
                        }

                        Text {
                            text: "Data validation, repair and analysis workspace"
                            color: root.mutedColor
                            font.pixelSize: 10
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        width: 128
                        height: 30
                        radius: 15
                        color: "#102A22"

                        border.width: 1
                        border.color: "#1F5C48"

                        Row {
                            anchors.centerIn: parent
                            spacing: 7

                            Rectangle {
                                width: 7
                                height: 7
                                radius: 4
                                color: root.successColor
                            }

                            Text {
                                text: "LOCAL ONLY"
                                color: "#A7F3D0"
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true

                spacing: 0

                /*
                    SIDEBAR
                */

                Rectangle {
                    Layout.preferredWidth: 235
                    Layout.fillHeight: true

                    color: root.sidebarColor

                    border.width: 1
                    border.color: root.borderColor

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12

                        spacing: 6

                        Text {
                            text: "WORKSPACE"
                            color: root.mutedColor
                            font.pixelSize: 10
                            font.weight: Font.Bold

                            Layout.leftMargin: 8
                            Layout.topMargin: 10
                            Layout.bottomMargin: 6
                        }

                        SidebarButton {
                            text: "Home"
                            iconText: "⌂"
                            pageIndex: 0
                        }

                        SidebarButton {
                            text: "Compare & Validate"
                            iconText: "✓"
                            pageIndex: 1
                        }

                        SidebarButton {
                            text: "Repair CSV / Text"
                            iconText: "↻"
                            pageIndex: 2
                        }

                        SidebarButton {
                            text: "Data Health Check"
                            iconText: "▦"
                            pageIndex: 3
                        }

                        SidebarButton {
                            text: "Explore & Analyze"
                            iconText: "⌕"
                            pageIndex: 4
                        }

                        Item {
                            Layout.fillHeight: true
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 86

                            radius: 8
                            color: "#101C2C"

                            border.width: 1
                            border.color: root.borderColor

                            Column {
                                anchors.fill: parent
                                anchors.margins: 12

                                spacing: 5

                                Text {
                                    text: "Privacy"
                                    color: root.textColor
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    width: parent.width
                                    wrapMode: Text.WordWrap

                                    text:
                                        "Files are processed locally by the application."

                                    color: root.mutedColor
                                    font.pixelSize: 9
                                }
                            }
                        }
                    }
                }

                /*
                    CONTENT
                */

                StackLayout {
                    id: pageStack

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    currentIndex: root.currentPage

                    /*
                        HOME
                    */

                    Item {
                        ScrollView {
                            anchors.fill: parent
                            clip: true

                            ColumnLayout {
                                width: Math.max(
                                    900,
                                    pageStack.width - 60
                                )

                                anchors.horizontalCenter: parent.horizontalCenter

                                spacing: 18

                                Item {
                                    Layout.preferredHeight: 18
                                }

                                Text {
                                    text: "Data Workspace"
                                    color: root.textColor
                                    font.pixelSize: 28
                                    font.weight: Font.Bold
                                }

                                Text {
                                    text:
                                        "Validate store files, repair malformed data, inspect file quality and analyze datasets without uploading confidential information."

                                    color: root.mutedColor
                                    font.pixelSize: 13

                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 4
                                    columnSpacing: 12
                                    rowSpacing: 12

                                    MetricCard {
                                        Layout.fillWidth: true
                                        metricTitle: "Store Validation"
                                        metricValue: "14"
                                        metricDetail: "Controlled standard fields"
                                    }

                                    MetricCard {
                                        Layout.fillWidth: true
                                        metricTitle: "CSV Repair"
                                        metricValue: "✓"
                                        metricDetail: "Broken-line inspection"
                                    }

                                    MetricCard {
                                        Layout.fillWidth: true
                                        metricTitle: "Data Health"
                                        metricValue: "360°"
                                        metricDetail: "Quality and structure review"
                                    }

                                    MetricCard {
                                        Layout.fillWidth: true
                                        metricTitle: "SQL Analysis"
                                        metricValue: "SQL"
                                        metricDetail: "Read-only exploration"
                                    }
                                }

                                SectionCard {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 210

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 20

                                        spacing: 12

                                        Text {
                                            text: "Choose a workspace"
                                            color: root.textColor
                                            font.pixelSize: 18
                                            font.weight: Font.DemiBold
                                        }

                                        Text {
                                            text:
                                                "Use Store Validation for controlled store mapping. Use Data Health Check or Explore & Analyze for general datasets."

                                            color: root.mutedColor
                                            font.pixelSize: 12

                                            wrapMode: Text.WordWrap
                                            Layout.fillWidth: true
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 12

                                            PrimaryButton {
                                                text: "Compare Store Files"

                                                Layout.fillWidth: true

                                                onClicked: {
                                                    root.currentPage = 1
                                                    pageStack.currentIndex = 1
                                                }
                                            }

                                            SecondaryButton {
                                                text: "Repair a File"

                                                Layout.fillWidth: true

                                                onClicked: {
                                                    root.currentPage = 2
                                                    pageStack.currentIndex = 2
                                                }
                                            }

                                            SecondaryButton {
                                                text: "Check Data Quality"

                                                Layout.fillWidth: true

                                                onClicked: {
                                                    root.currentPage = 3
                                                    pageStack.currentIndex = 3
                                                }
                                            }

                                            SecondaryButton {
                                                text: "Explore Data"

                                                Layout.fillWidth: true

                                                onClicked: {
                                                    root.currentPage = 4
                                                    pageStack.currentIndex = 4
                                                }
                                            }
                                        }
                                    }
                                }

                                Item {
                                    Layout.preferredHeight: 30
                                }
                            }
                        }
                    }

                    /*
                        STORE VALIDATION
                    */

                    Item {
                        ScrollView {
                            anchors.fill: parent
                            clip: true

                            ColumnLayout {
                                width: Math.max(
                                    900,
                                    pageStack.width - 60
                                )

                                anchors.horizontalCenter: parent.horizontalCenter

                                spacing: 16

                                Item {
                                    Layout.preferredHeight: 18
                                }

                                Text {
                                    text: "Compare & Validate Store Data"
                                    color: root.textColor
                                    font.pixelSize: 26
                                    font.weight: Font.Bold
                                }

                                Text {
                                    text:
                                        "Compare a store mapping file with the master dataset using the controlled 14-field schema."

                                    color: root.mutedColor
                                    font.pixelSize: 12
                                }

                                SectionCard {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 245

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 18

                                        spacing: 12

                                        Text {
                                            text: "1. Select files"
                                            color: root.textColor
                                            font.pixelSize: 16
                                            font.weight: Font.DemiBold
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true

                                            spacing: 10

                                            ColumnLayout {
                                                Layout.fillWidth: true

                                                Text {
                                                    text: "Master file"
                                                    color: root.mutedColor
                                                    font.pixelSize: 10
                                                }

                                                TextField {
                                                    id: masterPathText

                                                    Layout.fillWidth: true
                                                    readOnly: true

                                                    placeholderText:
                                                        "Select master file..."
                                                }
                                            }

                                            SecondaryButton {
                                                text: "Browse"

                                                onClicked: {
                                                    masterDialog.open()
                                                }
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 10

                                            ColumnLayout {
                                                Layout.fillWidth: true

                                                Text {
                                                    text: "File to compare"
                                                    color: root.mutedColor
                                                    font.pixelSize: 10
                                                }

                                                TextField {
                                                    id: mappingPathText

                                                    Layout.fillWidth: true
                                                    readOnly: true

                                                    placeholderText:
                                                        "Select mapping file..."
                                                }
                                            }

                                            SecondaryButton {
                                                text: "Browse"

                                                onClicked: {
                                                    mappingDialog.open()
                                                }
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 10

                                            PrimaryButton {
                                                text: "Detect Columns"

                                                Layout.fillWidth: true

                                                onClicked: {
                                                    if (!root.masterPath ||
                                                        !root.mappingPath) {

                                                        statusMessage.text =
                                                            "Select both files first."

                                                        statusMessage.color =
                                                            root.warningColor

                                                        return
                                                    }

                                                    safeBackendCall(
                                                        "detectColumns",
                                                        cleanFilePath(
                                                            root.masterPath
                                                        ),
                                                        cleanFilePath(
                                                            root.mappingPath
                                                        )
                                                    )
                                                }
                                            }

                                            PrimaryButton {
                                                text: "Validate Stores"

                                                Layout.fillWidth: true

                                                onClicked: {
                                                    if (!root.masterPath ||
                                                        !root.mappingPath) {

                                                        statusMessage.text =
                                                            "Select both files first."

                                                        statusMessage.color =
                                                            root.warningColor

                                                        return
                                                    }

                                                    safeBackendCall(
                                                        "validateStores",
                                                        cleanFilePath(
                                                            root.masterPath
                                                        ),
                                                        cleanFilePath(
                                                            root.mappingPath
                                                        )
                                                    )
                                                }
                                            }
                                        }
                                    }
                                }

                                SectionCard {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 320

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 18

                                        Text {
                                            text: "Controlled Store Schema"
                                            color: root.textColor
                                            font.pixelSize: 16
                                            font.weight: Font.DemiBold
                                        }

                                        TextArea {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true

                                            readOnly: true

                                            color: root.textColor

                                            text:
                                                "1. Store Name — Alphabet / Number\n" +
                                                "2. SID — Alphabet / Number\n" +
                                                "3. Banner — Variable\n" +
                                                "4. Nielsen Store Code — Alphabet / Number\n" +
                                                "5. Trip Received — Date\n" +
                                                "6. Last Trip — Date\n" +
                                                "7. Address 1 — Alphabet / Number\n" +
                                                "8. Address 2 — Alphabet / Number\n" +
                                                "9. Address 3 — Alphabet / Number\n" +
                                                "10. ZIP — Alphabet / Number\n" +
                                                "11. Active / Inactive — 1 or 0\n" +
                                                "12. Is Census — 1 or 0\n" +
                                                "13. Is Exceptions — 1 or 0\n" +
                                                "14. Updated By — Empty preferred; timestamp/value warning"
                                        }
                                    }
                                }

                                Item {
                                    Layout.preferredHeight: 30
                                }
                            }
                        }
                    }

                    /*
                        CSV REPAIR
                    */

                    Item {
                        ScrollView {
                            anchors.fill: parent
                            clip: true

                            ColumnLayout {
                                width: Math.max(
                                    900,
                                    pageStack.width - 60
                                )

                                anchors.horizontalCenter: parent.horizontalCenter

                                spacing: 16

                                Item {
                                    Layout.preferredHeight: 18
                                }

                                Text {
                                    text: "Repair CSV / Text File"
                                    color: root.textColor
                                    font.pixelSize: 26
                                    font.weight: Font.Bold
                                }

                                Text {
                                    text:
                                        "Inspect malformed records, broken physical lines and delimiter problems before exporting a repaired copy."

                                    color: root.mutedColor
                                    font.pixelSize: 12

                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }

                                SectionCard {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 210

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 18

                                        spacing: 12

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 10

                                            TextField {
                                                id: repairPathText

                                                Layout.fillWidth: true
                                                readOnly: true

                                                placeholderText:
                                                    "Select CSV or text file..."
                                            }

                                            SecondaryButton {
                                                text: "Browse"

                                                onClicked: {
                                                    repairDialog.open()
                                                }
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 10

                                            PrimaryButton {
                                                text: "Inspect File"

                                                Layout.fillWidth: true

                                                onClicked: {
                                                    if (!root.repairPath) {
                                                        statusMessage.text =
                                                            "Select a file first."

                                                        statusMessage.color =
                                                            root.warningColor

                                                        return
                                                    }

                                                    safeBackendCall(
                                                        "inspectFile",
                                                        cleanFilePath(
                                                            root.repairPath
                                                        )
                                                    )
                                                }
                                            }

                                            PrimaryButton {
                                                text: "Repair & Export Copy"

                                                Layout.fillWidth: true

                                                onClicked: {
                                                    if (!root.repairPath) {
                                                        statusMessage.text =
                                                            "Select a file first."

                                                        statusMessage.color =
                                                            root.warningColor

                                                        return
                                                    }

                                                    safeBackendCall(
                                                        "repairFile",
                                                        cleanFilePath(
                                                            root.repairPath
                                                        )
                                                    )
                                                }
                                            }
                                        }

                                        Text {
                                            text:
                                                "The source file should remain unchanged. Repairs should be exported as a new version."

                                            color: root.mutedColor
                                            font.pixelSize: 11
                                        }
                                    }
                                }

                                SectionCard {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 300

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 18

                                        Text {
                                            text: "Repair diagnostics"
                                            color: root.textColor
                                            font.pixelSize: 16
                                            font.weight: Font.DemiBold
                                        }

                                        TextArea {
                                            id: repairOutput

                                            Layout.fillWidth: true
                                            Layout.fillHeight: true

                                            readOnly: true

                                            placeholderText:
                                                "Broken rows, physical line numbers and repair information will appear here."
                                        }
                                    }
                                }

                                Item {
                                    Layout.preferredHeight: 30
                                }
                            }
                        }
                    }

                    /*
                        DATA HEALTH
                    */

                    Item {
                        ScrollView {
                            anchors.fill: parent
                            clip: true

                            ColumnLayout {
                                width: Math.max(
                                    900,
                                    pageStack.width - 60
                                )

                                anchors.horizontalCenter: parent.horizontalCenter

                                spacing: 16

                                Item {
                                    Layout.preferredHeight: 18
                                }

                                Text {
                                    text: "Data Health Check"
                                    color: root.textColor
                                    font.pixelSize: 26
                                    font.weight: Font.Bold
                                }

                                Text {
                                    text:
                                        "Profile a general dataset for structure, missing information, duplicates, suspicious records and data-type inconsistencies."

                                    color: root.mutedColor
                                    font.pixelSize: 12

                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }

                                SectionCard {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 190

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 18

                                        spacing: 12

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 10

                                            TextField {
                                                id: healthPathText

                                                Layout.fillWidth: true
                                                readOnly: true

                                                text:
                                                    root.analysisPath
                                                    ? cleanFilePath(
                                                          root.analysisPath
                                                      )
                                                    : ""

                                                placeholderText:
                                                    "Select a dataset..."
                                            }

                                            SecondaryButton {
                                                text: "Browse"

                                                onClicked: {
                                                    analysisDialog.open()
                                                }
                                            }
                                        }

                                        PrimaryButton {
                                            text: "Run Data Health Check"

                                            Layout.fillWidth: true

                                            onClicked: {
                                                if (!root.analysisPath) {
                                                    statusMessage.text =
                                                        "Select a dataset first."

                                                    statusMessage.color =
                                                        root.warningColor

                                                    return
                                                }

                                                safeBackendCall(
                                                    "analyzeFile",
                                                    cleanFilePath(
                                                        root.analysisPath
                                                    )
                                                )
                                            }
                                        }
                                    }
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 4
                                    columnSpacing: 12
                                    rowSpacing: 12

                                    MetricCard {
                                        Layout.fillWidth: true
                                        metricTitle: "Rows"
                                        metricValue: "-"
                                        metricDetail: "Detected records"
                                    }

                                    MetricCard {
                                        Layout.fillWidth: true
                                        metricTitle: "Columns"
                                        metricValue: "-"
                                        metricDetail: "Detected fields"
                                    }

                                    MetricCard {
                                        Layout.fillWidth: true
                                        metricTitle: "Missing"
                                        metricValue: "-"
                                        metricDetail: "Empty values"
                                    }

                                    MetricCard {
                                        Layout.fillWidth: true
                                        metricTitle: "Duplicates"
                                        metricValue: "-"
                                        metricDetail: "Repeated records"
                                    }
                                }

                                SectionCard {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 300

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 18

                                        Text {
                                            text: "Quality findings"
                                            color: root.textColor
                                            font.pixelSize: 16
                                            font.weight: Font.DemiBold
                                        }

                                        TextArea {
                                            id: healthOutput

                                            Layout.fillWidth: true
                                            Layout.fillHeight: true

                                            readOnly: true

                                            placeholderText:
                                                "File statistics and actionable quality findings will appear here."
                                        }
                                    }
                                }

                                Item {
                                    Layout.preferredHeight: 30
                                }
                            }
                        }
                    }

                    /*
                        EXPLORE / SQL
                    */

                    Item {
                        ScrollView {
                            anchors.fill: parent
                            clip: true

                            ColumnLayout {
                                width: Math.max(
                                    900,
                                    pageStack.width - 60
                                )

                                anchors.horizontalCenter: parent.horizontalCenter

                                spacing: 16

                                Item {
                                    Layout.preferredHeight: 18
                                }

                                Text {
                                    text: "Explore & Analyze Data"
                                    color: root.textColor
                                    font.pixelSize: 26
                                    font.weight: Font.Bold
                                }

                                Text {
                                    text:
                                        "Inspect records, calculate values and run read-only SQL against the selected dataset."

                                    color: root.mutedColor
                                    font.pixelSize: 12

                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }

                                SectionCard {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 170

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 18

                                        spacing: 12

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 10

                                            TextField {
                                                id: analysisPathText

                                                Layout.fillWidth: true
                                                readOnly: true

                                                placeholderText:
                                                    "Select dataset..."
                                            }

                                            SecondaryButton {
                                                text: "Browse"

                                                onClicked: {
                                                    analysisDialog.open()
                                                }
                                            }
                                        }

                                        PrimaryButton {
                                            text: "Load Dataset"

                                            Layout.fillWidth: true

                                            onClicked: {
                                                if (!root.analysisPath) {
                                                    statusMessage.text =
                                                        "Select a dataset first."

                                                    statusMessage.color =
                                                        root.warningColor

                                                    return
                                                }

                                                safeBackendCall(
                                                    "loadAnalysisFile",
                                                    cleanFilePath(
                                                        root.analysisPath
                                                    )
                                                )
                                            }
                                        }
                                    }
                                }

                                SectionCard {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 310

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 18

                                        spacing: 10

                                        Text {
                                            text: "Read-only SQL"
                                            color: root.textColor
                                            font.pixelSize: 16
                                            font.weight: Font.DemiBold
                                        }

                                        Text {
                                            text:
                                                "SQL is available only in this analysis workspace."

                                            color: root.mutedColor
                                            font.pixelSize: 10
                                        }

                                        TextArea {
                                            id: sqlEditor

                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 120

                                            text:
                                                "SELECT * FROM data LIMIT 100"

                                            placeholderText:
                                                "Enter SELECT query..."
                                        }

                                        PrimaryButton {
                                            text: "Run Query"

                                            Layout.fillWidth: true

                                            onClicked: {
                                                if (!root.analysisPath) {
                                                    statusMessage.text =
                                                        "Load a dataset first."

                                                    statusMessage.color =
                                                        root.warningColor

                                                    return
                                                }

                                                if (!sqlEditor.text.trim()) {
                                                    statusMessage.text =
                                                        "Enter a SQL query."

                                                    statusMessage.color =
                                                        root.warningColor

                                                    return
                                                }

                                                safeBackendCall(
                                                    "runSql",
                                                    sqlEditor.text
                                                )
                                            }
                                        }
                                    }
                                }

                                SectionCard {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 320

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 18

                                        Text {
                                            text: "Results"
                                            color: root.textColor
                                            font.pixelSize: 16
                                            font.weight: Font.DemiBold
                                        }

                                        TextArea {
                                            id: sqlOutput

                                            Layout.fillWidth: true
                                            Layout.fillHeight: true

                                            readOnly: true

                                            placeholderText:
                                                "Query results will appear here."
                                        }
                                    }
                                }

                                Item {
                                    Layout.preferredHeight: 30
                                }
                            }
                        }
                    }
                }
            }

            /*
                STATUS BAR
            */

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34

                color: "#09121F"

                border.width: 1
                border.color: root.borderColor

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18

                    Text {
                        id: statusMessage

                        text: "Ready"
                        color: root.mutedColor
                        font.pixelSize: 10

                        Layout.fillWidth: true
                    }

                    Text {
                        text: "Store Data Assistant 6.0"
                        color: root.mutedColor
                        font.pixelSize: 10
                    }
                }
            }
        }
    }

    /*
        BACKEND SIGNALS

        These Connections are intentionally defensive.
        If your Python backend doesn't expose one of these signals,
        QML will ignore it instead of terminating startup.
    */

    Connections {
        target:
            typeof backend !== "undefined"
            ? backend
            : null

        ignoreUnknownSignals: true

        function onStatusChanged(message) {
            statusMessage.text = message
            statusMessage.color = root.textColor
        }

        function onErrorOccurred(message) {
            statusMessage.text = message
            statusMessage.color = root.dangerColor
        }

        function onRepairResult(message) {
            repairOutput.text = message
        }

        function onAnalysisResult(message) {
            healthOutput.text = message
        }

        function onSqlResult(message) {
            sqlOutput.text = message
        }
    }
}
