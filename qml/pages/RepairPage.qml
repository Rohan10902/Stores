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

    property int selectedIssue: -1
    property bool hasData: false
    property bool busy: false

    property var headers: []
    property var rows: []
    property var issues: []

    property int historyCount: 0

    property string selectedMessage: ""
    property string selectedType: ""

    property int selectedSourceColumn: -1
    property string selectedTargetColumn: ""

    function backendAvailable() {
        return typeof backend !== "undefined" &&
               backend !== null &&
               backend.repair !== undefined &&
               backend.repair !== null
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

    function clearSelection() {
        selectedIssue = -1
        selectedMessage = ""
        selectedType = ""
        selectedSourceColumn = -1
        selectedTargetColumn = ""
    }

    function loadPayload(payload) {
        try {
            var data = JSON.parse(payload)

            root.headers = data.headers || []
            root.rows = data.rows || []
            root.issues = data.issues || []
            root.historyCount = Number(data.history || 0)

            root.hasData =
                root.headers.length > 0 ||
                root.rows.length > 0

            if (root.selectedIssue >= root.issues.length)
                root.clearSelection()

            if (root.selectedIssue >= 0 &&
                    root.selectedIssue < root.issues.length) {
                var issue = root.issues[root.selectedIssue]

                root.selectedMessage =
                    String(issue.message || "")

                root.selectedType =
                    String(issue.type || "")
            }
        } catch (error) {
            root.headers = []
            root.rows = []
            root.issues = []
            root.historyCount = 0
            root.hasData = false
            root.clearSelection()
        }
    }

    function selectIssue(index) {
        if (index < 0 || index >= root.issues.length)
            return

        root.selectedIssue = index

        var issue = root.issues[index] || {}

        root.selectedMessage =
            String(issue.message || "")

        root.selectedType =
            String(issue.type || "")

        root.selectedSourceColumn = -1
        root.selectedTargetColumn = ""
    }

    function issueRow(issue) {
        return Number(issue.row || 0)
    }

    function issueIndex(issue) {
        return Number(issue.index || 0)
    }

    function selectedIssueObject() {
        if (root.selectedIssue < 0 ||
                root.selectedIssue >= root.issues.length)
            return null

        return root.issues[root.selectedIssue]
    }

    function selectedRowData() {
        var issue = root.selectedIssueObject()

        if (!issue)
            return []

        var rowIndex = Number(issue.row || 0) - 1

        if (rowIndex < 0 ||
                rowIndex >= root.rows.length)
            return []

        var row = root.rows[rowIndex]

        if (Array.isArray(row))
            return row

        return []
    }

    function performRepair() {
        if (!root.backendAvailable())
            return

        if (root.sourcePath === "" ||
                root.destinationPath === "") {
            return
        }

        root.busy = true

        backend.repair.repair(
            root.sourcePath,
            root.destinationPath
        )

        root.busy = false
    }

    // =========================================================
    // FILE DIALOGS
    // =========================================================

    FileDialog {
        id: sourceDialog

        title: "Select CSV to Repair"

        nameFilters: [
            "CSV Files (*.csv)",
            "All Files (*)"
        ]

        onAccepted: {
            root.sourcePath =
                root.urlToPath(selectedFile)

            if (root.backendAvailable() &&
                    root.sourcePath !== "") {
                root.busy = true

                backend.repair.inspect_repair(
                    root.sourcePath
                )

                root.busy = false
            }
        }
    }

    FileDialog {
        id: destinationDialog

        title: "Export Repaired CSV"

        fileMode: FileDialog.SaveFile

        currentFile: "repaired.csv"

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
    // BACKEND SIGNAL
    // =========================================================

    Connections {
        target:
            root.backendAvailable()
                ? backend.repair
                : null

        ignoreUnknownSignals: true

        function onRepairReady(payload) {
            root.loadPayload(payload)
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

            width: parent.width

            spacing: Theme.spacingLarge

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

                title: "Record Repair"

                subtitle:
                    "Inspect structural issues, repair records, undo changes, and export a clean dataset."
            }

            // =================================================
            // SOURCE / EXPORT
            // =================================================

            Card {
                Layout.fillWidth: true

                Layout.leftMargin:
                    Theme.spacingXLarge

                Layout.rightMargin:
                    Theme.spacingXLarge

                Layout.preferredHeight: 155

                ColumnLayout {
                    anchors.fill: parent

                    anchors.margins:
                        Theme.spacingMedium

                    spacing:
                        Theme.spacingMedium

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "Source CSV"

                            color:
                                Theme.textSecondary

                            font.bold: true

                            Layout.preferredWidth: 105
                        }

                        TextField {
                            Layout.fillWidth: true

                            readOnly: true

                            text:
                                root.sourcePath

                            placeholderText:
                                "Select a CSV file to inspect"

                            color:
                                Theme.textPrimary

                            background: Rectangle {
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
                            text: "Browse"

                            enabled:
                                !root.busy

                            onClicked:
                                sourceDialog.open()
                        }

                        PrimaryButton {
                            text: "Inspect"

                            enabled:
                                root.sourcePath !== "" &&
                                !root.busy

                            onClicked: {
                                if (root.backendAvailable()) {
                                    root.busy = true

                                    backend.repair.inspect_repair(
                                        root.sourcePath
                                    )

                                    root.busy = false
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "Export To"

                            color:
                                Theme.textSecondary

                            font.bold: true

                            Layout.preferredWidth: 105
                        }

                        TextField {
                            Layout.fillWidth: true

                            readOnly: true

                            text:
                                root.destinationPath

                            placeholderText:
                                "Choose destination for repaired CSV"

                            color:
                                Theme.textPrimary

                            background: Rectangle {
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
                            text: "Browse"

                            enabled:
                                root.hasData &&
                                !root.busy

                            onClicked:
                                destinationDialog.open()
                        }

                        PrimaryButton {
                            text: "Export Repaired CSV"

                            enabled:
                                root.hasData &&
                                root.destinationPath !== "" &&
                                !root.busy

                            onClicked:
                                root.performRepair()
                        }
                    }
                }
            }

            // =================================================
            // SUMMARY
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
                    Layout.preferredHeight: 80

                    ColumnLayout {
                        anchors.centerIn: parent

                        Text {
                            text:
                                root.rows.length

                            color:
                                Theme.primary

                            font.pixelSize: 22
                            font.bold: true

                            Layout.alignment:
                                Qt.AlignHCenter
                        }

                        Text {
                            text: "Records"

                            color:
                                Theme.textSecondary

                            font.pixelSize: 10

                            Layout.alignment:
                                Qt.AlignHCenter
                        }
                    }
                }

                Card {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80

                    ColumnLayout {
                        anchors.centerIn: parent

                        Text {
                            text:
                                root.headers.length

                            color:
                                Theme.info

                            font.pixelSize: 22
                            font.bold: true

                            Layout.alignment:
                                Qt.AlignHCenter
                        }

                        Text {
                            text: "Columns"

                            color:
                                Theme.textSecondary

                            font.pixelSize: 10

                            Layout.alignment:
                                Qt.AlignHCenter
                        }
                    }
                }

                Card {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80

                    ColumnLayout {
                        anchors.centerIn: parent

                        Text {
                            text:
                                root.issues.length

                            color:
                                root.issues.length > 0
                                    ? Theme.error
                                    : Theme.success

                            font.pixelSize: 22
                            font.bold: true

                            Layout.alignment:
                                Qt.AlignHCenter
                        }

                        Text {
                            text: "Open Issues"

                            color:
                                Theme.textSecondary

                            font.pixelSize: 10

                            Layout.alignment:
                                Qt.AlignHCenter
                        }
                    }
                }

                Card {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80

                    ColumnLayout {
                        anchors.centerIn: parent

                        Text {
                            text:
                                root.historyCount

                            color:
                                Theme.warning

                            font.pixelSize: 22
                            font.bold: true

                            Layout.alignment:
                                Qt.AlignHCenter
                        }

                        Text {
                            text: "Undo Steps"

                            color:
                                Theme.textSecondary

                            font.pixelSize: 10

                            Layout.alignment:
                                Qt.AlignHCenter
                        }
                    }
                }
            }

            // =================================================
            // WORKSPACE
            // =================================================

            SplitView {
                id: workspace

                Layout.fillWidth: true

                Layout.leftMargin:
                    Theme.spacingXLarge

                Layout.rightMargin:
                    Theme.spacingXLarge

                Layout.bottomMargin:
                    Theme.spacingXLarge

                Layout.preferredHeight: 650

                orientation:
                    Qt.Horizontal

                // =============================================
                // ISSUE PANEL
                // =============================================

                Card {
                    SplitView.preferredWidth: 390
                    SplitView.minimumWidth: 320

                    ColumnLayout {
                        anchors.fill: parent

                        anchors.margins:
                            Theme.spacingMedium

                        spacing:
                            Theme.spacingSmall

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "Repair Queue"

                                color:
                                    Theme.textPrimary

                                font.pixelSize: 15
                                font.bold: true
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Text {
                                text:
                                    root.issues.length
                                    + " issue(s)"

                                color:
                                    Theme.textSecondary

                                font.pixelSize: 11
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true

                            height: 34

                            color:
                                Theme.surfaceHover

                            border.color:
                                Theme.border

                            RowLayout {
                                anchors.fill: parent

                                anchors.leftMargin:
                                    Theme.spacingSmall

                                anchors.rightMargin:
                                    Theme.spacingSmall

                                Text {
                                    text: "Row"

                                    color:
                                        Theme.textSecondary

                                    font.bold: true

                                    Layout.preferredWidth: 50
                                }

                                Text {
                                    text: "Issue"

                                    color:
                                        Theme.textSecondary

                                    font.bold: true

                                    Layout.fillWidth: true
                                }
                            }
                        }

                        ListView {
                            id: issueList

                            Layout.fillWidth: true

                            Layout.fillHeight: true

                            clip: true

                            spacing: 2

                            model:
                                root.issues

                            ScrollBar.vertical:
                                ScrollBar {}

                            delegate: Rectangle {
                                required property int index

                                required property var modelData

                                width:
                                    issueList.width

                                height: 64

                                radius:
                                    Theme.radiusMedium

                                color:
                                    root.selectedIssue === index
                                        ? Theme.surfaceHover
                                        : Theme.background

                                border.color:
                                    root.selectedIssue === index
                                        ? Theme.primary
                                        : Theme.border

                                MouseArea {
                                    anchors.fill: parent

                                    onClicked:
                                        root.selectIssue(index)
                                }

                                ColumnLayout {
                                    anchors.fill: parent

                                    anchors.margins:
                                        Theme.spacingSmall

                                    spacing: 2

                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            text:
                                                String(
                                                    modelData.row || ""
                                                )

                                            color:
                                                Theme.textSecondary

                                            font.bold: true

                                            Layout.preferredWidth:
                                                50
                                        }

                                        Text {
                                            text:
                                                String(
                                                    modelData.type || ""
                                                )

                                            color:
                                                modelData.type ===
                                                    "Created Record"
                                                    ? Theme.success
                                                    : Theme.error

                                            font.bold: true

                                            elide:
                                                Text.ElideRight

                                            Layout.fillWidth: true
                                        }
                                    }

                                    Text {
                                        text:
                                            String(
                                                modelData.message || ""
                                            )

                                        color:
                                            Theme.textSecondary

                                        font.pixelSize: 10

                                        elide:
                                            Text.ElideRight

                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            spacing:
                                Theme.spacingSmall

                            AppButton {
                                text: "Undo"

                                enabled:
                                    root.historyCount > 0 &&
                                    root.hasData

                                onClicked: {
                                    if (root.backendAvailable())
                                        backend.repair.undo_repair_action()
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                            }
                        }
                    }
                }

                // =============================================
                // INSPECTOR
                // =============================================

                Card {
                    SplitView.fillWidth: true
                    SplitView.minimumWidth: 650

                    ColumnLayout {
                        anchors.fill: parent

                        anchors.margins:
                            Theme.spacingMedium

                        spacing:
                            Theme.spacingSmall

                        // -------------------------------------
                        // HEADER
                        // -------------------------------------

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text:
                                    root.selectedIssue >= 0
                                        ? "Repair Inspector"
                                        : "Dataset Preview"

                                color:
                                    Theme.textPrimary

                                font.pixelSize: 15
                                font.bold: true
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Text {
                                visible:
                                    root.selectedIssue >= 0

                                text:
                                    root.selectedType

                                color:
                                    Theme.error

                                font.bold: true
                            }
                        }

                        // -------------------------------------
                        // ISSUE MESSAGE
                        // -------------------------------------

                        Rectangle {
                            visible:
                                root.selectedIssue >= 0

                            Layout.fillWidth: true

                            height:
                                visible ? 58 : 0

                            radius:
                                Theme.radiusMedium

                            color:
                                Theme.surfaceHover

                            border.color:
                                Theme.border

                            ColumnLayout {
                                anchors.fill: parent

                                anchors.margins:
                                    Theme.spacingSmall

                                spacing: 2

                                Text {
                                    text:
                                        root.selectedType

                                    color:
                                        Theme.error

                                    font.bold: true
                                }

                                Text {
                                    text:
                                        root.selectedMessage

                                    color:
                                        Theme.textPrimary

                                    font.pixelSize: 11

                                    wrapMode:
                                        Text.WordWrap

                                    Layout.fillWidth: true
                                }
                            }
                        }

                        // -------------------------------------
                        // ACTIONS
                        // -------------------------------------

                        RowLayout {
                            visible:
                                root.selectedIssue >= 0

                            Layout.fillWidth: true

                            spacing:
                                Theme.spacingSmall

                            PrimaryButton {
                                text: "Join Rows"

                                enabled:
                                    root.selectedIssue >= 0

                                onClicked: {
                                    var issue =
                                        root.selectedIssueObject()

                                    if (issue &&
                                            root.backendAvailable()) {
                                        backend.repair.join_repair_rows(
                                            Number(
                                                issue.index || 0
                                            )
                                        )
                                    }
                                }
                            }

                            AppButton {
                                text: "Keep As-Is"

                                enabled:
                                    root.selectedIssue >= 0

                                onClicked: {
                                    var issue =
                                        root.selectedIssueObject()

                                    if (issue &&
                                            root.backendAvailable()) {
                                        backend.repair.keep_repair_issue(
                                            Number(
                                                issue.index || 0
                                            )
                                        )
                                    }
                                }
                            }

                            AppButton {
                                text: "Keep / Pad Row"

                                enabled:
                                    root.selectedIssue >= 0

                                onClicked: {
                                    var issue =
                                        root.selectedIssueObject()

                                    if (issue &&
                                            root.backendAvailable()) {
                                        backend.repair.keep_repair_unresolved(
                                            Number(
                                                issue.index || 0
                                            ),
                                            root.selectedSourceColumn >= 0
                                                ? root.selectedSourceColumn
                                                : 0
                                        )
                                    }
                                }
                            }

                            AppButton {
                                text: "Create Record"

                                enabled:
                                    root.selectedIssue >= 0

                                onClicked:
                                    mappingDialog.open()
                            }

                            Item {
                                Layout.fillWidth: true
                            }
                        }

                        // -------------------------------------
                        // ROW PREVIEW
                        // -------------------------------------

                        Rectangle {
                            Layout.fillWidth: true

                            height: 38

                            color:
                                Theme.surfaceHover

                            border.color:
                                Theme.border

                            RowLayout {
                                anchors.fill: parent

                                anchors.leftMargin:
                                    Theme.spacingSmall

                                anchors.rightMargin:
                                    Theme.spacingSmall

                                Text {
                                    text: "Column"

                                    color:
                                        Theme.textSecondary

                                    font.bold: true

                                    Layout.preferredWidth: 180
                                }

                                Text {
                                    text: "Value"

                                    color:
                                        Theme.textSecondary

                                    font.bold: true

                                    Layout.fillWidth: true
                                }
                            }
                        }

                        ListView {
                            id: rowPreview

                            Layout.fillWidth: true

                            Layout.fillHeight: true

                            clip: true

                            model: {
                                var row = root.selectedRowData()

                                var result = []

                                for (var i = 0;
                                     i < root.headers.length;
                                     ++i) {
                                    result.push({
                                        column:
                                            String(
                                                root.headers[i]
                                            ),

                                        value:
                                            i < row.length
                                                ? String(
                                                    row[i] === null ||
                                                    row[i] === undefined
                                                        ? ""
                                                        : row[i]
                                                  )
                                                : ""
                                    })
                                }

                                return result
                            }

                            ScrollBar.vertical:
                                ScrollBar {}

                            delegate: Rectangle {
                                required property var modelData
                                required property int index

                                width:
                                    rowPreview.width

                                height: 38

                                color:
                                    index % 2 === 0
                                        ? Theme.background
                                        : Theme.surface

                                border.color:
                                    Theme.border

                                MouseArea {
                                    anchors.fill: parent

                                    onClicked: {
                                        root.selectedSourceColumn =
                                            index

                                        root.selectedTargetColumn =
                                            modelData.column
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent

                                    anchors.leftMargin:
                                        Theme.spacingSmall

                                    anchors.rightMargin:
                                        Theme.spacingSmall

                                    Text {
                                        text:
                                            modelData.column

                                        color:
                                            root.selectedSourceColumn === index
                                                ? Theme.primary
                                                : Theme.textPrimary

                                        font.bold:
                                            root.selectedSourceColumn === index

                                        Layout.preferredWidth: 180

                                        elide:
                                            Text.ElideRight
                                    }

                                    Text {
                                        text:
                                            modelData.value === ""
                                                ? "—"
                                                : modelData.value

                                        color:
                                            Theme.textSecondary

                                        Layout.fillWidth: true

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

    // =========================================================
    // CREATE RECORD DIALOG
    // =========================================================

    Dialog {
        id: mappingDialog

        title: "Create Repair Record"

        modal: true

        width: 520
        height: 360

        anchors.centerIn: parent

        background: Rectangle {
            color:
                Theme.surface

            border.color:
                Theme.border

            radius:
                Theme.radiusMedium
        }

        ColumnLayout {
            anchors.fill: parent

            anchors.margins:
                Theme.spacingLarge

            spacing:
                Theme.spacingMedium

            Text {
                text:
                    "Create a new record from the selected issue."

                color:
                    Theme.textPrimary

                wrapMode:
                    Text.WordWrap

                Layout.fillWidth: true
            }

            Text {
                text:
                    "The mapping is sent as JSON to the repair backend."

                color:
                    Theme.textSecondary

                font.pixelSize: 11

                Layout.fillWidth: true
            }

            TextArea {
                id: mappingInput

                Layout.fillWidth: true
                Layout.fillHeight: true

                placeholderText:
                    '{"Column Name":"Value"}'

                textFormat:
                    TextEdit.PlainText

                color:
                    Theme.textPrimary

                background: Rectangle {
                    color:
                        Theme.background

                    border.color:
                        Theme.border

                    radius:
                        Theme.radiusMedium
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Item {
                    Layout.fillWidth: true
                }

                AppButton {
                    text: "Cancel"

                    onClicked:
                        mappingDialog.close()
                }

                PrimaryButton {
                    text: "Create"

                    onClicked: {
                        var issue =
                            root.selectedIssueObject()

                        if (issue &&
                                root.backendAvailable()) {

                            backend.repair.create_repair_record(
                                Number(issue.index || 0),
                                mappingInput.text
                            )
                        }

                        mappingInput.text = ""
                        mappingDialog.close()
                    }
                }
            }
        }
    }
}
