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

    property var headers: []
    property var rows: []
    property var findings: []

    property int validationCount: 0
    property bool validated: false
    property bool exporting: false

    function backendAvailable() {
        return typeof backend !== "undefined" &&
               backend !== null &&
               backend.creator !== undefined &&
               backend.creator !== null
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

    function loadFile() {
        if (!root.backendAvailable() ||
                root.sourcePath === "")
            return

        backend.creator.load_creator_file(
            root.sourcePath
        )
    }

    function validateRows() {
        if (!root.backendAvailable())
            return

        if (root.rows.length === 0)
            return

        root.validated = false
        root.findings = []

        backend.creator.validate_creator(
            JSON.stringify(root.rows)
        )
    }

    function exportRows() {
        if (!root.backendAvailable())
            return

        if (!root.destinationPath ||
                root.rows.length === 0)
            return

        if (!root.validated ||
                root.findings.some(function (item) {
                    return String(item.severity || "")
                        .toUpperCase() === "ERROR"
                })) {
            return
        }

        root.exporting = true

        backend.creator.export_creator_file(
            JSON.stringify(root.rows),
            root.destinationPath
        )
    }

    function cellValue(row, columnIndex) {
        if (Array.isArray(row)) {
            return columnIndex < row.length
                    ? String(
                        row[columnIndex] === null ||
                        row[columnIndex] === undefined
                            ? ""
                            : row[columnIndex]
                      )
                    : ""
        }

        if (row !== null &&
                row !== undefined &&
                typeof row === "object") {
            var key = root.headers[columnIndex]

            return row[key] === null ||
                    row[key] === undefined
                    ? ""
                    : String(row[key])
        }

        return ""
    }

    function setCell(rowIndex, columnIndex, value) {
        if (rowIndex < 0 ||
                rowIndex >= root.rows.length)
            return

        var row = root.rows[rowIndex]

        if (!Array.isArray(row))
            return

        while (row.length < root.headers.length)
            row.push("")

        row[columnIndex] = value

        root.rows = root.rows.slice()
        root.validated = false
        root.findings = []
    }

    // =========================================================
    // FILE DIALOGS
    // =========================================================

    FileDialog {
        id: sourceDialog

        title: "Select Store Template"

        nameFilters: [
            "CSV Files (*.csv)",
            "All Files (*)"
        ]

        onAccepted: {
            root.sourcePath =
                root.urlToPath(selectedFile)

            root.loadFile()
        }
    }

    FileDialog {
        id: destinationDialog

        title: "Export Store Dataset"

        fileMode:
            FileDialog.SaveFile

        currentFile:
            "created_store_dataset.csv"

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
    // BACKEND SIGNALS
    // =========================================================

    Connections {
        target:
            root.backendAvailable()
                ? backend.creator
                : null

        ignoreUnknownSignals: true

        function onCreatorLoaded(payload) {
            try {
                var data = JSON.parse(payload)

                root.headers =
                    data.headers || []

                root.rows =
                    data.rows || []

                root.findings = []
                root.validationCount = 0
                root.validated = false

            } catch (error) {
                root.headers = []
                root.rows = []
                root.findings = []
                root.validationCount = 0
                root.validated = false
            }
        }

        function onCreatorReady(payload) {
            try {
                var data = JSON.parse(payload)

                root.validationCount =
                    Number(data.count || 0)

                root.findings =
                    data.findings || []

                root.validated = true

            } catch (error) {
                root.validationCount = 0
                root.findings = []
                root.validated = false
            }
        }

        function onCreatorExported() {
            root.exporting = false
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
                    "Create Store"

                subtitle:
                    "Create, validate, and export store records using your dataset template."
            }

            // =================================================
            // FILE CONTROLS
            // =================================================

            Card {
                Layout.fillWidth: true

                Layout.leftMargin:
                    Theme.spacingXLarge

                Layout.rightMargin:
                    Theme.spacingXLarge

                Layout.preferredHeight:
                    155

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
                                "Template"

                            color:
                                Theme.textSecondary

                            font.bold:
                                true

                            Layout.preferredWidth:
                                100
                        }

                        TextField {
                            Layout.fillWidth:
                                true

                            readOnly:
                                true

                            text:
                                root.sourcePath

                            placeholderText:
                                "Select a store template CSV"

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
                                "Load"

                            enabled:
                                root.sourcePath !== ""

                            onClicked:
                                root.loadFile()
                        }
                    }

                    RowLayout {
                        Layout.fillWidth:
                            true

                        Text {
                            text:
                                "Export To"

                            color:
                                Theme.textSecondary

                            font.bold:
                                true

                            Layout.preferredWidth:
                                100
                        }

                        TextField {
                            Layout.fillWidth:
                                true

                            readOnly:
                                true

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
                                root.rows.length > 0

                            onClicked:
                                destinationDialog.open()
                        }

                        AppButton {
                            text:
                                "Validate"

                            enabled:
                                root.rows.length > 0

                            onClicked:
                                root.validateRows()
                        }

                        PrimaryButton {
                            text:
                                root.exporting
                                    ? "Exporting..."
                                    : "Export"

                            enabled:
                                root.rows.length > 0 &&
                                root.destinationPath !== "" &&
                                root.validated &&
                                !root.exporting &&
                                !root.findings.some(
                                    function (item) {
                                        return String(
                                            item.severity || ""
                                        ).toUpperCase() === "ERROR"
                                    }
                                )

                            onClicked:
                                root.exportRows()
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
                    Layout.fillWidth:
                        true

                    Layout.preferredHeight:
                        82

                    ColumnLayout {
                        anchors.centerIn:
                            parent

                        Text {
                            text:
                                root.rows.length

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
                                "RECORDS"

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
                    Layout.fillWidth:
                        true

                    Layout.preferredHeight:
                        82

                    ColumnLayout {
                        anchors.centerIn:
                            parent

                        Text {
                            text:
                                root.headers.length

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
                    Layout.fillWidth:
                        true

                    Layout.preferredHeight:
                        82

                    ColumnLayout {
                        anchors.centerIn:
                            parent

                        Text {
                            text:
                                root.validationCount

                            color:
                                root.validated
                                    ? Theme.success
                                    : Theme.textMuted

                            font.pixelSize:
                                23

                            font.bold:
                                true

                            Layout.alignment:
                                Qt.AlignHCenter
                        }

                        Text {
                            text:
                                "VALIDATED"

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
                    Layout.fillWidth:
                        true

                    Layout.preferredHeight:
                        82

                    ColumnLayout {
                        anchors.centerIn:
                            parent

                        Text {
                            text:
                                root.findings.length

                            color:
                                root.findings.length > 0
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

                Layout.fillWidth:
                    true

                Layout.leftMargin:
                    Theme.spacingXLarge

                Layout.rightMargin:
                    Theme.spacingXLarge

                Layout.preferredHeight:
                    visible
                        ? Math.min(
                            230,
                            75 +
                            root.findings.length * 48
                          )
                        : 0

                ColumnLayout {
                    anchors.fill:
                        parent

                    anchors.margins:
                        Theme.spacingMedium

                    spacing:
                        Theme.spacingSmall

                    Text {
                        text:
                            "Validation Findings"

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
                                    anchors.fill:
                                        parent

                                    anchors.margins:
                                        Theme.spacingSmall

                                    spacing:
                                        Theme.spacingSmall

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
            // EDITOR
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
                    650

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
                                "Store Records"

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
                                root.rows.length > 0
                                    ? root.rows.length
                                      + " row(s)"
                                    : "No records loaded"

                            color:
                                Theme.textSecondary

                            font.pixelSize:
                                11
                        }
                    }

                    // -------------------------------------------------
                    // HEADER
                    // -------------------------------------------------

                    Flickable {
                        id: headerFlick

                        Layout.fillWidth:
                            true

                        contentWidth:
                            Math.max(
                                width,
                                root.headers.length * 160
                            )

                        contentHeight:
                            38

                        height:
                            root.headers.length > 0
                                ? 38
                                : 0

                        clip:
                            true

                        Row {
                            width:
                                headerFlick.contentWidth

                            height:
                                38

                            spacing:
                                0

                            Repeater {
                                model:
                                    root.headers

                                delegate:
                                    Rectangle {
                                        required property string modelData

                                        width:
                                            160

                                        height:
                                            38

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
                    }

                    // -------------------------------------------------
                    // GRID
                    // -------------------------------------------------

                    Flickable {
                        id: gridFlick

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
                                root.headers.length * 160
                            )

                        contentHeight:
                            gridColumn.height

                        ScrollBar.vertical:
                            ScrollBar {}

                        ScrollBar.horizontal:
                            ScrollBar {}

                        Column {
                            id: gridColumn

                            width:
                                gridFlick.contentWidth

                            spacing:
                                1

                            Repeater {
                                model:
                                    root.rows

                                delegate:
                                    Row {
                                        required property var modelData
                                        required property int index

                                        height:
                                            42

                                        spacing:
                                            0

                                        Repeater {
                                            model:
                                                root.headers

                                            delegate:
                                                Rectangle {
                                                    required property string modelData
                                                    required property int index

                                                    width:
                                                        160

                                                    height:
                                                        42

                                                    color:
                                                        modelData === ""
                                                            ? Theme.background
                                                            : (
                                                                parent &&
                                                                parent.parent &&
                                                                parent.parent.index % 2 === 0
                                                                    ? Theme.background
                                                                    : Theme.surface
                                                              )

                                                    border.color:
                                                        Theme.border

                                                    TextField {
                                                        anchors.fill:
                                                            parent

                                                        text:
                                                            root.cellValue(
                                                                modelData,
                                                                index
                                                            )

                                                        color:
                                                            Theme.textPrimary

                                                        font.pixelSize:
                                                            11

                                                        leftPadding:
                                                            Theme.spacingSmall

                                                        rightPadding:
                                                            Theme.spacingSmall

                                                        topPadding:
                                                            4

                                                        bottomPadding:
                                                            4

                                                        background:
                                                            Rectangle {
                                                                color:
                                                                    "transparent"

                                                                border.color:
                                                                    parent.activeFocus
                                                                        ? Theme.primary
                                                                        : "transparent"
                                                            }

                                                        onEditingFinished: {
                                                            root.setCell(
                                                                parent.parent.parent.index,
                                                                index,
                                                                text
                                                            )
                                                        }
                                                    }
                                                }
                                        }
                                    }
                            }
                        }
                    }

                    // -------------------------------------------------
                    // EMPTY STATE
                    // -------------------------------------------------

                    Rectangle {
                        visible:
                            root.headers.length === 0

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
                                "Load a store template to begin."

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
