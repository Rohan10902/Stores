import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"
import "../theme"

Item {
    id: root

    property string master: ""
    property string upload: ""

    property int selected: -1
    property bool diffOnly: true

    property int total: 0
    property int correct: 0
    property int review: 0
    property int errors: 0
    property int attention: 0

    property string filterKey: ""

    property string detailMessage: ""
    property string detailStatus: ""

    property var suggestedKeys: []
    property string key1: "SID"
    property string key2: "Nielsen Store Code"

    ListModel {
        id: rowsModel
    }

    ListModel {
        id: insightsModel
    }

    ListModel {
        id: detailsModel
    }

    function urlToPath(value) {
        var text = String(value || "")
        var url = Qt.resolvedUrl(text)

        if (url.indexOf("file:///") === 0)
            url = url.substring(8)
        else if (url.indexOf("file://") === 0)
            url = url.substring(7)

        if (Qt.platform.os === "windows") {
            url = url.replace(/^\/+/, "")
        }

        try {
            return decodeURIComponent(url)
        } catch (e) {
            return url
        }
    }

    function backendAvailable() {
        return typeof backend !== "undefined" &&
               backend !== null &&
               backend.validate !== undefined &&
               backend.validate !== null
    }

    function statusColor(status) {
        var value = String(status || "").toUpperCase()

        if (value === "ERROR")
            return Theme.error

        if (value === "REVIEW" || value === "WARNING")
            return Theme.warning

        if (value === "CORRECT" || value === "OK")
            return Theme.success

        return Theme.textSecondary
    }

    function statusBackground(status) {
        var value = String(status || "").toUpperCase()

        if (value === "ERROR")
            return "#421820"

        if (value === "REVIEW" || value === "WARNING")
            return "#433614"

        if (value === "CORRECT" || value === "OK")
            return "#113426"

        return Theme.surface
    }

    function clearResults() {
        rowsModel.clear()
        insightsModel.clear()
        detailsModel.clear()

        selected = -1

        total = 0
        correct = 0
        review = 0
        errors = 0
        attention = 0

        detailMessage = ""
        detailStatus = ""
        filterKey = ""
    }

    function validateCurrentSelection() {
        if (!backendAvailable())
            return

        if (master === "" || upload === "")
            return

        var keys = []

        if (k1.currentText !== "")
            keys.push(k1.currentText)

        if (k2.currentText !== "(None)" &&
                k2.currentText !== "" &&
                k2.currentText !== k1.currentText) {
            keys.push(k2.currentText)
        }

        if (keys.length === 0)
            return

        clearResults()

        backend.validate.validate(JSON.stringify(keys))
    }

    function requestDetail(index) {
        if (!backendAvailable())
            return

        if (index < 0)
            return

        selected = index
        backend.validate.detail(index, diffOnly)
    }

    // =========================================================
    // FILE DIALOGS
    // =========================================================

    FileDialog {
        id: masterDialog

        title: "Select Master Dataset"

        nameFilters: [
            "Data (*.csv *.xlsx *.xls *.xlsm *.txt *.tsv *.json *.xml)",
            "All Files (*)"
        ]

        onAccepted: {
            root.master = root.urlToPath(selectedFile)

            if (root.backendAvailable()) {
                backend.validate.load_master(root.master)
            }
        }
    }

    FileDialog {
        id: uploadDialog

        title: "Select Uploaded / Country Dataset"

        nameFilters: [
            "Data (*.csv *.xlsx *.xls *.xlsm *.txt *.tsv *.json *.xml)",
            "All Files (*)"
        ]

        onAccepted: {
            root.upload = root.urlToPath(selectedFile)

            if (root.backendAvailable()) {
                backend.validate.load_upload(root.upload)
            }
        }
    }

    // =========================================================
    // BACKEND SIGNALS
    // =========================================================

    Connections {
        target: root.backendAvailable() ? backend.validate : null

        ignoreUnknownSignals: true

        function onMappingReady(payload) {
            try {
                var data = JSON.parse(payload)

                var keys = data.suggestedKeys || []

                root.suggestedKeys = keys

                if (keys.length > 0)
                    root.key1 = String(keys[0])

                if (keys.length > 1)
                    root.key2 = String(keys[1])
                else
                    root.key2 = "(None)"

            } catch (error) {
                root.suggestedKeys = []
            }
        }

        function onValidationReady(payload) {
            try {
                var data = JSON.parse(payload)

                root.total = Number(data.total || 0)
                root.correct = Number(data.correct || 0)
                root.review = Number(data.review || 0)
                root.errors = Number(data.errors || 0)
                root.attention = Number(data.attention || 0)

                root.filterKey = ""

                root.rowsModel.clear()
                root.insightsModel.clear()
                root.detailsModel.clear()

                root.selected = -1
                root.detailMessage = ""
                root.detailStatus = ""

                var rawRows = data.rows || []

                for (var i = 0; i < rawRows.length; ++i) {
                    var row = rawRows[i] || {}

                    root.rowsModel.append({
                        rowNum: String(
                            row.row !== undefined
                                ? row.row
                                : i + 1
                        ),

                        keyVal: String(
                            row.key !== undefined
                                ? row.key
                                : ""
                        ),

                        statusVal: String(
                            row.status !== undefined
                                ? row.status
                                : "UNKNOWN"
                        ).toUpperCase(),

                        msgVal: String(
                            row.message !== undefined
                                ? row.message
                                : ""
                        )
                    })
                }

                var rawInsights = data.insights || []

                for (var j = 0; j < rawInsights.length; ++j) {
                    var insight = rawInsights[j] || {}

                    root.insightsModel.append({
                        insightKey: String(
                            insight.key || ""
                        ),

                        title: String(
                            insight.title || ""
                        ),

                        count: String(
                            insight.count || "0"
                        ),

                        severity: String(
                            insight.severity || ""
                        ).toUpperCase(),

                        action: String(
                            insight.action || ""
                        )
                    })
                }

            } catch (error) {
                root.clearResults()
            }
        }

        function onDetailReady(payload) {
            try {
                var data = JSON.parse(payload)

                root.detailMessage = String(
                    data.message || ""
                )

                root.detailStatus = String(
                    data.status || ""
                ).toUpperCase()

                root.detailsModel.clear()

                var comparisons = data.comparisons || []

                for (var i = 0; i < comparisons.length; ++i) {
                    var comparison = comparisons[i] || {}

                    root.detailsModel.append({
                        fieldName: String(
                            comparison.field || ""
                        ),

                        masterValue:
                            comparison.master === undefined ||
                            comparison.master === null
                                ? ""
                                : String(comparison.master),

                        uploadedValue:
                            comparison.uploaded === undefined ||
                            comparison.uploaded === null
                                ? ""
                                : String(comparison.uploaded),

                        resultText: String(
                            comparison.result || ""
                        ),

                        severityText: String(
                            comparison.severity || ""
                        ).toUpperCase()
                    })
                }

            } catch (error) {
                root.detailMessage = ""
                root.detailStatus = ""
                root.detailsModel.clear()
            }
        }
    }

    // =========================================================
    // PAGE
    // =========================================================

    ScrollView {
        id: scrollView

        anchors.fill: parent

        clip: true

        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        ColumnLayout {
            id: content

            width: scrollView.availableWidth

            spacing: Theme.spacingLarge

            // =================================================
            // TITLE
            // =================================================

            PageTitle {
                Layout.fillWidth: true

                Layout.leftMargin: Theme.spacingXLarge
                Layout.rightMargin: Theme.spacingXLarge
                Layout.topMargin: Theme.spacingLarge

                title: "Compare & Validate"

                subtitle:
                    "Match and validate uploaded store data against the Master dataset."
            }

            // =================================================
            // DATASET CARD
            // =================================================

            Card {
                Layout.fillWidth: true

                Layout.leftMargin: Theme.spacingXLarge
                Layout.rightMargin: Theme.spacingXLarge

                Layout.preferredHeight: 190

                ColumnLayout {
                    anchors.fill: parent

                    anchors.margins: Theme.spacingMedium

                    spacing: Theme.spacingMedium

                    // -----------------------------------------
                    // MASTER
                    // -----------------------------------------

                    RowLayout {
                        Layout.fillWidth: true

                        spacing: Theme.spacingMedium

                        Text {
                            text: "Master Dataset"

                            color: Theme.textSecondary

                            font.bold: true

                            Layout.preferredWidth: 125
                        }

                        TextField {
                            Layout.fillWidth: true

                            readOnly: true

                            text: root.master

                            placeholderText:
                                "No master dataset selected"

                            color: Theme.textPrimary

                            background: Rectangle {
                                color: Theme.background

                                border.color:
                                    root.master !== ""
                                        ? Theme.primary
                                        : Theme.border

                                radius: Theme.radiusMedium
                            }
                        }

                        AppButton {
                            text: "Browse"

                            onClicked:
                                masterDialog.open()
                        }
                    }

                    // -----------------------------------------
                    // UPLOAD
                    // -----------------------------------------

                    RowLayout {
                        Layout.fillWidth: true

                        spacing: Theme.spacingMedium

                        Text {
                            text: "Uploaded Dataset"

                            color: Theme.textSecondary

                            font.bold: true

                            Layout.preferredWidth: 125
                        }

                        TextField {
                            Layout.fillWidth: true

                            readOnly: true

                            text: root.upload

                            placeholderText:
                                "No uploaded dataset selected"

                            color: Theme.textPrimary

                            background: Rectangle {
                                color: Theme.background

                                border.color:
                                    root.upload !== ""
                                        ? Theme.primary
                                        : Theme.border

                                radius: Theme.radiusMedium
                            }
                        }

                        AppButton {
                            text: "Browse"

                            onClicked:
                                uploadDialog.open()
                        }
                    }

                    // -----------------------------------------
                    // MATCHING
                    // -----------------------------------------

                    RowLayout {
                        Layout.fillWidth: true

                        spacing: Theme.spacingSmall

                        Text {
                            text: "Match by"

                            color: Theme.textSecondary

                            font.bold: true

                            Layout.preferredWidth: 125
                        }

                        ComboBox {
                            id: k1

                            Layout.preferredWidth: 180

                            model: [
                                "SID",
                                "Nielsen Store Code"
                            ]

                            currentIndex:
                                Math.max(
                                    0,
                                    model.indexOf(root.key1)
                                )

                            onActivated: {
                                root.key1 = currentText
                            }

                            background: Rectangle {
                                color: Theme.background

                                border.color: Theme.border

                                radius: Theme.radiusMedium
                            }

                            contentItem: Text {
                                text:
                                    parent.currentIndex >= 0
                                        ? parent.currentText
                                        : ""

                                color: Theme.textPrimary

                                verticalAlignment:
                                    Text.AlignVCenter

                                leftPadding: 8
                            }
                        }

                        Text {
                            text: "+"

                            color: Theme.textSecondary

                            font.bold: true
                        }

                        ComboBox {
                            id: k2

                            Layout.preferredWidth: 200

                            model: [
                                "(None)",
                                "Nielsen Store Code",
                                "SID"
                            ]

                            currentIndex:
                                Math.max(
                                    0,
                                    model.indexOf(root.key2)
                                )

                            onActivated: {
                                root.key2 = currentText
                            }

                            background: Rectangle {
                                color: Theme.background

                                border.color: Theme.border

                                radius: Theme.radiusMedium
                            }

                            contentItem: Text {
                                text:
                                    parent.currentIndex >= 0
                                        ? parent.currentText
                                        : ""

                                color: Theme.textPrimary

                                verticalAlignment:
                                    Text.AlignVCenter

                                leftPadding: 8
                            }
                        }

                        Text {
                            Layout.fillWidth: true

                            text:
                                root.suggestedKeys.length > 0
                                    ? "Smart suggestion: "
                                      + root.suggestedKeys.join(" + ")
                                    : ""

                            color: Theme.info

                            elide:
                                Text.ElideRight

                            verticalAlignment:
                                Text.AlignVCenter
                        }

                        AppButton {
                            text: "Detect Columns"

                            enabled:
                                root.master !== "" &&
                                root.upload !== ""

                            onClicked: {
                                if (root.backendAvailable())
                                    backend.validate.detect()
                            }
                        }

                        PrimaryButton {
                            text: "Validate"

                            enabled:
                                root.master !== "" &&
                                root.upload !== ""

                            onClicked:
                                root.validateCurrentSelection()
                        }
                    }
                }
            }

            // =================================================
            // METRICS
            // =================================================

            RowLayout {
                Layout.fillWidth: true

                Layout.leftMargin: Theme.spacingXLarge
                Layout.rightMargin: Theme.spacingXLarge

                spacing: Theme.spacingMedium

                Repeater {
                    model: [
                        {
                            label: "TOTAL",
                            value: root.total,
                            color: Theme.primary
                        },
                        {
                            label: "CORRECT",
                            value: root.correct,
                            color: Theme.success
                        },
                        {
                            label: "REVIEW",
                            value: root.review,
                            color: Theme.warning
                        },
                        {
                            label: "ERROR",
                            value: root.errors,
                            color: Theme.error
                        }
                    ]

                    delegate: Card {
                        required property var modelData

                        Layout.fillWidth: true

                        Layout.preferredHeight: 78

                        ColumnLayout {
                            anchors.fill: parent

                            anchors.margins:
                                Theme.spacingSmall

                            spacing: 2

                            Text {
                                text: modelData.value

                                color: modelData.color

                                font.pixelSize: 22

                                font.bold: true

                                Layout.alignment:
                                    Qt.AlignHCenter
                            }

                            Text {
                                text: modelData.label

                                color: Theme.textSecondary

                                font.pixelSize: 10

                                font.bold: true

                                Layout.alignment:
                                    Qt.AlignHCenter
                            }
                        }
                    }
                }
            }

            // =================================================
            // VALIDATION INTELLIGENCE
            // =================================================

            Card {
                Layout.fillWidth: true

                Layout.leftMargin: Theme.spacingXLarge
                Layout.rightMargin: Theme.spacingXLarge

                visible:
                    root.insightsModel.count > 0

                Layout.preferredHeight:
                    visible ? 128 : 0

                ColumnLayout {
                    anchors.fill: parent

                    anchors.margins:
                        Theme.spacingMedium

                    spacing: Theme.spacingSmall

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text:
                                "Validation Intelligence"

                            color: Theme.textPrimary

                            font.bold: true
                        }

                        Text {
                            text:
                                root.attention
                                + " finding(s) need attention"

                            color: Theme.textSecondary

                            font.pixelSize: 11
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        AppButton {
                            text:
                                root.filterKey === ""
                                    ? "All Records"
                                    : "Show All"

                            onClicked:
                                root.filterKey = ""
                        }
                    }

                    ListView {
                        Layout.fillWidth: true

                        Layout.fillHeight: true

                        orientation:
                            ListView.Horizontal

                        spacing:
                            Theme.spacingSmall

                        clip: true

                        model:
                            root.insightsModel

                        delegate: Rectangle {
                            required property string insightKey
                            required property string title
                            required property string count
                            required property string severity
                            required property string action

                            width: 255
                            height: 68

                            radius:
                                Theme.radiusMedium

                            color:
                                root.filterKey === insightKey
                                    ? Theme.surfaceHover
                                    : statusBackground(severity)

                            border.color:
                                root.filterKey === insightKey
                                    ? Theme.primary
                                    : Theme.border

                            MouseArea {
                                anchors.fill: parent

                                onClicked:
                                    root.filterKey =
                                        insightKey
                            }

                            ColumnLayout {
                                anchors.fill: parent

                                anchors.margins:
                                    Theme.spacingSmall

                                spacing: 2

                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        text: count

                                        color:
                                            statusColor(
                                                severity
                                            )

                                        font.pixelSize: 16

                                        font.bold: true
                                    }

                                    Text {
                                        text: title

                                        color:
                                            Theme.textPrimary

                                        font.bold: true

                                        elide:
                                            Text.ElideRight

                                        Layout.fillWidth: true
                                    }
                                }

                                Text {
                                    text: action

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
                }
            }

            // =================================================
            // RESULTS / INSPECTOR
            // =================================================

            Card {
                Layout.fillWidth: true

                Layout.leftMargin: Theme.spacingXLarge
                Layout.rightMargin: Theme.spacingXLarge

                Layout.preferredHeight: 620

                ColumnLayout {
                    anchors.fill: parent

                    anchors.margins:
                        Theme.spacingMedium

                    spacing:
                        Theme.spacingMedium

                    // -----------------------------------------
                    // RESULTS HEADER
                    // -----------------------------------------

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "Validation Results"

                            color: Theme.textPrimary

                            font.pixelSize: 15

                            font.bold: true
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Text {
                            visible:
                                root.filterKey !== ""

                            text:
                                "Filter: "
                                + root.filterKey

                            color:
                                Theme.info

                            font.pixelSize: 11
                        }
                    }

                    // -----------------------------------------
                    // RESULTS TABLE HEADER
                    // -----------------------------------------

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

                            spacing:
                                Theme.spacingSmall

                            Text {
                                text: "Row"

                                color:
                                    Theme.textSecondary

                                font.bold: true

                                Layout.preferredWidth: 60
                            }

                            Text {
                                text: "Key"

                                color:
                                    Theme.textSecondary

                                font.bold: true

                                Layout.preferredWidth: 190
                            }

                            Text {
                                text: "Status"

                                color:
                                    Theme.textSecondary

                                font.bold: true

                                Layout.preferredWidth: 90
                            }

                            Text {
                                text: "Message"

                                color:
                                    Theme.textSecondary

                                font.bold: true

                                Layout.fillWidth: true
                            }
                        }
                    }

                    // -----------------------------------------
                    // RESULTS
                    // -----------------------------------------

                    ListView {
                        id: resultsListView

                        Layout.fillWidth: true

                        Layout.fillHeight: true

                        model:
                            root.rowsModel

                        clip: true

                        spacing: 1

                        ScrollBar.vertical:
                            ScrollBar {}

                        delegate: Rectangle {
                            required property int index

                            required property string rowNum
                            required property string keyVal
                            required property string statusVal
                            required property string msgVal

                            readonly property bool matchesFilter:
                                root.filterKey === "" ||
                                statusVal === root.filterKey

                            width:
                                resultsListView.width

                            height:
                                matchesFilter ? 38 : 0

                            visible:
                                matchesFilter

                            color:
                                root.selected === index
                                    ? Theme.surfaceHover
                                    : (
                                        index % 2 === 0
                                            ? Theme.background
                                            : Theme.surface
                                      )

                            border.color:
                                root.selected === index
                                    ? Theme.primary
                                    : Theme.border

                            border.width:
                                root.selected === index
                                    ? 1
                                    : 0

                            Behavior on color {
                                ColorAnimation {
                                    duration:
                                        Theme.durationFast
                                }
                            }

                            MouseArea {
                                anchors.fill: parent

                                onClicked:
                                    root.requestDetail(index)
                            }

                            RowLayout {
                                anchors.fill: parent

                                anchors.leftMargin:
                                    Theme.spacingSmall

                                anchors.rightMargin:
                                    Theme.spacingSmall

                                spacing:
                                    Theme.spacingSmall

                                Text {
                                    text: rowNum

                                    color:
                                        Theme.textSecondary

                                    Layout.preferredWidth: 60
                                }

                                Text {
                                    text: keyVal

                                    color:
                                        Theme.textPrimary

                                    Layout.preferredWidth: 190

                                    elide:
                                        Text.ElideRight
                                }

                                Text {
                                    text: statusVal

                                    color:
                                        statusColor(statusVal)

                                    font.bold: true

                                    Layout.preferredWidth: 90
                                }

                                Text {
                                    text: msgVal

                                    color:
                                        Theme.textPrimary

                                    Layout.fillWidth: true

                                    elide:
                                        Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }

            // =================================================
            // COMPARISON INSPECTOR
            // =================================================

            Card {
                Layout.fillWidth: true

                Layout.leftMargin: Theme.spacingXLarge
                Layout.rightMargin: Theme.spacingXLarge

                Layout.bottomMargin:
                    Theme.spacingXLarge

                Layout.preferredHeight: 560

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
                                "Error-aware Comparison Inspector"

                            color:
                                Theme.textPrimary

                            font.pixelSize: 15

                            font.bold: true
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        CheckBox {
                            text: "Differences only"

                            checked:
                                root.diffOnly

                            onToggled: {
                                root.diffOnly =
                                    checked

                                if (root.selected >= 0)
                                    root.requestDetail(
                                        root.selected
                                    )
                            }

                            contentItem: Text {
                                text:
                                    parent.text

                                color:
                                    Theme.textPrimary

                                leftPadding:
                                    parent.indicator.width + 4

                                verticalAlignment:
                                    Text.AlignVCenter
                            }
                        }
                    }

                    Rectangle {
                        visible:
                            root.selected >= 0

                        Layout.fillWidth: true

                        height: visible ? 48 : 0

                        radius:
                            Theme.radiusMedium

                        color:
                            statusBackground(
                                root.detailStatus
                            )

                        border.color:
                            Theme.border

                        Text {
                            anchors.fill: parent

                            anchors.margins:
                                Theme.spacingSmall

                            text:
                                root.detailMessage !== ""
                                    ? root.detailMessage
                                    : "No issue description available."

                            color:
                                Theme.textPrimary

                            wrapMode:
                                Text.WordWrap

                            verticalAlignment:
                                Text.AlignVCenter
                        }
                    }

                    Rectangle {
                        visible:
                            root.selected < 0

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
                                root.rowsModel.count === 0
                                    ? "Run validation to inspect comparison details."
                                    : "Select a validation result to inspect its differences."

                            color:
                                Theme.textMuted

                            font.pixelSize: 13
                        }
                    }

                    RowLayout {
                        visible:
                            root.selected >= 0

                        Layout.fillWidth: true

                        spacing:
                            Theme.spacingSmall

                        Text {
                            text: "Field"

                            color:
                                Theme.textSecondary

                            font.bold: true

                            Layout.preferredWidth: 160
                        }

                        Text {
                            text: "Master Value"

                            color:
                                Theme.textSecondary

                            font.bold: true

                            Layout.fillWidth: true
                        }

                        Text {
                            text:
                                "Uploaded / Updated Value"

                            color:
                                Theme.textSecondary

                            font.bold: true

                            Layout.fillWidth: true
                        }

                        Text {
                            text: "Result"

                            color:
                                Theme.textSecondary

                            font.bold: true

                            Layout.preferredWidth: 120
                        }
                    }

                    ListView {
                        id: detailsListView

                        visible:
                            root.selected >= 0

                        Layout.fillWidth: true

                        Layout.fillHeight: true

                        model:
                            root.detailsModel

                        clip: true

                        ScrollBar.vertical:
                            ScrollBar {}

                        delegate: Rectangle {
                            required property string fieldName
                            required property string masterValue
                            required property string uploadedValue
                            required property string resultText
                            required property string severityText

                            width:
                                detailsListView.width

                            height: 36

                            color:
                                statusBackground(
                                    severityText
                                )

                            border.color:
                                Theme.border

                            RowLayout {
                                anchors.fill: parent

                                anchors.leftMargin:
                                    Theme.spacingSmall

                                anchors.rightMargin:
                                    Theme.spacingSmall

                                spacing:
                                    Theme.spacingSmall

                                Text {
                                    text:
                                        fieldName

                                    color:
                                        Theme.textPrimary

                                    font.bold: true

                                    Layout.preferredWidth: 160

                                    elide:
                                        Text.ElideRight
                                }

                                Text {
                                    text:
                                        masterValue === ""
                                            ? "—"
                                            : masterValue

                                    color:
                                        masterValue === ""
                                            ? Theme.textMuted
                                            : Theme.textPrimary

                                    Layout.fillWidth: true

                                    elide:
                                        Text.ElideRight
                                }

                                Text {
                                    text:
                                        uploadedValue === ""
                                            ? "—"
                                            : uploadedValue

                                    color:
                                        uploadedValue === ""
                                            ? Theme.textMuted
                                            : Theme.textPrimary

                                    Layout.fillWidth: true

                                    elide:
                                        Text.ElideRight
                                }

                                Text {
                                    text:
                                        resultText

                                    color:
                                        statusColor(
                                            severityText
                                        )

                                    font.bold: true

                                    Layout.preferredWidth: 120

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
