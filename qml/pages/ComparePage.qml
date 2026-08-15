pragma ComponentBehavior: Bound

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
    property string key1: "SID"
    property string key2: "Nielsen Store Code"
    property var suggestedKeys: []
    property var resultRows: []
    property var insightRows: []
    property var detailRows: []
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

    function backendAvailable() {
        return typeof backend !== "undefined" && backend !== null && backend.validate !== undefined && backend.validate !== null
    }
    function urlToPath(value) {
        var text = String(value || "")
        if (text.indexOf("file:///") === 0) text = text.substring(8)
        else if (text.indexOf("file://") === 0) text = text.substring(7)
        if (Qt.platform.os === "windows") text = text.replace(/^\/+/, "")
        try { return decodeURIComponent(text) } catch (error) { return text }
    }
    function statusColor(status) {
        var value = String(status || "").toUpperCase()
        if (value === "ERROR") return Theme.error
        if (value === "REVIEW" || value === "WARNING") return Theme.warning
        if (value === "CORRECT" || value === "OK") return Theme.success
        return Theme.textSecondary
    }
    function statusBackground(status) {
        var value = String(status || "").toUpperCase()
        if (value === "ERROR") return "#421820"
        if (value === "REVIEW" || value === "WARNING") return "#433614"
        if (value === "CORRECT" || value === "OK") return "#113426"
        return Theme.surface
    }
    function clearResults() {
        root.resultRows = []
        root.insightRows = []
        root.detailRows = []
        root.selected = -1
        root.total = 0
        root.correct = 0
        root.review = 0
        root.errors = 0
        root.attention = 0
        root.filterKey = ""
        root.detailMessage = ""
        root.detailStatus = ""
    }
    function validateCurrentSelection() {
        if (!root.backendAvailable() || root.master === "" || root.upload === "") return
        var keys = []
        if (k1.currentText !== "") keys.push(k1.currentText)
        if (k2.currentText !== "(None)" && k2.currentText !== "" && k2.currentText !== k1.currentText) keys.push(k2.currentText)
        if (!keys.length) return
        root.clearResults()
        backend.validate.validate(JSON.stringify(keys))
    }
    function requestDetail(index) {
        if (!root.backendAvailable() || index < 0 || index >= root.resultRows.length) return
        root.selected = index
        backend.validate.detail(index, root.diffOnly)
    }

    FileDialog {
        id: masterDialog
        title: "Select Master Dataset"
        nameFilters: ["Data (*.csv *.xlsx *.xls *.xlsm *.txt *.tsv *.json *.xml)", "All Files (*)"]
        onAccepted: {
            root.master = root.urlToPath(selectedFile)
            backend.validate.load_master(root.master)
        }
    }
    FileDialog {
        id: uploadDialog
        title: "Select Uploaded Dataset"
        nameFilters: ["Data (*.csv *.xlsx *.xls *.xlsm *.txt *.tsv *.json *.xml)", "All Files (*)"]
        onAccepted: {
            root.upload = root.urlToPath(selectedFile)
            backend.validate.load_upload(root.upload)
        }
    }

    Connections {
        target: root.backendAvailable() ? backend.validate : null
        ignoreUnknownSignals: true
        function onMappingReady(payload) {
            try {
                var data = JSON.parse(String(payload || "{}"))
                root.suggestedKeys = Array.isArray(data.suggestedKeys) ? data.suggestedKeys : []
                if (root.suggestedKeys.length > 0) root.key1 = String(root.suggestedKeys[0])
                root.key2 = root.suggestedKeys.length > 1 ? String(root.suggestedKeys[1]) : "(None)"
            } catch (error) {
                root.suggestedKeys = []
            }
        }
        function onValidationReady(payload) {
            try {
                var data = JSON.parse(String(payload || "{}"))
                root.total = Number(data.total || 0)
                root.correct = Number(data.correct || 0)
                root.review = Number(data.review || 0)
                root.errors = Number(data.errors || 0)
                root.attention = Number(data.attention || 0)
                root.selected = -1
                root.detailRows = []
                var rawRows = Array.isArray(data.rows) ? data.rows : []
                var formattedRows = []
                for (var i = 0; i < rawRows.length; ++i) {
                    var row = rawRows[i] || {}
                    formattedRows.push({
                        rowNum: String(row.row === undefined ? i + 1 : row.row),
                        keyVal: String(row.key === undefined ? "" : row.key),
                        statusVal: String(row.status || "UNKNOWN").toUpperCase(),
                        msgVal: String(row.message || "")
                    })
                }
                root.resultRows = formattedRows
                var rawInsights = Array.isArray(data.insights) ? data.insights : []
                var formattedInsights = []
                for (var j = 0; j < rawInsights.length; ++j) {
                    var insight = rawInsights[j] || {}
                    formattedInsights.push({
                        insightKey: String(insight.key || ""),
                        title: String(insight.title || ""),
                        count: String(insight.count || "0"),
                        severity: String(insight.severity || "").toUpperCase(),
                        action: String(insight.action || "")
                    })
                }
                root.insightRows = formattedInsights
            } catch (error) {
                root.clearResults()
            }
        }
        function onDetailReady(payload) {
            try {
                var data = JSON.parse(String(payload || "{}"))
                root.detailMessage = String(data.message || "")
                root.detailStatus = String(data.status || "").toUpperCase()
                var comparisons = Array.isArray(data.comparisons) ? data.comparisons : []
                var formatted = []
                for (var i = 0; i < comparisons.length; ++i) {
                    var item = comparisons[i] || {}
                    formatted.push({
                        fieldName: String(item.field || ""),
                        masterValue: item.master === undefined || item.master === null ? "" : String(item.master),
                        uploadedValue: item.uploaded === undefined || item.uploaded === null ? "" : String(item.uploaded),
                        resultText: String(item.result || ""),
                        severityText: String(item.severity || "").toUpperCase()
                    })
                }
                root.detailRows = formatted
            } catch (error) {
                root.detailMessage = ""
                root.detailStatus = ""
                root.detailRows = []
            }
        }
    }

    ScrollView {
        id: scrollView
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        ColumnLayout {
            width: scrollView.availableWidth
            spacing: Theme.spacingLarge

            PageTitle {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacingXLarge
                Layout.rightMargin: Theme.spacingXLarge
                Layout.topMargin: Theme.spacingLarge
                title: "Compare & Validate"
                subtitle: "Match and validate uploaded store data against the Master dataset."
            }

            Card {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacingXLarge
                Layout.rightMargin: Theme.spacingXLarge
                Layout.preferredHeight: 205
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMedium
                    spacing: Theme.spacingMedium
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Master Dataset"; color: Theme.textSecondary; font.bold: true; Layout.preferredWidth: 125 }
                        TextField { Layout.fillWidth: true; readOnly: true; text: root.master; placeholderText: "No master dataset selected"; color: Theme.textPrimary }
                        AppButton { text: "Browse"; onClicked: masterDialog.open() }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Uploaded Dataset"; color: Theme.textSecondary; font.bold: true; Layout.preferredWidth: 125 }
                        TextField { Layout.fillWidth: true; readOnly: true; text: root.upload; placeholderText: "No uploaded dataset selected"; color: Theme.textPrimary }
                        AppButton { text: "Browse"; onClicked: uploadDialog.open() }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Match by"; color: Theme.textSecondary; font.bold: true; Layout.preferredWidth: 125 }
                        ComboBox {
                            id: k1
                            Layout.preferredWidth: 190
                            model: ["SID", "Nielsen Store Code"]
                            currentIndex: Math.max(0, model.indexOf(root.key1))
                            onActivated: root.key1 = currentText
                        }
                        Text { text: "+"; color: Theme.textSecondary; font.bold: true }
                        ComboBox {
                            id: k2
                            Layout.preferredWidth: 200
                            model: ["(None)", "Nielsen Store Code", "SID"]
                            currentIndex: Math.max(0, model.indexOf(root.key2))
                            onActivated: root.key2 = currentText
                        }
                        Text { Layout.fillWidth: true; text: root.suggestedKeys.length ? "Smart suggestion: " + root.suggestedKeys.join(" + ") : ""; color: Theme.info; elide: Text.ElideRight }
                        AppButton { text: "Detect Columns"; enabled: root.master !== "" && root.upload !== ""; onClicked: backend.validate.detect() }
                        PrimaryButton { text: "Validate"; enabled: root.master !== "" && root.upload !== ""; onClicked: root.validateCurrentSelection() }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacingXLarge
                Layout.rightMargin: Theme.spacingXLarge
                spacing: Theme.spacingMedium
                Repeater {
                    model: [
                        { label: "TOTAL", value: root.total, tone: Theme.primary },
                        { label: "CORRECT", value: root.correct, tone: Theme.success },
                        { label: "REVIEW", value: root.review, tone: Theme.warning },
                        { label: "ERROR", value: root.errors, tone: Theme.error }
                    ]
                    delegate: Card {
                        id: metricDelegate
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 82
                        ColumnLayout {
                            anchors.centerIn: parent
                            Text { text: metricDelegate.modelData.value; color: metricDelegate.modelData.tone; font.pixelSize: 22; font.bold: true; Layout.alignment: Qt.AlignHCenter }
                            Text { text: metricDelegate.modelData.label; color: Theme.textSecondary; font.pixelSize: 10; font.bold: true; Layout.alignment: Qt.AlignHCenter }
                        }
                    }
                }
            }

            Card {
                visible: root.insightRows.length > 0
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacingXLarge
                Layout.rightMargin: Theme.spacingXLarge
                Layout.preferredHeight: Math.min(260, 100 + root.insightRows.length * 48)
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMedium
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Validation Intelligence"; color: Theme.textPrimary; font.bold: true }
                        Item { Layout.fillWidth: true }
                        Text { text: root.attention + " finding(s) need attention"; color: root.attention ? Theme.warning : Theme.success }
                    }
                    ListView {
                        id: insightsList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: root.insightRows
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        delegate: Rectangle {
                            id: insightDelegate
                            required property var modelData
                            width: insightsList.width
                            height: 42
                            color: root.statusBackground(insightDelegate.modelData.severity)
                            border.color: root.statusColor(insightDelegate.modelData.severity)
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                Text { text: String(insightDelegate.modelData.title || ""); color: root.statusColor(insightDelegate.modelData.severity); font.bold: true; Layout.preferredWidth: 210 }
                                Text { text: String(insightDelegate.modelData.count || "0"); color: Theme.textPrimary; font.bold: true; Layout.preferredWidth: 50 }
                                Text { text: String(insightDelegate.modelData.action || ""); color: Theme.textSecondary; Layout.fillWidth: true; elide: Text.ElideRight }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.filterKey = root.filterKey === String(insightDelegate.modelData.insightKey || "") ? "" : String(insightDelegate.modelData.insightKey || "")
                            }
                        }
                    }
                }
            }

            Card {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacingXLarge
                Layout.rightMargin: Theme.spacingXLarge
                Layout.preferredHeight: 540
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMedium
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Validation Results"; color: Theme.textPrimary; font.pixelSize: 15; font.bold: true }
                        Item { Layout.fillWidth: true }
                        Text { text: root.resultRows.length + " record(s)"; color: Theme.textSecondary }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        color: Theme.surfaceHover
                        border.color: Theme.border
                        RowLayout {
                            anchors.fill: parent
                            Text { text: "Row"; color: Theme.textSecondary; font.bold: true; Layout.preferredWidth: 70 }
                            Text { text: "Key"; color: Theme.textSecondary; font.bold: true; Layout.preferredWidth: 260 }
                            Text { text: "Status"; color: Theme.textSecondary; font.bold: true; Layout.preferredWidth: 120 }
                            Text { text: "Message"; color: Theme.textSecondary; font.bold: true; Layout.fillWidth: true }
                        }
                    }
                    ListView {
                        id: resultsList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: root.resultRows
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        delegate: Rectangle {
                            id: resultDelegate
                            required property var modelData
                            required property int index
                            width: resultsList.width
                            height: 46
                            visible: root.filterKey === "" || String(resultDelegate.modelData.statusVal) === root.filterKey
                            color: root.selected === resultDelegate.index ? Theme.surfaceHover : root.statusBackground(resultDelegate.modelData.statusVal)
                            border.color: root.selected === resultDelegate.index ? Theme.primary : Theme.border
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                Text { text: String(resultDelegate.modelData.rowNum || ""); color: Theme.textSecondary; Layout.preferredWidth: 70 }
                                Text { text: String(resultDelegate.modelData.keyVal || ""); color: Theme.textPrimary; Layout.preferredWidth: 260; elide: Text.ElideRight }
                                Text { text: String(resultDelegate.modelData.statusVal || ""); color: root.statusColor(resultDelegate.modelData.statusVal); font.bold: true; Layout.preferredWidth: 120 }
                                Text { text: String(resultDelegate.modelData.msgVal || ""); color: Theme.textSecondary; Layout.fillWidth: true; elide: Text.ElideRight }
                            }
                            MouseArea { anchors.fill: parent; onClicked: root.requestDetail(resultDelegate.index) }
                        }
                    }
                }
            }

            Card {
                visible: root.selected >= 0 && root.detailRows.length > 0
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacingXLarge
                Layout.rightMargin: Theme.spacingXLarge
                Layout.bottomMargin: Theme.spacingXLarge
                Layout.preferredHeight: 430
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMedium
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Record Detail"; color: Theme.textPrimary; font.pixelSize: 15; font.bold: true }
                        Item { Layout.fillWidth: true }
                        Text { text: root.detailStatus; color: root.statusColor(root.detailStatus); font.bold: true }
                    }
                    Text { text: root.detailMessage; color: Theme.textSecondary; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                    ListView {
                        id: detailsList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: root.detailRows
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        delegate: Rectangle {
                            id: detailDelegate
                            required property var modelData
                            width: detailsList.width
                            height: 54
                            color: Theme.background
                            border.color: Theme.border
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                Text { text: String(detailDelegate.modelData.fieldName || ""); color: Theme.textSecondary; Layout.preferredWidth: 170; elide: Text.ElideRight }
                                Text { text: String(detailDelegate.modelData.masterValue || "") === "" ? "—" : String(detailDelegate.modelData.masterValue); color: Theme.textPrimary; Layout.fillWidth: true; elide: Text.ElideRight }
                                Text { text: String(detailDelegate.modelData.uploadedValue || "") === "" ? "—" : String(detailDelegate.modelData.uploadedValue); color: Theme.textPrimary; Layout.fillWidth: true; elide: Text.ElideRight }
                                Text { text: String(detailDelegate.modelData.resultText || ""); color: root.statusColor(detailDelegate.modelData.severityText); font.bold: true; Layout.preferredWidth: 120; elide: Text.ElideRight }
                            }
                        }
                    }
                }
            }
        }
    }
}
