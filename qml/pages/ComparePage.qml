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

    property string detailMessage: ""
    property string detailStatus: ""
    property var suggestedKeys: []
    property string key1: "SID"
    property string key2: "Nielsen Store Code"

    ListModel { id: rows }
    ListModel { id: details }
    ListModel { id: insights }

    function urlToPath(urlStr) {
        var s = urlStr.toString();
        if (s.indexOf("file:///") === 0) {
            s = s.substring(8);
            if (Qt.platform.os === "windows" && s.charAt(0) === '/' && s.charAt(2) === ':') { s = s.substring(1); }
        }
        return s;
    }

    FileDialog {
        id: md
        title: "Select Master Dataset"
        nameFilters: ["Data (*.csv *.xlsx *.xls *.xlsm *.txt *.tsv *.json *.xml)"]
        onAccepted: {
            master = urlToPath(selectedFile)
            if (typeof backend !== "undefined" && backend.validate) backend.validate.load_master(master)
        }
    }

    FileDialog {
        id: ud
        title: "Select Uploaded / Country File"
        nameFilters: ["Data (*.csv *.xlsx *.xls *.xlsm *.txt *.tsv *.json *.xml)"]
        onAccepted: {
            upload = urlToPath(selectedFile)
            if (typeof backend !== "undefined" && backend.validate) backend.validate.load_upload(upload)
        }
    }

    Connections {
        target: typeof backend !== "undefined" ? backend.validate : null
        ignoreUnknownSignals: true

        function onMappingReady(p) {
            try {
                var d = JSON.parse(p)
                suggestedKeys = d.suggestedKeys || ["SID"]
                key1 = suggestedKeys[0] || "SID"
                key2 = suggestedKeys.length > 1 ? suggestedKeys[1] : "(None)"
            } catch (e) { }
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
                selected = -1

                var rawRows = d.rows || []
                for (var i = 0; i < rawRows.length; i++) {
                    var r = rawRows[i]
                    rows.append({
                        rowNum: String(r.row || ""),
                        keyVal: String(r.key || ""),
                        statusVal: String(r.status || ""),
                        msgVal: String(r.message || "")
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
            } catch (e) { }
        }

        function onDetailReady(p) {
            try {
                var d = JSON.parse(p)
                detailMessage = d.message || ""
                detailStatus = d.status || ""
                details.clear()

                var comps = d.comparisons || []
                for (var i = 0; i < comps.length; i++) {
                    var c = comps[i]
                    details.append({
                        fieldName: String(c.field || ""),
                        masterValue: c.master === undefined || c.master === null ? "" : String(c.master),
                        uploadedValue: c.uploaded === undefined || c.uploaded === null ? "" : String(c.uploaded),
                        resultText: String(c.result || ""),
                        severityText: String(c.severity || "")
                    })
                }
            } catch (e) { }
        }
    }

    ScrollView {
        id: scrollView
        anchors.fill: parent; clip: true

        ColumnLayout {
            width: scrollView.availableWidth
            anchors.margins: Theme.spacingXLarge
            spacing: Theme.spacingLarge

            PageTitle { title: "Compare & Validate"; subtitle: "Row-order-independent master vs uploaded store comparison."; Layout.fillWidth: true }

            Card {
                Layout.fillWidth: true; Layout.preferredHeight: 140
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: Theme.spacingMedium; spacing: Theme.spacingSmall
                    RowLayout {
                        Layout.fillWidth: true; spacing: Theme.spacingMedium
                        TextField {
                            Layout.fillWidth: true; readOnly: true; text: root.master
                            placeholderText: "Master file path..."; color: Theme.textPrimary
                            background: Rectangle { color: Theme.background; border.color: Theme.border; radius: Theme.radiusMedium }
                        }
                        AppButton { text: "Browse Master"; onClicked: md.open() }
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: Theme.spacingMedium
                        TextField {
                            Layout.fillWidth: true; readOnly: true; text: root.upload
                            placeholderText: "Uploaded / country file path..."; color: Theme.textPrimary
                            background: Rectangle { color: Theme.background; border.color: Theme.border; radius: Theme.radiusMedium }
                        }
                        AppButton { text: "Browse Upload"; onClicked: ud.open() }
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: Theme.spacingMedium
                        Text { text: "Match by"; color: Theme.textSecondary }
                        ComboBox {
                            id: k1
                            Layout.preferredWidth: 180; model: ["SID", "Nielsen Store Code"]
                            currentIndex: Math.max(0, model.indexOf(key1)); onActivated: key1 = currentText
                            background: Rectangle { color: Theme.background; border.color: Theme.border; radius: Theme.radiusMedium }
                            contentItem: Text { text: parent.currentIndex >= 0 ? parent.currentText : ""; color: Theme.textPrimary; verticalAlignment: Text.AlignVCenter; leftPadding: 8 }
                        }
                        Text { text: "+"; color: Theme.textSecondary }
                        ComboBox {
                            id: k2
                            Layout.preferredWidth: 200; model: ["(None)", "Nielsen Store Code", "SID"]
                            currentIndex: Math.max(0, model.indexOf(key2)); onActivated: key2 = currentText
                            background: Rectangle { color: Theme.background; border.color: Theme.border; radius: Theme.radiusMedium }
                            contentItem: Text { text: parent.currentIndex >= 0 ? parent.currentText : ""; color: Theme.textPrimary; verticalAlignment: Text.AlignVCenter; leftPadding: 8 }
                        }
                        Text { text: suggestedKeys.length ? "Smart suggestion: " + suggestedKeys.join(" + ") : ""; color: Theme.info; Layout.fillWidth: true; elide: Text.ElideRight }
                        AppButton {
                            text: "Detect Columns"
                            enabled: root.master !== "" && root.upload !== ""
                            onClicked: { if (backend && backend.validate) backend.validate.detect() }
                        }
                        PrimaryButton {
                            text: "Validate"
                            enabled: root.master !== "" && root.upload !== ""
                            onClicked: {
                                var a = [k1.currentText]
                                if (k2.currentText !== "(None)" && k2.currentText !== k1.currentText) a.push(k2.currentText)
                                if (backend && backend.validate) backend.validate.validate(JSON.stringify(a))
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true; spacing: Theme.spacingMedium
                Repeater {
                    model: [ ["TOTAL", total, Theme.primary], ["CORRECT", ok, Theme.success], ["REVIEW", rev, Theme.warning], ["ERROR", err, Theme.error] ]
                    delegate: Card {
                        required property var modelData
                        Layout.fillWidth: true; Layout.preferredHeight: 70
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: Theme.spacingSmall; spacing: 2
                            Text { text: modelData[1]; color: modelData[2]; font.pixelSize: 20; font.bold: true; Layout.alignment: Qt.AlignHCenter }
                            Text { text: modelData[0]; color: Theme.textSecondary; font.pixelSize: 10; font.bold: true; Layout.alignment: Qt.AlignHCenter }
                        }
                    }
                }
            }

            Card {
                Layout.fillWidth: true; Layout.preferredHeight: insights.count > 0 ? 120 : 0
                visible: insights.count > 0
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: Theme.spacingMedium; spacing: Theme.spacingSmall
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Validation Intelligence   " + attention + " finding(s) need attention"; color: Theme.textPrimary; font.bold: true }
                        Item { Layout.fillWidth: true }
                        AppButton { text: filterKey ? "Show All" : "All Records"; onClicked: filterKey = "" }
                    }
                    ListView {
                        Layout.fillWidth: true; Layout.preferredHeight: 65
                        orientation: ListView.Horizontal; spacing: Theme.spacingSmall; model: insights; clip: true
                        delegate: Rectangle {
                            required property string key
                            required property string title
                            required property string count
                            required property string severity
                            required property string action
                            width: 250; height: 65; radius: Theme.radiusMedium
                            color: filterKey === key ? Theme.surfaceHover : (severity === "ERROR" ? "#421820" : "#433614")
                            border.color: filterKey === key ? Theme.primary : Theme.border
                            MouseArea { anchors.fill: parent; onClicked: filterKey = key }
                            ColumnLayout {
                                anchors.fill: parent; anchors.margins: Theme.spacingSmall; spacing: 2
                                RowLayout {
                                    Layout.fillWidth: true; spacing: Theme.spacingSmall
                                    Text { text: count; color: severity === "ERROR" ? Theme.error : Theme.warning; font.bold: true; font.pixelSize: 16 }
                                    Text { text: title; color: Theme.textPrimary; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                                }
                                Text { text: action; color: Theme.textSecondary; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
                            }
                        }
                    }
                }
            }

            SplitView {
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 500; orientation: Qt.Vertical

                Card {
                    SplitView.minimumHeight: 180; SplitView.preferredHeight: 220
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: Theme.spacingMedium; spacing: Theme.spacingSmall
                        Text { text: "Validation Results"; color: Theme.textPrimary; font.bold: true }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 30; color: Theme.surfaceHover; border.color: Theme.border
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: Theme.spacingSmall; anchors.rightMargin: Theme.spacingSmall; spacing: Theme.spacingSmall
                                Text { text: "Row"; color: Theme.textSecondary; font.bold: true; Layout.preferredWidth: 50 }
                                Text { text: "Key"; color: Theme.textSecondary; font.bold: true; Layout.preferredWidth: 150 }
                                Text { text: "Status"; color: Theme.textSecondary; font.bold: true; Layout.preferredWidth: 90 }
                                Text { text: "Message"; color: Theme.textSecondary; font.bold: true; Layout.fillWidth: true }
                            }
                        }
                        ListView {
                            id: resultsListView
                            Layout.fillWidth: true; Layout.fillHeight: true; model: rows; clip: true
                            delegate: Rectangle {
                                required property int index
                                required property string rowNum
                                required property string keyVal
                                required property string statusVal
                                required property string msgVal
                                width: resultsListView.width; height: 36
                                color: selected === index ? Theme.surfaceHover : (index % 2 === 0 ? Theme.background : Theme.surface)
                                border.color: Theme.border; border.width: 1
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        selected = index
                                        if (backend && backend.validate) backend.validate.detail(index, diff)
                                    }
                                }
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: Theme.spacingSmall; anchors.rightMargin: Theme.spacingSmall; spacing: Theme.spacingSmall
                                    Text { text: rowNum; color: Theme.textSecondary; Layout.preferredWidth: 50 }
                                    Text { text: keyVal; color: Theme.textPrimary; Layout.preferredWidth: 150; elide: Text.ElideRight }
                                    Text { text: statusVal; color: statusVal === "ERROR" ? Theme.error : (statusVal === "REVIEW" ? Theme.warning : Theme.success); font.bold: true; Layout.preferredWidth: 90 }
                                    Text { text: msgVal; color: Theme.textPrimary; Layout.fillWidth: true; elide: Text.ElideRight }
                                }
                            }
                        }
                    }
                }

                Card {
                    SplitView.minimumHeight: 220; SplitView.fillHeight: true
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: Theme.spacingMedium; spacing: Theme.spacingSmall
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Comparison Inspector"; color: Theme.textPrimary; font.bold: true }
                            Item { Layout.fillWidth: true }
                            CheckBox {
                                text: "Differences only"
                                checked: diff
                                onToggled: {
                                    diff = checked
                                    if (selected >= 0 && backend && backend.validate) backend.validate.detail(selected, diff)
                                }
                                contentItem: Text { text: parent.text; color: Theme.textPrimary; leftPadding: parent.indicator.width + 4; verticalAlignment: Text.AlignVCenter }
                            }
                        }
                        Rectangle {
                            visible: selected >= 0
                            Layout.fillWidth: true; implicitHeight: 45; radius: Theme.radiusMedium
                            color: detailStatus === "ERROR" ? "#421820" : (detailStatus === "REVIEW" ? "#433614" : "#113426")
                            border.color: Theme.border
                            Text {
                                anchors.fill: parent; anchors.margins: Theme.spacingSmall
                                text: detailMessage; color: Theme.textPrimary; wrapMode: Text.WordWrap; verticalAlignment: Text.AlignVCenter
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingSmall
                            Text { text: "Field"; color: Theme.textSecondary; font.bold: true; Layout.preferredWidth: 160 }
                            Text { text: "Master Value"; color: Theme.textSecondary; font.bold: true; Layout.fillWidth: true }
                            Text { text: "Uploaded / Updated Value"; color: Theme.textSecondary; font.bold: true; Layout.fillWidth: true }
                            Text { text: "Result"; color: Theme.textSecondary; font.bold: true; Layout.preferredWidth: 120 }
                        }
                        ListView {
                            id: detailsListView
                            Layout.fillWidth: true; Layout.fillHeight: true; model: details; clip: true
                            delegate: Rectangle {
                                required property string fieldName
                                required property string masterValue
                                required property string uploadedValue
                                required property string resultText
                                required property string severityText
                                width: detailsListView.width; height: 32
                                color: severityText === "ERROR" ? "#421820" : (severityText === "REVIEW" ? "#433614" : "#113426")
                                border.color: Theme.border; border.width: 1
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: Theme.spacingSmall; anchors.rightMargin: Theme.spacingSmall; spacing: Theme.spacingSmall
                                    Text { text: fieldName; color: Theme.textPrimary; font.bold: true; Layout.preferredWidth: 160; elide: Text.ElideRight }
                                    Text { text: masterValue === "" ? "—" : masterValue; color: masterValue === "" ? Theme.textMuted : Theme.textPrimary; Layout.fillWidth: true; elide: Text.ElideRight }
                                    Text { text: uploadedValue === "" ? "—" : uploadedValue; color: uploadedValue === "" ? Theme.textMuted : Theme.textPrimary; Layout.fillWidth: true; elide: Text.ElideRight }
                                    Text { text: resultText; color: severityText === "ERROR" ? Theme.error : (severityText === "REVIEW" ? Theme.warning : Theme.success); font.bold: true; Layout.preferredWidth: 120; elide: Text.ElideRight }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
