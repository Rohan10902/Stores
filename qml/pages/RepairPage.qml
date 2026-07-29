import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"

Item {
    property string src: ""
    property var audit: ({})
    property int selected: -1
    property bool mappingMode: false
    property bool newRecordMode: false
    property bool canUndo: false

    ListModel { id: issues }
    ListModel { id: preview }
    ListModel { id: createdRows }

    function issueAt(i) {
        if (i < 0 || i >= issues.count)
            return null
        return issues.get(i)
    }

    function showIssue(i) {
        var q = issueAt(i)
        if (!q) {
            selected = -1
            mappingMode = false
            newRecordMode = false
            preview.clear()
            return
        }

        selected = i
        mappingMode = false
        newRecordMode = false
        preview.clear()

        var columns = []
        try {
            columns = JSON.parse(String(q.columnsJson || "[]"))
        } catch (e) {
            columns = []
        }

        for (var j = 0; j < columns.length; ++j) {
            var x = columns[j] || {}
            preview.append({
                sourceIndex: j,
                field: String(x.field || ""),
                before: String(x.detected || ""),
                after: String(x.proposed || ""),
                state: String(x.state || ""),
                reason: String(x.reason || ""),
                suggested: String(x.suggestedField || ""),
                confidence: String(x.confidence || 0),
                decision: String(x.decision || ""),
                candidatesJson: JSON.stringify(x.candidates || []),
                target: String(x.mappedTo || x.suggestedField || "")
            })
        }
    }

    function createNewRecord() {
        var m = { "__values__": { "SID": newSid.text } }
        for (var i = 0; i < preview.count; ++i) {
            var r = preview.get(i)
            if (String(r.field).indexOf("PRESERVED EXTRA") === 0 && String(r.target).length > 0)
                m[String(r.sourceIndex)] = r.target
        }
        backend.createRepairRecord(selected, JSON.stringify(m))
        newRecordMode = false
        mappingMode = false
        newSid.text = ""
    }

    FileDialog {
        id: openDlg
        nameFilters: ["CSV / Text (*.csv *.txt *.tsv)"]
        onAccepted: {
            src = selectedFile.toString()
            selected = -1
            preview.clear()
            backend.inspectRepair(src)
        }
    }

    FileDialog {
        id: saveDlg
        fileMode: FileDialog.SaveFile
        nameFilters: ["CSV (*.csv)"]
        onAccepted: backend.repair(src, selectedFile.toString())
    }

    Connections {
        target: backend

        function onRepairReady(p) {
            var d = {}
            try {
                d = JSON.parse(String(p || "{}"))
            } catch (e) {
                d = {}
            }

            var old = selected
            audit = d
            canUndo = !!d.canUndo
            selected = -1
            mappingMode = false
            newRecordMode = false
            issues.clear()
            preview.clear()
            createdRows.clear()

            var incomingIssues = d.issues || []
            for (var i = 0; i < incomingIssues.length; ++i) {
                var r = incomingIssues[i] || {}
                issues.append({
                    line: String(r.line || ""),
                    status: String(r.status || ""),
                    decision: String(r.decision || ""),
                    problem: String(r.problem || ""),
                    diagnosis: String(r.diagnosis || ""),
                    expected: String(r.expectedColumns || ""),
                    actual: String(r.actualColumns || ""),
                    confidence: String(r.confidence || ""),
                    joinLine: String(r.joinCandidateLine || ""),
                    hasJoin: !!r.joinCandidateRecordIndex,
                    columnsJson: JSON.stringify(r.columns || [])
                })
            }

            var cr = d.createdRecords || []
            for (var j = 0; j < cr.length; ++j) {
                var created = cr[j] || {}
                if (created.active !== false) {
                    createdRows.append({
                        recordId: Number(created.id || 0),
                        valuesJson: JSON.stringify(created.values || {})
                    })
                }
            }

            if (issues.count > 0) {
                var next = Math.max(0, Math.min(old, issues.count - 1))
                showIssue(next)
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 22
        spacing: 10

        PageTitle { text: "Record Repair" }

        Text {
            text: "Detect broken records, reconstruct shifted lines, and resolve overflow without changing the source file."
            color: "#94a3b8"
        }

        Card {
            Layout.fillWidth: true
            implicitHeight: 70

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10

                TextField {
                    Layout.fillWidth: true
                    readOnly: true
                    text: src
                    placeholderText: "CSV / TXT / TSV"
                }

                AppButton {
                    text: "Choose File"
                    onClicked: openDlg.open()
                }

                AppButton {
                    text: "Undo Last Action"
                    enabled: canUndo
                    onClicked: backend.undoRepairAction()
                }

                PrimaryButton {
                    text: "Save Reviewed Copy"
                    enabled: src !== ""
                    onClicked: saveDlg.open()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Repeater {
                model: [
                    ["RECORDS", audit.records || 0],
                    ["EXPECTED FIELDS", audit.expected || 0],
                    ["HEALTHY", audit.healthy || 0],
                    ["AUTO FIXED", audit.autoFixed || 0],
                    ["NEEDS REVIEW", audit.reviewRequired || 0]
                ]

                delegate: Card {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 58

                    Column {
                        anchors.fill: parent
                        anchors.margins: 8

                        Text {
                            text: modelData[1]
                            color: "#22c55e"
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Text {
                            text: modelData[0]
                            color: "#94a3b8"
                            font.pixelSize: 9
                            font.bold: true
                        }
                    }
                }
            }
        }

        Card {
            visible: createdRows.count > 0
            Layout.fillWidth: true
            implicitHeight: Math.min(170, 62 + createdRows.count * 42)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "✓ New line created — " + createdRows.count + " user-created line(s) are included in the reviewed output"
                        color: "#22c55e"
                        font.bold: true
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "Delete or Undo remains available."
                        color: "#94a3b8"
                    }
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: createdRows
                    clip: true

                    delegate: Rectangle {
                        property var rowData: (index >= 0 && index < createdRows.count) ? createdRows.get(index) : null
                        width: ListView.view ? ListView.view.width : 0
                        height: 40
                        color: "#113426"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 4

                            Text {
                                property var vals: rowData ? JSON.parse(String(rowData.valuesJson || "{}")) : ({})
                                text: rowData ? "NEW LINE #" + rowData.recordId + "    SID: " + (vals["SID"] || "—") + "    Store: " + (vals["Store Name"] || "—") + "    ZIP: " + (vals["ZIP"] || "—") : ""
                                color: "#f8fafc"
                                font.bold: true
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Button {
                                enabled: !!rowData
                                text: "Delete"
                                onClicked: if (rowData) backend.deleteRepairRecord(rowData.recordId)
                            }
                        }
                    }
                }
            }
        }

        SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: Qt.Vertical

            Card {
                SplitView.minimumHeight: 120
                SplitView.preferredHeight: Math.min(250, Math.max(130, issues.count * 36 + 48))

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10

                    RowLayout {
                        Text {
                            text: "Repair Queue"
                            color: "#f8fafc"
                            font.bold: true
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            visible: Number(audit.unresolved || 0) > 0
                            text: Number(audit.unresolved || 0) + " record(s) need review"
                            color: "#f59e0b"
                            font.bold: true
                        }
                    }

                    Text {
                        visible: issues.count === 0
                        text: "No structural findings. This panel collapses when there is nothing to review."
                        color: "#22c55e"
                    }

                    ListView {
                        visible: issues.count > 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: issues
                        clip: true

                        delegate: Rectangle {
                            property var rowData: (index >= 0 && index < issues.count) ? issues.get(index) : null
                            width: ListView.view ? ListView.view.width : 0
                            height: 36
                            color: selected === index ? "#17375f" : (rowData && String(rowData.status) === "AUTO FIXED" ? "#113426" : "#421820")

                            MouseArea {
                                anchors.fill: parent
                                onClicked: if (rowData) showIssue(index)
                            }

                            RowLayout {
                                anchors.fill: parent

                                Text {
                                    text: rowData ? String(rowData.line || "") : ""
                                    color: "#f8fafc"
                                    Layout.preferredWidth: 70
                                    leftPadding: 6
                                }

                                Text {
                                    text: rowData ? String(rowData.status || "") : ""
                                    color: rowData && String(rowData.status) === "AUTO FIXED" ? "#22c55e" : "#f59e0b"
                                    font.bold: true
                                    Layout.preferredWidth: 135
                                }

                                Text {
                                    text: rowData ? String(rowData.problem || "") : ""
                                    color: "#f8fafc"
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: rowData ? String(rowData.expected || "") + " → " + String(rowData.actual || "") : ""
                                    color: rowData && String(rowData.expected) === String(rowData.actual) ? "#22c55e" : "#ef4444"
                                    Layout.preferredWidth: 90
                                }
                            }
                        }
                    }
                }
            }

            Card {
                SplitView.minimumHeight: 300
                SplitView.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10

                    Text {
                        text: "Record Reconstruction Inspector"
                        color: "#f8fafc"
                        font.bold: true
                    }

                    Rectangle {
                        visible: selected >= 0 && selected < issues.count
                        Layout.fillWidth: true
                        implicitHeight: 54
                        radius: 6
                        color: {
                            var q = issueAt(selected)
                            return q && q.hasJoin ? "#123b2a" : "#342611"
                        }

                        Text {
                            anchors.fill: parent
                            anchors.margins: 8
                            text: {
                                var q = issueAt(selected)
                                return q ? String(q.diagnosis || "") : ""
                            }
                            color: "#f8fafc"
                            wrapMode: Text.WordWrap
                        }
                    }

                    RowLayout {
                        visible: selected >= 0 && selected < issues.count
                        Layout.fillWidth: true

                        Text {
                            text: "Record decision"
                            color: "#94a3b8"
                            font.bold: true
                        }

                        PrimaryButton {
                            visible: {
                                var q = issueAt(selected)
                                return !!(q && q.hasJoin)
                            }
                            text: {
                                var q = issueAt(selected)
                                return q ? "Join Rows " + q.line + " + " + q.joinLine : "Join Rows"
                            }
                            onClicked: backend.joinRepairRows(selected)
                        }

                        AppButton {
                            text: mappingMode ? "Hide Overflow Mapping" : "Repair / Absorb Overflow"
                            onClicked: {
                                mappingMode = !mappingMode
                                newRecordMode = false
                            }
                        }

                        AppButton {
                            text: newRecordMode ? "Cancel New Line" : "Create New Line"
                            onClicked: {
                                newRecordMode = !newRecordMode
                                mappingMode = newRecordMode
                            }
                        }

                        AppButton {
                            text: "Keep Entire Record"
                            enabled: {
                                var q = issueAt(selected)
                                return !!(q && String(q.problem || "").indexOf("Extra") >= 0)
                            }
                            onClicked: backend.keepRepairIssue(selected)
                        }

                        TextField {
                            id: newSid
                            visible: newRecordMode
                            Layout.preferredWidth: 150
                            placeholderText: "New SID (required)"
                        }

                        PrimaryButton {
                            visible: newRecordMode
                            text: "Confirm New Line"
                            enabled: newSid.text.trim().length > 0
                            onClicked: createNewRecord()
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: newRecordMode
                                  ? "Create a separate record only when the overflow belongs to another store. Values are not absorbed into the original row."
                                  : mappingMode
                                    ? "Absorb preserved overflow only into EMPTY fields of this same record. Occupied fields cannot be overwritten."
                                    : "Choose whether the overflow belongs to this record, a new record, or should remain unresolved."
                            color: "#60a5fa"
                            wrapMode: Text.WordWrap
                            Layout.preferredWidth: 520
                        }
                    }

                    GridLayout {
                        visible: selected >= 0 && selected < issues.count
                        Layout.fillWidth: true
                        columns: 6
                        columnSpacing: 8

                        Text { text: "Field / Source"; color: "#94a3b8"; font.bold: true; Layout.preferredWidth: 175 }
                        Text { text: "Detected"; color: "#94a3b8"; font.bold: true; Layout.preferredWidth: 150 }
                        Text { text: "Smart Suggestion"; color: "#94a3b8"; font.bold: true; Layout.preferredWidth: 165 }
                        Text { text: "Confidence"; color: "#94a3b8"; font.bold: true; Layout.preferredWidth: 90 }
                        Text { text: "Reason"; color: "#94a3b8"; font.bold: true; Layout.fillWidth: true }
                        Text { text: "Action"; color: "#94a3b8"; font.bold: true; Layout.preferredWidth: 210 }
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: preview
                        clip: true

                        delegate: Rectangle {
                            property var rowData: (index >= 0 && index < preview.count) ? preview.get(index) : null
                            width: ListView.view ? ListView.view.width : 0
                            height: 48
                            color: rowData && (String(rowData.state) === "USER APPROVED" || String(rowData.state) === "NEW RECORD")
                                   ? "#113426"
                                   : rowData && (String(rowData.state) === "REVIEW" || String(rowData.state) === "UNRESOLVED" || String(rowData.state) === "MISSING")
                                     ? "#421820"
                                     : index % 2 ? "#0d1b2e" : "#0b1829"

                            RowLayout {
                                anchors.fill: parent
                                spacing: 8

                                Text {
                                    text: rowData ? String(rowData.field || "") : ""
                                    color: "#f8fafc"
                                    font.bold: true
                                    Layout.preferredWidth: 175
                                    leftPadding: 6
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: rowData ? String(rowData.before || "") : ""
                                    color: "#f8fafc"
                                    Layout.preferredWidth: 150
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: rowData ? (String(rowData.state) === "USER APPROVED" ? String(rowData.after || "") + " → " + (String(rowData.target || "") || String(rowData.suggested || "")) : (String(rowData.suggested || "") || "—")) : ""
                                    color: rowData && (String(rowData.suggested || "") || String(rowData.target || "")) ? "#60a5fa" : "#94a3b8"
                                    Layout.preferredWidth: 165
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: rowData && Number(rowData.confidence) > 0 ? String(rowData.confidence) + "%" : "—"
                                    color: rowData && Number(rowData.confidence) >= 95 ? "#22c55e" : (rowData && Number(rowData.confidence) >= 70 ? "#f59e0b" : "#94a3b8")
                                    font.bold: true
                                    Layout.preferredWidth: 90
                                }

                                Text {
                                    text: rowData ? String(rowData.reason || "") : ""
                                    color: "#94a3b8"
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                RowLayout {
                                    Layout.preferredWidth: 210
                                    visible: mappingMode && rowData && String(rowData.field || "").indexOf("PRESERVED EXTRA") === 0

                                    ComboBox {
                                        id: dest
                                        Layout.preferredWidth: 120
                                        model: audit.header || []
                                        currentIndex: rowData && String(rowData.target || "") ? (audit.header || []).indexOf(String(rowData.target)) : -1
                                        onActivated: if (index >= 0 && index < preview.count) preview.setProperty(index, "target", currentText)
                                    }

                                    Button {
                                        visible: !newRecordMode
                                        text: rowData && String(rowData.state) === "USER APPROVED" ? "Absorbed" : "Absorb"
                                        enabled: !!rowData && dest.currentIndex >= 0 && String(rowData.state) !== "USER APPROVED"
                                        onClicked: if (rowData) backend.applyRepairMapping(selected, rowData.sourceIndex, dest.currentText, true)
                                    }

                                    Button {
                                        visible: !newRecordMode
                                        text: "Keep"
                                        enabled: !!rowData && String(rowData.state) !== "USER APPROVED"
                                        onClicked: if (rowData) backend.keepRepairUnresolved(selected, rowData.sourceIndex)
                                    }
                                }

                                Text {
                                    visible: !mappingMode || !rowData || String(rowData.field || "").indexOf("PRESERVED EXTRA") !== 0
                                    text: rowData ? String(rowData.state || "") : ""
                                    color: rowData && (String(rowData.state) === "USER APPROVED" || String(rowData.state) === "NEW RECORD") ? "#22c55e" : "#94a3b8"
                                    Layout.preferredWidth: 210
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
