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

    property int totalRows: 0
    property int displayedRows: 0
    property bool truncated: false

    property string searchText: ""
    property string searchColumn: ""

    property string sqlText: ""

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
        if (!root.backendAvailable())
            return

        if (root.sourcePath === "")
            return

        backend.health.load_data(
            root.sourcePath
        )
    }

    function executeSearch() {
        if (!root.backendAvailable())
            return

        if (root.searchText === "")
            return

        backend.health.search(
            root.searchText,
            root.searchColumn
        )
    }

    function executeSql() {
        if (!root.backendAvailable())
            return

        if (root.sqlText.trim() === "")
            return

        backend.health.sql(
            root.sqlText
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

            } catch (error) {
                root.columns = []
                root.rows = []
                root.totalRows = 0
                root.displayedRows = 0
                root.truncated = false
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

            PageTitle {
                Layout.fillWidth: true

                Layout.leftMargin:
                    Theme.spacingXLarge

                Layout.rightMargin:
                    Theme.spacingXLarge

                Layout.topMargin:
                    Theme.spacingLarge

                title:
                    "Explore Data"

                subtitle:
                    "Search, inspect, and query your loaded dataset."
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
                    anchors.fill: parent

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
                            "Select CSV or spreadsheet"

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
                            "Load"

                        enabled:
                            root.sourcePath !== ""

                        onClicked:
                            root.loadData()
                    }
                }
            }

            // =================================================
            // STATS
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
                                root.displayedRows

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
                                "DISPLAYED"

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
                                    ? "YES"
                                    : "NO"

                            color:
                                root.truncated
                                    ? Theme.warning
                                    : Theme.success

                            font.pixelSize:
                                18

                            font.bold:
                                true

                            Layout.alignment:
                                Qt.AlignHCenter
                        }

                        Text {
                            text:
                                "TRUNCATED"

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
            // SEARCH
            // =================================================

            Card {
                Layout.fillWidth:
                    true

                Layout.leftMargin:
                    Theme.spacingXLarge

                Layout.rightMargin:
                    Theme.spacingXLarge

                Layout.preferredHeight:
                    120

                ColumnLayout {
                    anchors.fill:
                        parent

                    anchors.margins:
                        Theme.spacingMedium

                    spacing:
                        Theme.spacingSmall

                    Text {
                        text:
                            "Search Dataset"

                        color:
                            Theme.textPrimary

                        font.pixelSize:
                            14

                        font.bold:
                            true
                    }

                    RowLayout {
                        Layout.fillWidth:
                            true

                        ComboBox {
                            id: columnCombo

                            Layout.preferredWidth:
                                220

                            model:
                                ["All Columns"].concat(
                                    root.columns
                                )

                            onCurrentTextChanged: {
                                root.searchColumn =
                                    currentIndex <= 0
                                        ? ""
                                        : currentText
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

                        TextField {
                            Layout.fillWidth:
                                true

                            placeholderText:
                                "Search for a value..."

                            text:
                                root.searchText

                            color:
                                Theme.textPrimary

                            onAccepted:
                                root.executeSearch()

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
                                "Search"

                            enabled:
                                root.searchText.trim() !== ""

                            onClicked:
                                root.executeSearch()
                        }

                        AppButton {
                            text:
                                "Clear"

                            onClicked: {
                                root.searchText = ""
                                root.loadData()
                            }
                        }
                    }
                }
            }

            // =================================================
            // SQL
            // =================================================

            Card {
                Layout.fillWidth:
                    true

                Layout.leftMargin:
                    Theme.spacingXLarge

                Layout.rightMargin:
                    Theme.spacingXLarge

                Layout.preferredHeight:
                    150

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
                                "SQL Query"

                            color:
                                Theme.textPrimary

                            font.pixelSize:
                                14

                            font.bold:
                                true
                        }

                        Item {
                            Layout.fillWidth:
                                true
                        }

                        Text {
                            text:
                                "Run against the loaded dataset"

                            color:
                                Theme.textSecondary

                            font.pixelSize:
                                10
                        }
                    }

                    TextArea {
                        Layout.fillWidth:
                            true

                        Layout.fillHeight:
                            true

                        text:
                            root.sqlText

                        placeholderText:
                            "SELECT * FROM data LIMIT 100"

                        color:
                            Theme.textPrimary

                        wrapMode:
                            TextEdit.NoWrap

                        onTextChanged:
                            root.sqlText = text

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

                    RowLayout {
                        Layout.fillWidth:
                            true

                        Item {
                            Layout.fillWidth:
                                true
                        }

                        AppButton {
                            text:
                                "Reset"

                            onClicked:
                                root.sqlText = ""
                        }

                        PrimaryButton {
                            text:
                                "Run SQL"

                            enabled:
                                root.sqlText.trim() !== ""

                            onClicked:
                                root.executeSql()
                        }
                    }
                }
            }

            // =================================================
            // RESULTS
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
                            visible:
                                root.truncated

                            text:
                                "Showing "
                                + root.displayedRows
                                + " of "
                                + root.totalRows

                            color:
                                Theme.warning

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

                            // -----------------------------------------
                            // HEADER
                            // -----------------------------------------

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

                            // -----------------------------------------
                            // ROWS
                            // -----------------------------------------

                            Repeater {
                                model:
                                    root.rows

                                delegate:
                                    Row {
                                        required property var modelData
                                        required property int index

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
                                                    required property int index

                                                    width:
                                                        160

                                                    height:
                                                        40

                                                    color:
                                                        parent &&
                                                        parent.parent &&
                                                        parent.parent.index % 2 === 0
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
                                                                parent.parent.modelData,
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
                                    : "No rows returned."

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
