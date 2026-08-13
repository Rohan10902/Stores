import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"
import "../theme"

Item {
    id: root

    readonly property var headers: ["Store Name", "SID", "Banner", "Nielsen Store Code", "Trip Received", "Last Trip", "Address 1", "Address 2", "City", "State", "Pincode", "Phone"]
    readonly property var columnWidths: [155, 155, 155, 180, 155, 155, 210, 180, 140, 150, 110, 160]
    readonly property int tableWidth: 2025
    readonly property int minimumRows: 10
    property var rows: []
    property var selected: []
    property var findings: []
    property bool validated: false
    property bool validationPending: false
    property bool exporting: false
    property string destinationPath: ""

    function blankRow() {
        var row = []
        for (var i = 0; i < root.headers.length; i++) row.push("")
        return row
    }

    function resetRows() {
        var next = [], picked = []
        for (var i = 0; i < root.minimumRows; i++) { next.push(root.blankRow()); picked.push(true) }
        root.rows = next; root.selected = picked; root.findings = []; root.validated = false; root.validationPending = false
    }

    function hasData(row) {
        if (!row) return false
        for (var i = 0; i < row.length; i++) if (String(row[i] || "").trim() !== "") return true
        return false
    }

    function enteredCount() {
        var count = 0
        for (var i = 0; i < root.rows.length; i++) if (root.hasData(root.rows[i])) count++
        return count
    }

    function includedCount() {
        var count = 0
        for (var i = 0; i < root.rows.length; i++) if (root.selected[i] && root.hasData(root.rows[i])) count++
        return count
    }

    function invalidate() {
        root.validated = false
        root.findings = []
    }

    function setCell(rowIndex, columnIndex, value) {
        if (rowIndex < 0 || rowIndex >= root.rows.length) return
        var next = root.rows.slice(), row = next[rowIndex].slice()
        row[columnIndex] = value; next[rowIndex] = row
        root.rows = next; root.invalidate()
    }

    function setSelected(index, value) {
        var next = root.selected.slice(); next[index] = value; root.selected = next; root.invalidate()
    }

    function addRow() {
        var nextRows = root.rows.slice(), nextSelected = root.selected.slice()
        nextRows.push(root.blankRow()); nextSelected.push(true)
        root.rows = nextRows; root.selected = nextSelected; root.invalidate()
    }

    function selectAll() {
        var next = []
        for (var i = 0; i < root.rows.length; i++) next.push(true)
        root.selected = next; root.invalidate()
    }

    function deselectAll() {
        var next = []
        for (var i = 0; i < root.rows.length; i++) next.push(false)
        root.selected = next; root.invalidate()
    }

    function deleteSelected() {
        var nextRows = [], nextSelected = []
        for (var i = 0; i < root.rows.length; i++) {
            if (!root.selected[i]) { nextRows.push(root.rows[i]); nextSelected.push(false) }
        }
        while (nextRows.length < root.minimumRows) { nextRows.push(root.blankRow()); nextSelected.push(true) }
        root.rows = nextRows; root.selected = nextSelected; root.findings = []; root.validated = false
    }

    function validationRowsJson() {
        var output = []
        for (var r = 0; r < root.rows.length; r++) {
            if (!root.selected[r] || !root.hasData(root.rows[r])) continue
            var record = {}
            for (var c = 0; c < root.headers.length; c++) record[root.headers[c]] = String(root.rows[r][c] || "").trim()
            output.push(record)
        }
        return JSON.stringify(output)
    }

    function validateRows() {
        if (root.includedCount() === 0 || root.validationPending) return
        root.validationPending = true
        root.validated = false
        root.findings = []
        if (typeof backend !== "undefined" && backend.creator !== undefined) {
            backend.creator.validate_creator(root.validationRowsJson())
        } else {
            root.validationPending = false
            root.findings = [{row: 0, field: "SYSTEM", message: "Validation backend is unavailable.", severity: "ERROR"}]
        }
    }

    function parseDelimited(text) {
        var source = String(text || "").replace(/\r\n/g, "\n").replace(/\r/g, "\n")
        if (!source.trim()) return []
        var delimiter = source.indexOf("\t") >= 0 ? "\t" : ","
        var parsed = [], row = [], cell = "", quoted = false
        for (var i = 0; i < source.length; i++) {
            var ch = source.charAt(i)
            if (ch === '"') {
                if (quoted && i + 1 < source.length && source.charAt(i + 1) === '"') { cell += '"'; i++ }
                else quoted = !quoted
            } else if (ch === delimiter && !quoted) {
                row.push(cell); cell = ""
            } else if (ch === "\n" && !quoted) {
                row.push(cell); parsed.push(row); row = []; cell = ""
            } else {
                cell += ch
            }
        }
        if (quoted) return []
        if (cell !== "" || row.length) { row.push(cell); parsed.push(row) }
        return parsed
    }

    function importPasted(text) {
        var parsed = root.parseDelimited(text)
        if (parsed.length === 0) return
        var firstText = parsed[0].map(function(v) { return String(v).trim().toLowerCase() }).join("|")
        if (firstText.indexOf("store name") >= 0 || firstText.indexOf("nielsen store code") >= 0) parsed.shift()
        if (parsed.length === 0) return

        var nextRows = root.rows.slice(), nextSelected = root.selected.slice(), cursor = 0
        for (var p = 0; p < parsed.length; p++) {
            while (cursor < nextRows.length && root.hasData(nextRows[cursor])) cursor++
            if (cursor >= nextRows.length) { nextRows.push(root.blankRow()); nextSelected.push(true) }
            var row = root.blankRow()
            for (var c = 0; c < root.headers.length && c < parsed[p].length; c++) row[c] = String(parsed[p][c]).trim()
            nextRows[cursor] = row; nextSelected[cursor] = true; cursor++
        }
        root.rows = nextRows; root.selected = nextSelected; root.findings = []; root.validated = false; pasteDialog.close()
    }

    function urlToPath(value) {
        var text = String(value || "")
        if (text.indexOf("file:///") === 0) text = text.substring(8)
        else if (text.indexOf("file://") === 0) text = text.substring(7)
        if (Qt.platform.os === "windows") text = text.replace(/^\/+/, "")
        try { return decodeURIComponent(text) } catch (e) { return text }
    }

    function exportRows() {
        if (!root.validated || root.findings.length > 0 || root.includedCount() === 0 || root.exporting) return
        var output = []
        for (var i = 0; i < root.rows.length; i++) if (root.selected[i] && root.hasData(root.rows[i])) output.push(root.rows[i])
        root.exporting = true
        if (typeof backend !== "undefined" && backend.creator !== undefined) backend.creator.export_builder_file(JSON.stringify(output), root.destinationPath, JSON.stringify(root.headers))
        else root.exporting = false
    }

    Component.onCompleted: root.resetRows()

    FileDialog {
        id: exportDialog
        title: "Export Store Builder CSV"
        fileMode: FileDialog.SaveFile
        currentFile: "store_builder.csv"
        nameFilters: ["CSV Files (*.csv)", "All Files (*)"]
        onAccepted: { root.destinationPath = root.urlToPath(selectedFile); root.exportRows() }
    }

    Dialog {
        id: pasteDialog
        title: "Paste Stores"
        modal: true
        width: Math.min(root.width - 80, 900)
        height: Math.min(root.height - 100, 600)
        standardButtons: Dialog.Cancel

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.spacingMedium
            Text { text: "Paste tab-separated or comma-separated store rows below. Quoted CSV values are preserved."; color: Theme.textSecondary; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            TextArea {
                id: pasteArea
                Layout.fillWidth: true; Layout.fillHeight: true
                placeholderText: "Store Name\tSID\tBanner\tNielsen Store Code\tTrip Received\tLast Trip\tAddress 1"
                color: Theme.textPrimary; selectionColor: Theme.primary
                background: Rectangle { color: Theme.background; border.color: Theme.border; radius: Theme.radiusMedium }
            }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                PrimaryButton { text: "Import Stores"; onClicked: root.importPasted(pasteArea.text) }
            }
        }
    }

    Connections {
        target: typeof backend !== "undefined" && backend.creator !== undefined ? backend.creator : null
        ignoreUnknownSignals: true
        function onCreatorReady(payload) {
            try {
                var data = JSON.parse(payload || "{}")
                root.findings = data.findings || []
                root.validated = true
            } catch (e) {
                root.findings = [{row: 0, field: "SYSTEM", message: String(e), severity: "ERROR"}]
                root.validated = true
            }
            root.validationPending = false
        }
        function onBuilderExported() { root.exporting = false; root.destinationPath = "" }
    }

    ScrollView {
        anchors.fill: parent
        clip: true
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        ColumnLayout {
            width: parent.width
            spacing: Theme.spacingLarge

            PageTitle {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacingXLarge; Layout.rightMargin: Theme.spacingXLarge; Layout.topMargin: Theme.spacingLarge
                title: "Store Builder"
                subtitle: "Build, paste, validate and export store records in one canonical spreadsheet workspace."
            }

            Card {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacingXLarge; Layout.rightMargin: Theme.spacingXLarge
                Layout.preferredHeight: 86
                RowLayout {
                    anchors.fill: parent; anchors.margins: Theme.spacingSmall; spacing: 6
                    AppButton { text: "Paste Stores"; onClicked: { pasteArea.clear(); pasteDialog.open(); pasteArea.forceActiveFocus() } }
                    AppButton { text: "+ Add Row"; onClicked: root.addRow() }
                    AppButton { text: "Select All"; onClicked: root.selectAll() }
                    AppButton { text: "Deselect All"; onClicked: root.deselectAll() }
                    AppButton { text: "Delete Selected"; onClicked: root.deleteSelected() }
                    AppButton { text: "Clear"; onClicked: root.resetRows() }
                    Item { Layout.fillWidth: true }
                    ColumnLayout {
                        spacing: 1
                        Text { text: root.enteredCount() + " entered  •  " + root.includedCount() + " included"; color: Theme.textPrimary; font.bold: true; Layout.alignment: Qt.AlignRight }
                        Text { text: Math.max(10, root.rows.length) + " rows available — expands automatically"; color: Theme.textSecondary; font.pixelSize: 10; Layout.alignment: Qt.AlignRight }
                    }
                    AppButton { text: root.validationPending ? "Validating..." : "Validate"; enabled: root.enteredCount() > 0 && !root.validationPending; onClicked: root.validateRows() }
                    PrimaryButton { text: root.exporting ? "Exporting..." : "Export CSV"; enabled: root.includedCount() > 0 && root.validated && root.findings.length === 0 && !root.validationPending && !root.exporting; onClicked: exportDialog.open() }
                }
            }

            Card {
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 600
                Layout.leftMargin: Theme.spacingXLarge; Layout.rightMargin: Theme.spacingXLarge; Layout.bottomMargin: Theme.spacingXLarge
                ScrollView {
                    anchors.fill: parent; anchors.margins: 8; clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AsNeeded; ScrollBar.vertical.policy: ScrollBar.AsNeeded
                    Column {
                        width: root.tableWidth; spacing: 0
                        Rectangle {
                            width: root.tableWidth; height: 42; color: Theme.surfaceElevated; border.color: Theme.border
                            Row {
                                anchors.fill: parent
                                Rectangle { width: 120; height: 42; color: "transparent"; border.color: Theme.border; Text { anchors.fill: parent; anchors.margins: 8; verticalAlignment: Text.AlignVCenter; text: "USE / ROW"; color: Theme.textPrimary; font.bold: true } }
                                Repeater {
                                    model: root.headers
                                    delegate: Rectangle {
                                        required property string modelData
                                        width: root.columnWidths[index]; height: 42; color: "transparent"; border.color: Theme.border
                                        Text { anchors.fill: parent; anchors.margins: 8; verticalAlignment: Text.AlignVCenter; text: modelData; color: Theme.textPrimary; font.bold: true; font.pixelSize: 11; elide: Text.ElideRight }
                                    }
                                }
                            }
                        }
                        Repeater {
                            model: root.rows.length
                            delegate: Rectangle {
                                required property int index
                                width: root.tableWidth; height: 38
                                color: index % 2 === 0 ? Theme.background : Theme.surface
                                border.color: Theme.border
                                Row {
                                    anchors.fill: parent
                                    Rectangle {
                                        width: 120; height: 38; color: "transparent"; border.color: Theme.border
                                        RowLayout {
                                            anchors.fill: parent; anchors.leftMargin: 7; spacing: 7
                                            Rectangle {
                                                width: 27; height: 27; radius: 2
                                                color: root.selected[index] ? Theme.background : Theme.surfaceElevated
                                                border.color: root.selected[index] ? Theme.textPrimary : Theme.border
                                                Text { anchors.centerIn: parent; text: root.selected[index] ? "✓" : ""; color: Theme.textPrimary; font.pixelSize: 20 }
                                                MouseArea { anchors.fill: parent; onClicked: root.setSelected(index, !root.selected[index]) }
                                            }
                                            Text { text: index + 1; color: Theme.textSecondary; font.pixelSize: 11 }
                                        }
                                    }
                                    Repeater {
                                        model: root.headers.length
                                        delegate: Rectangle {
                                            required property int index
                                            width: root.columnWidths[index]; height: 38; color: "transparent"; border.color: Theme.border
                                            TextField {
                                                anchors.fill: parent; anchors.margins: 1
                                                text: root.rows[parent.parent.parent.index][index]
                                                color: Theme.textPrimary; font.pixelSize: 11; leftPadding: 7; rightPadding: 7; selectByMouse: true
                                                background: Rectangle { color: "transparent"; border.color: parent.activeFocus ? Theme.primary : "transparent" }
                                                onEditingFinished: root.setCell(parent.parent.parent.index, index, text)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Card {
                visible: root.findings.length > 0
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacingXLarge; Layout.rightMargin: Theme.spacingXLarge; Layout.bottomMargin: Theme.spacingXLarge
                Layout.preferredHeight: Math.min(240, 70 + root.findings.length * 34)
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: Theme.spacingMedium
                    Text { text: "Validation Findings"; color: Theme.textPrimary; font.bold: true; font.pixelSize: 14 }
                    ListView {
                        Layout.fillWidth: true; Layout.fillHeight: true; model: root.findings; clip: true
                        delegate: Text { required property var modelData; width: ListView.view.width; text: "Row " + modelData.row + " • " + modelData.field + ": " + modelData.message; color: Theme.error; elide: Text.ElideRight }
                    }
                }
            }
        }
    }
}
