// qml/pages/ComparePage.qml
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
    property bool diff: true

    property int total: 0
    property int ok: 0
    property int rev: 0
    property int err: 0
    property int attention: 0
    property string filterKey: ""

    property string detailProblem: ""
    property string detailStatus: ""
    property var detailContext: ({})
    property var suggestedKeys: []
    property string key1: "SID"
    property string key2: "Nielsen Store Code"

    ListModel { id: rows }
    ListModel { id: details }
    ListModel { id: related }
    ListModel { id: insights }

    FileDialog {
        id: md
        title: "Select Master Dataset"
        nameFilters: ["Data (*.csv *.xlsx *.xls *.xlsm *.txt *.tsv *.json *.xml)"]
        onAccepted: {
            master = selectedFile.toString()
            if (typeof backend !== "undefined") {
                backend.loadMaster(master)
            }
        }
    }

    FileDialog {
        id: ud
        title: "Select Uploaded / Country File"
        nameFilters: ["Data (*.csv *.xlsx *.xls *.xlsm *.txt *.tsv *.json *.xml)"]
        onAccepted: {
            upload = selectedFile.toString()
            if (typeof backend !== "undefined") {
                backend.loadUpload(upload)
            }
        }
    }

    Connections {
        target: typeof backend !== "undefined" ? backend : null
        ignoreUnknownSignals: true

        function onMappingReady(p) {
            try {
                var d = JSON.parse(p)
                suggestedKeys = d.suggestedKeys || ["SID"]
                key1 = suggestedKeys[0] || "SID"
                key2 = suggestedKeys.length > 1 ? suggestedKeys[1] : "(None)"
            } catch (e) {
                // Safe parsing fallback
            }
        }

        function onValidationReady(p) {
            try {
                var d = JSON.parse(p)
                total = d.total || 0
                ok = d.correct || 0
                rev = d.review || 0
                err = d.errors || 0
                attention = d.attention || 0
                filterKey = ""
                rows.clear()
                insights.clear()
                details.clear()
                related.clear()
                selected = -1

                var rawRows = d.rows || []
                for (var i = 0; i < rawRows.length; i++) {
                    var r = rawRows[i]
                    rows.append({
                        row: String(r.row || ""),
                        sid: String(r.sid || ""),
                        store: String(r.storeName || ""),
                        status: String(r.status || ""),
                        problem: String(r.problem || ""),
                        categoriesJson: JSON.stringify(r.categories || [])
                    })
                }

                var rawInsights = d.insights || []
                for (var j = 0; j < rawInsights.length; j++) {
                    var x = rawInsights[j]
                    insights.append({
                        key: String(x.key || ""),
                        title: String(x.title || ""),
                        count: String(x.count || ""),
                        severity: String(x.severity || ""),
                        action: String(x.action || "")
                    })
                }
            } catch (e) {
                // Safe parsing fallback
            }
        }

        function onDetailReady(p) {
            try {
                var d = JSON.parse(p)
                detailProblem = d.problem || ""
                detailStatus = d.status || ""
                detailContext = d.context || {}
                details.clear()
                related.clear()

                var rawFields = d.rows || []
                for (var i = 0; i < rawFields.length; i++) {
                    var r = rawFields[i]
                    details.append({
                        fieldName: String(r.field || ""),
                        masterValue: r.master === undefined || r.master === null ? "" : String(r.master),
                        uploadedValue: r.uploaded === undefined || r.uploaded === null ? "" : String(r.uploaded),
                        resultText: String(r.result || ""),
                        severityText: String(r.severity || "")
                    })
                }

                var rr = (detailContext.relatedUploaded || [])
                for (var j = 0; j < rr.length; j++) {
                    related.append({
                        row: String(rr[j].row || ""),
                        sid: String(rr[j].sid || ""),
                        nielsen: String(rr[j].nielsen || ""),
                        store: String(rr[j].storeName || "")
                    })
                }
            } catch (e) {
                // Safe parsing fallback
            }
        }
    }

    ScrollView {
        id: scrollView
        anchors.fill: parent
        clip: true

        ColumnLayout {
            width: scrollView.availableWidth
            anchors.margins: Theme.spacingXLarge
            spacing: Theme.spacingLarge

            PageTitle {
                title: "Compare & Validate"
                subtitle: "Row-order-independent master vs uploaded store comparison."
                Layout.fillWidth: true
            }

            // 1. FILE SELECTION CARD
            Card {
                Layout.fillWidth: true
                Layout.preferredHeight: 140

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMedium
                    spacing: Theme.spacingSmall

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingMedium

                        TextField {
                            Layout.fillWidth: true
                            readOnly: true
                            text: root.master
                            placeholderText: "Master file path..."
                            color: Theme.textPrimary
                            background: Rectangle {
                                color: Theme.background
                                border.color: Theme.border
                                radius: Theme.radiusMedium
                            }
                        }

                        AppButton {
                            text: "Browse Master"
                            onClicked: md.open()
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingMedium

                        TextField {
                            Layout.fillWidth: true
                            readOnly: true
                            text: root.upload
                            placeholderText: "Uploaded / country file path..."
                            color: Theme.textPrimary
                            background: Rectangle {
                                color: Theme.background
                                border.color: Theme.border
                                radius: Theme.radiusMedium
                            }
                        }

                        AppButton {
                            text: "Browse Upload"
                            onClicked: ud.open()
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingMedium

                        Text { text: "Match by"; color: Theme.textSecondary }

                        ComboBox {
                            id: k1
                            Layout.preferredWidth: 180
                            model: ["SID", "Nielsen Store Code"]
                            currentIndex: Math.max(0, model.indexOf(key1))
                            onActivated: key1 = currentText
                            background: Rectangle { color: Theme.background; border.color: Theme.border; radius: Theme.radiusMedium }
                            contentItem: Text { text: parent.currentIndex >= 0 ? parent.currentText : ""; color: Theme.textPrimary; verticalAlignment: Text.AlignVCenter; leftPadding: 8 }
                        }

                        Text { text: "+"; color: Theme.textSecondary }

                        ComboBox {
                            id: k2
                            Layout.preferredWidth: 200
                            model: ["(None)", "Nielsen Store Code", "SID"]
                            currentIndex: Math.max(0, model.indexOf(key2))
                            onActivated: key2 = currentText
                            background: Rectangle { color: Theme.background; border.color: Theme.border; radius: Theme.radiusMedium }
                            contentItem: Text { text: parent.currentIndex >= 0 ? parent.currentText : ""; color: Theme.textPrimary; verticalAlignment: Text.AlignVCenter; leftPadding: 8 }
                        }

                        Text {
                            text: suggestedKeys.length ? "Smart suggestion: " + suggestedKeys.join(" + ") : ""
                            color: Theme.info
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        AppButton {
                            text: "Detect Columns"
                            enabled: root.master !== "" && root.upload !== ""
                            onClicked: {
                                if (typeof backend !== "undefined") {
                                    backend.detect()
                                }
                            }
                        }

                        PrimaryButton {
                            text: "Validate"
                            enabled: root.master !== "" && root.upload !== ""
                            onClicked: {
                                var a = [k1.currentText]
                                if (k2.currentText !== "(None)" && k2.currentText !== k1.currentText) {
                                    a.push(k2.currentText)
                                }
                                if (typeof backend !== "undefined") {
                                    backend.validate(JSON.stringify(a))
                                }
                            }
                        }
                    }
                }
            }

            // 2. COUNTERS ROW
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingMedium

                Repeater {
                    model: [
                        ["TOTAL", total, Theme.primary],
                        ["CORRECT", ok, Theme.success],
                        ["REVIEW", rev, Theme.warning],
                        ["ERROR", err, Theme.error]
                    ]

                    delegate: Card {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 70

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingSmall
                            spacing: 2

                            Text {
                                text: modelData[1]
                                color: modelData[2]
                                font.pixelSize: 20
                                font.bold: true
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: modelData[0]
                                color: Theme.textSecondary
                                font.pixelSize: 10
                                font.bold: true
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                }
            }

            // 3. VALIDATION INTELLIGENCE
            Card {
                Layout.fillWidth: true
                Layout.preferredHeight: insights.count > 0 ? 120 : 0
                visible: insights.count > 0

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMedium
                    spacing: Theme.spacingSmall

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "Validation Intelligence   " + attention + " finding(s) need attention"
                            color: Theme.textPrimary
                            font.bold: true
                        }
                        Item { Layout.fillWidth: true }
                        AppButton {
                            text: filterKey ? "Show All" : "All Records"
                            onClicked: filterKey = ""
                        }
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 65
                        orientation: ListView.Horizontal
                        spacing: Theme.spacingSmall
                        model: insights
                        clip: true

                        delegate: Rectangle {
                            required property string key
                            required property string title
                            required property string count
                            required property string severity
                            required property string action

                            width: 250
                            height: 65
                            radius: Theme.radiusMedium
                            color: filterKey === key ? Theme.surfaceHover : (severity === "ERROR" ? "#421820" : "#433614")
                            border.color: filterKey === key ? Theme.primary : Theme.border

                            MouseArea {
                                anchors.fill: parent
                                onClicked: filterKey = key
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingSmall
                                spacing: 2

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.spacingSmall
                                    Text {
                                        text: count
                                        color: severity === "ERROR" ? Theme.error : Theme.warning
                                        font.bold: true
                                        font.pixelSize: 16
                                    }
                                    Text {
                                        text: title
                                        color: Theme.textPrimary
                                        font.bold: true
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }
                                Text {
                                    text: action
                                    color: Theme.textSecondary
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }
            }

            // 4. VALIDATION RESULTS & COMPARISON INSPECTOR (SPLIT VIEW)
            SplitView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 500
                orientation: Qt.Vertical

                // Top Pane: Validation Results List
                Card {
                    SplitView.minimumHeight: 180
                    SplitView.preferredHeight: 220

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingMedium
                        spacing: Theme.spacingSmall

                        Text {
                            text: "Validation Results   (row order does not affect matching)"
                            color: Theme.textPrimary
                            font.bold: true
                        }

                        // Table Header
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            color: Theme.surfaceHover
                            border.color: Theme.border

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingSmall
                                anchors.rightMargin: Theme.spacingSmall
                                spacing: Theme.spacingSmall

                                Text { text: "Row"; color: Theme.textSecondary; font.bold: true; Layout.preferredWidth: 50 }
                                Text { text: "SID"; color: Theme.textSecondary; font.bold: true; Layout.preferredWidth: 120 }
                                Text { text: "Store Name"; color: Theme.textSecondary; font.bold: true; Layout.fillWidth: true }
                                Text { text: "Status"; color: Theme.textSecondary; font.bold: true; Layout.preferredWidth: 90 }
                                Text { text: "Problem"; color: Theme.textSecondary; font.bold: true; Layout.preferredWidth: 180 }
                            }
                        }

                        ListView {
                            id: resultsListView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            model: rows
                            clip: true

                            delegate: Rectangle {
                                required property int index
                                required property string row
                                required property string sid
                                required property string store
                                required property string status
                                required property string problem
                                required property string categoriesJson

                                width: resultsListView.width
                                height: (filterKey === "" || categoriesJson.indexOf(filterKey) >= 0) ? 36 : 0
                                visible: height > 0
                                color: selected === index ? Theme.surfaceHover : (index % 2 === 0 ? Theme.background : Theme.surface)
                                border.color: Theme.border
                                border.width: 1

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        selected = index
                                        if (typeof backend !== "undefined") {
                                            backend.detail(index, diff)
                                        }
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingSmall
                                    anchors.rightMargin: Theme.spacingSmall
                                    spacing: Theme.spacingSmall

                                    Text { text: row; color: Theme.textSecondary; Layout.preferredWidth: 50 }
                                    Text { text: sid; color: Theme.textPrimary; Layout.preferredWidth: 120; elide: Text.ElideRight }
                                    Text { text: store; color: Theme.textPrimary; Layout.fillWidth: true; elide: Text.ElideRight }
                                    Text {
                                        text: status
                                        color: status === "ERROR" ? Theme.error : (status === "REVIEW" ? Theme.warning : Theme.success)
                                        font.bold: true
                                        Layout.preferredWidth: 90
                                    }
                                    Text { text: problem; color: Theme.textPrimary; Layout.preferredWidth: 180; elide: Text.ElideRight }
                                }
                            }
                        }
                    }
                }

                // Bottom Pane: Error-aware Comparison Inspector
                Card {
                    SplitView.minimumHeight: 220
                    SplitView.fillHeight: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingMedium
                        spacing: Theme.spacingSmall

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Error-aware Comparison Inspector"
                                color: Theme.textPrimary
                                font.bold: true
                            }
                            Item { Layout.fillWidth: true }
                            CheckBox {
                                text: "Differences only"
                                checked: diff
                                onToggled: {
                                    diff = checked
                                    if (selected >= 0 && typeof backend !== "undefined") {
                                        backend.detail(selected, diff)
                                    }
                                }
                                contentItem: Text { text: parent.text; color: Theme.textPrimary; leftPadding: parent.indicator.width + 4; verticalAlignment: Text.AlignVCenter }
                            }
                        }

                        // Problem Banner
                        Rectangle {
                            visible: selected >= 0
                            Layout.fillWidth: true
                            implicitHeight: 45
                            radius: Theme.radiusMedium
                            color: detailStatus === "ERROR" ? "#421820" : (detailStatus === "REVIEW" ? "#433614" : "#113426")
                            border.color: Theme.border

                            Text {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingSmall
                                text: detailProblem
                                color: Theme.textPrimary
                                wrapMode: Text.WordWrap
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        // Related identities notice
                        Text {
                            visible: related.count > 1
                            text: "Related uploaded records for this identity:"
                            color: Theme.warning
                            font.bold: true
                        }

                        ListView {
                            visible: related.count > 1
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(65, related.count * 24)
                            model: related
                            clip: true

                            delegate: RowLayout {
                                required property string row
                                required property string sid
                                required property string nielsen
                                required property string store

                                width: ListView.view.width
                                height: 24
                                spacing: Theme.spacingSmall

                                Text { text: "Row " + row; color: Theme.textSecondary; Layout.preferredWidth: 70 }
                                Text { text: sid; color: Theme.textPrimary; Layout.preferredWidth: 110; elide: Text.ElideRight }
                                Text { text: nielsen; color: Theme.info; Layout.preferredWidth: 150; elide: Text.ElideRight }
                                Text { text: store; color: Theme.textPrimary; Layout.fillWidth: true; elide: Text.ElideRight }
                            }
                        }

                        // Field Comparison Table Header
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingSmall
                            Text { text: "Field"; color: Theme.textSecondary; font.bold: true; Layout.preferredWidth: 160 }
                            Text { text: "Master Value"; color: Theme.textSecondary; font.bold: true; Layout.fillWidth: true }
                            Text { text: "Uploaded / Updated Value"; color: Theme.textSecondary; font.bold: true; Layout.fillWidth: true }
                            Text { text: "Result"; color: Theme.textSecondary; font.bold: true; Layout.preferredWidth: 120 }
                        }

                        // Field Comparison Table Body
                        ListView {
                            id: detailsListView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            model: details
                            clip: true

                            delegate: Rectangle {
                                required property string fieldName
                                required property string masterValue
                                required property string uploadedValue
                                required property string resultText
                                required property string severityText

                                width: detailsListView.width
                                height: 32
                                color: severityText === "ERROR" ? "#421820" : (severityText === "REVIEW" ? "#433614" : "#113426")
                                border.color: Theme.border
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingSmall
                                    anchors.rightMargin: Theme.spacingSmall
                                    spacing: Theme.spacingSmall

                                    Text { text: fieldName; color: Theme.textPrimary; font.bold: true; Layout.preferredWidth: 160; elide: Text.ElideRight }
                                    Text { text: masterValue === "" ? "—" : masterValue; color: masterValue === "" ? Theme.textMuted : Theme.textPrimary; Layout.fillWidth: true; elide: Text.ElideRight; ToolTip.visible: hoverHandlerMaster.hovered; ToolTip.text: text; HoverHandler { id: hoverHandlerMaster } }
                                    Text { text: uploadedValue === "" ? "—" : uploadedValue; color: uploadedValue === "" ? Theme.textMuted : Theme.textPrimary; Layout.fillWidth: true; elide: Text.ElideRight; ToolTip.visible: hoverHandlerUpload.hovered; ToolTip.text: text; HoverHandler { id: hoverHandlerUpload } }
                                    Text {
                                        text: resultText
                                        color: severityText === "ERROR" ? Theme.error : (severityText === "REVIEW" ? Theme.warning : Theme.success)
                                        font.bold: true
                                        Layout.preferredWidth: 120
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
