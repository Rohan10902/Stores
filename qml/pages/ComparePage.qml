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

    ListModel { id: rowsModel }
    ListModel { id: insightsModel }
    ListModel { id: detailsModel }

    function backendAvailable() { return typeof backend !== "undefined" && backend !== null && backend.validate !== undefined && backend.validate !== null }
    function urlToPath(value) {
        var text = String(value || "")
        if (text.indexOf("file:///") === 0) text = text.substring(8)
        else if (text.indexOf("file://") === 0) text = text.substring(7)
        if (Qt.platform.os === "windows") text = text.replace(/^\/+/, "")
        try { return decodeURIComponent(text) } catch (e) { return text }
    }
    function statusColor(status) { var value = String(status || "").toUpperCase(); if (value === "ERROR") return Theme.error; if (value === "REVIEW" || value === "WARNING") return Theme.warning; if (value === "CORRECT" || value === "OK") return Theme.success; return Theme.textSecondary }
    function statusBackground(status) { var value = String(status || "").toUpperCase(); if (value === "ERROR") return "#421820"; if (value === "REVIEW" || value === "WARNING") return "#433614"; if (value === "CORRECT" || value === "OK") return "#113426"; return Theme.surface }
    function clearResults() { rowsModel.clear(); insightsModel.clear(); detailsModel.clear(); root.selected = -1; root.total = 0; root.correct = 0; root.review = 0; root.errors = 0; root.attention = 0; root.filterKey = ""; root.detailMessage = ""; root.detailStatus = "" }
    function validateCurrentSelection() {
        if (!root.backendAvailable() || root.master === "" || root.upload === "") return
        var keys = []
        if (k1.currentText !== "") keys.push(k1.currentText)
        if (k2.currentText !== "(None)" && k2.currentText !== "" && k2.currentText !== k1.currentText) keys.push(k2.currentText)
        if (!keys.length) return
        root.clearResults()
        backend.validate.validate(JSON.stringify(keys))
    }
    function requestDetail(index) { if (root.backendAvailable() && index >= 0) { root.selected = index; backend.validate.detail(index, root.diffOnly) } }

    FileDialog {
        id: masterDialog
        title: "Select Master Dataset"
        nameFilters: ["Data (*.csv *.xlsx *.xls *.xlsm *.txt *.tsv *.json *.xml)", "All Files (*)"]
        onAccepted: { root.master = root.urlToPath(selectedFile); if (root.backendAvailable()) backend.validate.load_master(root.master) }
    }
    FileDialog {
        id: uploadDialog
        title: "Select Uploaded Dataset"
        nameFilters: ["Data (*.csv *.xlsx *.xls *.xlsm *.txt *.tsv *.json *.xml)", "All Files (*)"]
        onAccepted: { root.upload = root.urlToPath(selectedFile); if (root.backendAvailable()) backend.validate.load_upload(root.upload) }
    }

    Connections {
        target: root.backendAvailable() ? backend.validate : null
        ignoreUnknownSignals: true
        function onMappingReady(payload) {
            try {
                var data = JSON.parse(String(payload || "{}")); root.suggestedKeys = Array.isArray(data.suggestedKeys) ? data.suggestedKeys : []
                if (root.suggestedKeys.length > 0) root.key1 = String(root.suggestedKeys[0])
                root.key2 = root.suggestedKeys.length > 1 ? String(root.suggestedKeys[1]) : "(None)"
            } catch (error) { root.suggestedKeys = [] }
        }
        function onValidationReady(payload) {
            try {
                var data = JSON.parse(String(payload || "{}"))
                root.total = Number(data.total || 0); root.correct = Number(data.correct || 0); root.review = Number(data.review || 0); root.errors = Number(data.errors || 0); root.attention = Number(data.attention || 0)
                rowsModel.clear(); insightsModel.clear(); detailsModel.clear(); root.selected = -1
                var rawRows = Array.isArray(data.rows) ? data.rows : []
                for (var i = 0; i < rawRows.length; ++i) {
                    var row = rawRows[i] || {}
                    rowsModel.append({rowNum: String(row.row === undefined ? i + 1 : row.row), keyVal: String(row.key === undefined ? "" : row.key), statusVal: String(row.status || "UNKNOWN").toUpperCase(), msgVal: String(row.message || "")})
                }
                var rawInsights = Array.isArray(data.insights) ? data.insights : []
                for (var j = 0; j < rawInsights.length; ++j) {
                    var insight = rawInsights[j] || {}
                    insightsModel.append({insightKey: String(insight.key || ""), title: String(insight.title || ""), count: String(insight.count || "0"), severity: String(insight.severity || "").toUpperCase(), action: String(insight.action || "")})
                }
            } catch (error) { root.clearResults() }
        }
        function onDetailReady(payload) {
            try {
                var data = JSON.parse(String(payload || "{}")); root.detailMessage = String(data.message || ""); root.detailStatus = String(data.status || "").toUpperCase(); detailsModel.clear()
                var comparisons = Array.isArray(data.comparisons) ? data.comparisons : []
                for (var i = 0; i < comparisons.length; ++i) {
                    var item = comparisons[i] || {}
                    detailsModel.append({fieldName: String(item.field || ""), masterValue: item.master === undefined || item.master === null ? "" : String(item.master), uploadedValue: item.uploaded === undefined || item.uploaded === null ? "" : String(item.uploaded), resultText: String(item.result || ""), severityText: String(item.severity || "").toUpperCase()})
                }
            } catch (error) { root.detailMessage = ""; root.detailStatus = ""; detailsModel.clear() }
        }
    }

    ScrollView {
        id: scrollView
        anchors.fill: parent; clip: true; contentWidth: availableWidth; ScrollBar.vertical.policy: ScrollBar.AsNeeded
        ColumnLayout {
            width: scrollView.availableWidth; spacing: Theme.spacingLarge
            PageTitle { Layout.fillWidth: true; Layout.leftMargin: Theme.spacingXLarge; Layout.rightMargin: Theme.spacingXLarge; Layout.topMargin: Theme.spacingLarge; title: "Compare & Validate"; subtitle: "Match and validate uploaded store data against the Master dataset." }

            Card {
                Layout.fillWidth: true; Layout.leftMargin: Theme.spacingXLarge; Layout.rightMargin: Theme.spacingXLarge; Layout.preferredHeight: 205
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: Theme.spacingMedium; spacing: Theme.spacingMedium
                    RowLayout { Layout.fillWidth: true; Text { text: "Master Dataset"; color: Theme.textSecondary; font.bold: true; Layout.preferredWidth: 125 }; TextField { Layout.fillWidth: true; readOnly: true; text: root.master; placeholderText: "No master dataset selected"; color: Theme.textPrimary }; AppButton { text: "Browse"; onClicked: masterDialog.open() } }
                    RowLayout { Layout.fillWidth: true; Text { text: "Uploaded Dataset"; color: Theme.textSecondary; font.bold: true; Layout.preferredWidth: 125 }; TextField { Layout.fillWidth: true; readOnly: true; text: root.upload; placeholderText: "No uploaded dataset selected"; color: Theme.textPrimary }; AppButton { text: "Browse"; onClicked: uploadDialog.open() } }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Match by"; color: Theme.textSecondary; font.bold: true; Layout.preferredWidth: 125 }
                        ComboBox { id: k1; Layout.preferredWidth: 190; model: ["SID","Nielsen Store Code"]; currentIndex: Math.max(0, model.indexOf(root.key1)); onActivated: root.key1 = currentText }
                        Text { text: "+"; color: Theme.textSecondary; font.bold: true }
                        ComboBox { id: k2; Layout.preferredWidth: 200; model: ["(None)","Nielsen Store Code","SID"]; currentIndex: Math.max(0, model.indexOf(root.key2)); onActivated: root.key2 = currentText }
                        Text { Layout.fillWidth: true; text: root.suggestedKeys.length ? "Smart suggestion: " + root.suggestedKeys.join(" + ") : ""; color: Theme.info; elide: Text.ElideRight }
                        AppButton { text: "Detect Columns"; enabled: root.master !== "" && root.upload !== ""; onClicked: backend.validate.detect() }
                        PrimaryButton { text: "Validate"; enabled: root.master !== "" && root.upload !== ""; onClicked: root.validateCurrentSelection() }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true; Layout.leftMargin: Theme.spacingXLarge; Layout.rightMargin: Theme.spacingXLarge; spacing: Theme.spacingMedium
                Repeater {
                    model: [{label:"TOTAL",value:root.total,tone:Theme.primary},{label:"CORRECT",value:root.correct,tone:Theme.success},{label:"REVIEW",value:root.review,tone:Theme.warning},{label:"ERROR",value:root.errors,tone:Theme.error}]
                    delegate: Card {
                        id: metricDelegate
                        required property var modelData
                        Layout.fillWidth: true; Layout.preferredHeight: 82
                        ColumnLayout { anchors.centerIn: parent; Text { text: metricDelegate.modelData.value; color: metricDelegate.modelData.tone; font.pixelSize: 22; font.bold: true; Layout.alignment: Qt.AlignHCenter }; Text { text: metricDelegate.modelData.label; color: Theme.textSecondary; font.pixelSize: 10; font.bold: true; Layout.alignment: Qt.AlignHCenter } }
                    }
                }
            }

            Card {
                visible: insightsModel.count > 0; Layout.fillWidth: true; Layout.leftMargin: Theme.spacingXLarge; Layout.rightMargin: Theme.spacingXLarge; Layout.preferredHeight: Math.min(260, 100 + insightsModel.count * 48)
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: Theme.spacingMedium; spacing: Theme.spacingSmall
                    RowLayout { Layout.fillWidth: true; Text { text: "Validation Intelligence"; color: Theme.textPrimary; font.bold: true }; Item { Layout.fillWidth: true }; Text { text: root.attention + " finding(s) need attention"; color: root.attention ? Theme.warning : Theme.success } }
                    ListView {
                        id: insightsList
                        Layout.fillWidth: true; Layout.fillHeight: true; clip: true; model: insightsModel; spacing: 4; ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        delegate: Rectangle {
                            id: insightDelegate
                            required property string insightKey
                            required property string title
                            required property string count
                            required property string severity
                            required property string action
                            width: insightsList.width; height: 42; radius: Theme.radiusMedium; color: root.filterKey === insightDelegate.insightKey ? Theme.surfaceHover : root.statusBackground(insightDelegate.severity); border.color: root.statusColor(insightDelegate.severity)
                            RowLayout { anchors.fill: parent; anchors.margins: 8; Text { text: insightDelegate.title; color: root.statusColor(insightDelegate.severity); font.bold: true; Layout.preferredWidth: 210 }; Text { text: insightDelegate.count; color: Theme.textPrimary; font.bold: true; Layout.preferredWidth: 50 }; Text { text: insightDelegate.action; color: Theme.textSecondary; Layout.fillWidth: true; elide: Text.ElideRight }; MouseArea { anchors.fill: parent; onClicked: root.filterKey = root.filterKey === insightDelegate.insightKey ? "" : insightDelegate.insightKey } }
                        }
                    }
                }
            }

            Card {
                Layout.fillWidth: true; Layout.leftMargin: Theme.spacingXLarge; Layout.rightMargin: Theme.spacingXLarge; Layout.preferredHeight: 540
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: Theme.spacingMedium; spacing: Theme.spacingSmall
                    RowLayout { Layout.fillWidth: true; Text { text: "Validation Results"; color: Theme.textPrimary; font.pixelSize: 15; font.bold: true }; Item { Layout.fillWidth: true }; Text { text: rowsModel.count + " record(s)"; color: Theme.textSecondary } }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 34; color: Theme.surfaceHover; border.color: Theme.border; RowLayout { anchors.fill: parent; Text { text: "Row"; color: Theme.textSecondary; font.bold: true; Layout.preferredWidth: 70 }; Text { text: "Key"; color: Theme.textSecondary; font.bold: true; Layout.preferredWidth: 260 }; Text { text: "Status"; color: Theme.textSecondary; font.bold: true; Layout.preferredWidth: 120 }; Text { text: "Message"; color: Theme.textSecondary; font.bold: true; Layout.fillWidth: true } } }
                    ListView {
                        id: resultsList
                        Layout.fillWidth: true; Layout.fillHeight: true; clip: true; model: rowsModel; ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        delegate: Rectangle {
                            id: resultDelegate
                            required property string rowNum
                            required property string keyVal
                            required property string statusVal
                            required property string msgVal
                            required property int index
                            width: resultsList.width; height: 46
                            visible: root.filterKey === "" || resultDelegate.statusVal === root.filterKey
                            color: root.selected === resultDelegate.index ? Theme.surfaceHover : root.statusBackground(resultDelegate.statusVal)
                            border.color: root.selected === resultDelegate.index ? Theme.primary : Theme.border
                            MouseArea { anchors.fill: parent; onClicked: root.requestDetail(resultDelegate.index) }
                            RowLayout { anchors.fill: parent; anchors.margins: 8; Text { text: resultDelegate.rowNum; color: Theme.textSecondary; Layout.preferredWidth: 70 }; Text { text: resultDelegate.keyVal; color: Theme.textPrimary; Layout.preferredWidth: 260; elide: Text.ElideRight }; Text { text: resultDelegate.statusVal; color: root.statusColor(resultDelegate.statusVal); font.bold: true; Layout.preferredWidth: 120 }; Text { text: resultDelegate.msgVal; color: Theme.textSecondary; Layout.fillWidth: true; elide: Text.ElideRight } }
                        }
                    }
                }
            }

            Card {
                visible: root.selected >= 0 && detailsModel.count > 0
                Layout.fillWidth: true; Layout.leftMargin: Theme.spacingXLarge; Layout.rightMargin: Theme.spacingXLarge; Layout.bottomMargin: Theme.spacingXLarge; Layout.preferredHeight: 430
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: Theme.spacingMedium; spacing: Theme.spacingSmall
                    RowLayout { Layout.fillWidth: true; Text { text: "Record Detail"; color: Theme.textPrimary; font.pixelSize: 15; font.bold: true }; Item { Layout.fillWidth: true }; Text { text: root.detailStatus; color: root.statusColor(root.detailStatus); font.bold: true } }
                    Text { text: root.detailMessage; color: Theme.textSecondary; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                    ListView {
                        id: detailsList
                        Layout.fillWidth: true; Layout.fillHeight: true; clip: true; model: detailsModel; ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        delegate: Rectangle {
                            id: detailDelegate
                            required property string fieldName
                            required property string masterValue
                            required property string uploadedValue
                            required property string resultText
                            required property string severityText
                            width: detailsList.width; height: 54; color: Theme.background; border.color: Theme.border
                            RowLayout { anchors.fill: parent; anchors.margins: 8; Text { text: detailDelegate.fieldName; color: Theme.textSecondary; Layout.preferredWidth: 170; elide: Text.ElideRight }; Text { text: detailDelegate.masterValue === "" ? "—" : detailDelegate.masterValue; color: Theme.textPrimary; Layout.fillWidth: true; elide: Text.ElideRight }; Text { text: detailDelegate.uploadedValue === "" ? "—" : detailDelegate.uploadedValue; color: Theme.textPrimary; Layout.fillWidth: true; elide: Text.ElideRight }; Text { text: detailDelegate.resultText; color: root.statusColor(detailDelegate.severityText); font.bold: true; Layout.preferredWidth: 120; elide: Text.ElideRight } }
                        }
                    }
                }
            }
        }
    }
}
