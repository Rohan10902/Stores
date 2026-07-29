import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"

Item {
    id: page

    property var headers: ["Store Name", "SID", "Banner", "Nielsen Store Code", "Trip Received", "Last Trip", "Address 1", "Address 2", "Address 3", "ZIP", "Active / Inactive", "Is Census", "Is Exceptions", "Updated By"]
    property int selectedRow: 0
    property int selectedCol: 0
    property bool selectingRows: false
    property bool selectingCols: false
    property int validationCount: 0
    property bool dirty: false
    property var findingRows: ({})
    property var selectedRows: ({})
    property var selectedCols: ({})
    property var undoStack: []
    property string lastBulkSummary: ""

    ListModel { id: grid }
    ListModel { id: validation }

    Component.onCompleted: {
        for (var i = 0; i < 10; ++i)
            addBlank(false)
    }

    function blank() {
        var o = { included: true }
        for (var i = 0; i < headers.length; ++i)
            o["c" + i] = ""
        return o
    }

    function addBlank(mark) {
        grid.append(blank())
        if (mark !== false)
            dirty = true
    }

    function rowHasData(r) {
        if (r < 0 || r >= grid.count)
            return false
        var item = grid.get(r)
        for (var c = 0; c < headers.length; ++c) {
            if (String(item["c" + c] || "").trim() !== "")
                return true
        }
        return false
    }

    function includedCount() {
        var n = 0
        for (var r = 0; r < grid.count; ++r) {
            if (grid.get(r).included && rowHasData(r))
                ++n
        }
        return n
    }

    function populatedCount() {
        var n = 0
        for (var r = 0; r < grid.count; ++r) {
            if (rowHasData(r))
                ++n
        }
        return n
    }

    function selectedCount() {
        var n = 0
        for (var r = 0; r < grid.count; ++r) {
            if (grid.get(r).included)
                ++n
        }
        return n
    }

    function setAllIncluded(v) {
        for (var r = 0; r < grid.count; ++r)
            grid.setProperty(r, "included", v)
        dirty = true
    }

    function deleteCheckedRows() {
        for (var r = grid.count - 1; r >= 0; --r) {
            if (grid.get(r).included)
                grid.remove(r)
        }
        if (grid.count === 0) {
            for (var i = 0; i < 10; ++i)
                addBlank(false)
        }
        selectedRow = Math.max(0, Math.min(selectedRow, grid.count - 1))
        validation.clear()
        validationCount = 0
        findingRows = {}
        dirty = true
    }

    function rowsJson() {
        var rows = []
        for (var r = 0; r < grid.count; ++r) {
            var item = grid.get(r)
            if (!item.included || !rowHasData(r))
                continue
            var row = {}
            for (var c = 0; c < headers.length; ++c)
                row[headers[c]] = item["c" + c] || ""
            rows.push(row)
        }
        return JSON.stringify(rows)
    }

    function pasteText(t) {
        if (!t)
            return
        var lines = String(t).replace(/\r\n/g, "\n").replace(/\r/g, "\n").split("\n")
        if (lines.length && lines[lines.length - 1] === "")
            lines.pop()
        if (!lines.length)
            return

        var start = selectedRow
        for (var r = 0; r < lines.length; ++r) {
            var vals = lines[r].indexOf("\t") >= 0 ? lines[r].split("\t") : lines[r].split(",")
            var targetRow = start + r
            while (grid.count <= targetRow)
                addBlank(false)
            grid.setProperty(targetRow, "included", true)
            for (var c = 0; c < vals.length && selectedCol + c < headers.length; ++c)
                grid.setProperty(targetRow, "c" + (selectedCol + c), vals[c])
        }
        dirty = true
        backend.say("Pasted " + lines.length + " row(s). Extra rows were created automatically.")
    }

    function clearAll() {
        grid.clear()
        for (var i = 0; i < 10; ++i)
            addBlank(false)
        validation.clear()
        validationCount = 0
        findingRows = {}
        selectedRows = {}
        selectedCols = {}
        undoStack = []
        lastBulkSummary = ""
        dirty = false
    }

    function rowHasFinding(rr) {
        return !!findingRows[String(rr + 1)]
    }

    function rowBackground(rr) {
        return rowHasFinding(rr) ? "#3a211b" : (rr % 2 ? "#0d1b2e" : "#0b1829")
    }

    function cellBackground(rr, cc) {
        if (!grid.get(rr).included)
            return "#151b25"
        if (rowHasFinding(rr))
            return "#301b1d"
        if (selectedRow === rr && selectedCol === cc)
            return "#17375f"
        return rr % 2 ? "#0d1b2e" : "#0b1829"
    }

    function rowBorder(rr) {
        return selectedRow === rr ? "#60a5fa" : "#29415f"
    }

    function cellBorder(rr, cc) {
        return selectedRow === rr && selectedCol === cc ? "#60a5fa" : "#29415f"
    }

    function cellBorderWidth(rr, cc) {
        return selectedRow === rr && selectedCol === cc ? 2 : 1
    }

    function cellTextColor(rr) {
        return grid.get(rr).included ? "#f8fafc" : "#64748b"
    }

    function rowSelected(r) {
        return !!selectedRows[String(r)]
    }

    function colSelected(c) {
        return !!selectedCols[String(c)]
    }

    function toggleRow(r) {
        var m = Object.assign({}, selectedRows)
        var k = String(r)
        if (m[k])
            delete m[k]
        else
            m[k] = true
        selectedRows = m
    }

    function toggleCol(c) {
        var m = Object.assign({}, selectedCols)
        var k = String(c)
        if (m[k])
            delete m[k]
        else
            m[k] = true
        selectedCols = m
    }

    function selectedRowIndices() {
        var a = []
        for (var r = 0; r < grid.count; ++r) {
            if (selectedRows[String(r)])
                a.push(r)
        }
        return a
    }

    function selectedColIndices() {
        var a = []
        for (var c = 0; c < headers.length; ++c) {
            if (selectedCols[String(c)])
                a.push(c)
        }
        return a
    }

    function effectiveRows() {
        var a = selectedRowIndices()
        if (a.length)
            return a
        for (var r = 0; r < grid.count; ++r) {
            if (grid.get(r).included && rowHasData(r))
                a.push(r)
        }
        return a
    }

    function effectiveCols() {
        var a = selectedColIndices()
        if (a.length)
            return a
        return [selectedCol]
    }

    function pushUndo(changes, label) {
        undoStack = undoStack.concat([{ label: label, changes: changes }])
        if (undoStack.length > 20)
            undoStack = undoStack.slice(1)
    }

    function undoBulk() {
        if (!undoStack.length) {
            backend.say("Nothing to undo.")
            return
        }
        var stack = undoStack.slice()
        var action = stack.pop()
        for (var i = 0; i < action.changes.length; ++i) {
            var x = action.changes[i]
            if (x.row < grid.count)
                grid.setProperty(x.row, "c" + x.col, x.before)
        }
        undoStack = stack
        dirty = true
        lastBulkSummary = "Undid: " + action.label
        backend.say(lastBulkSummary)
    }

    function applyBulkValue(value) {
        var rs = effectiveRows()
        var cs = effectiveCols()
        var changes = []
        for (var i = 0; i < rs.length; ++i) {
            for (var j = 0; j < cs.length; ++j) {
                var before = String(grid.get(rs[i])["c" + cs[j]] || "")
                if (before !== value) {
                    changes.push({ row: rs[i], col: cs[j], before: before })
                    grid.setProperty(rs[i], "c" + cs[j], value)
                }
            }
        }
        if (changes.length) {
            pushUndo(changes, "Set value in " + changes.length + " cell(s)")
            dirty = true
            lastBulkSummary = "Set '" + value + "' in " + changes.length + " cell(s)."
            backend.say(lastBulkSummary)
        } else {
            backend.say("No cells changed.")
        }
    }

    function fillDown() {
        var rs = selectedRowIndices()
        var cs = effectiveCols()
        if (rs.length < 2) {
            backend.say("Select at least two rows for Fill Down.")
            return
        }
        var changes = []
        for (var j = 0; j < cs.length; ++j) {
            var source = String(grid.get(rs[0])["c" + cs[j]] || "")
            for (var i = 1; i < rs.length; ++i) {
                var before = String(grid.get(rs[i])["c" + cs[j]] || "")
                if (before !== source) {
                    changes.push({ row: rs[i], col: cs[j], before: before })
                    grid.setProperty(rs[i], "c" + cs[j], source)
                }
            }
        }
        if (changes.length) {
            pushUndo(changes, "Fill Down")
            dirty = true
            lastBulkSummary = "Filled " + changes.length + " cell(s) down."
            backend.say(lastBulkSummary)
        }
    }

    function padZeros(width) {
        var w = parseInt(width)
        if (!w || w < 1) {
            backend.say("Enter a valid padding width.")
            return
        }
        var cs = selectedColIndices()
        if (!cs.length)
            cs = [selectedCol]
        var changes = []
        var rs = effectiveRows()
        for (var i = 0; i < rs.length; ++i) {
            for (var j = 0; j < cs.length; ++j) {
                var c = cs[j]
                if (c !== 1 && c !== 3) {
                    backend.say("Zero padding is only available for SID and Nielsen Store Code.")
                    return
                }
                var before = String(grid.get(rs[i])["c" + c] || "").trim()
                if (!before || !/^\d+$/.test(before))
                    continue
                var after = before.length >= w ? before : before.padStart(w, "0")
                if (after !== before) {
                    changes.push({ row: rs[i], col: c, before: before })
                    grid.setProperty(rs[i], "c" + c, after)
                }
            }
        }
        if (changes.length) {
            pushUndo(changes, "Zero padding to width " + w)
            dirty = true
            lastBulkSummary = "Padded " + changes.length + " identifier(s) to width " + w + "."
            backend.say(lastBulkSummary)
        } else {
            backend.say("No numeric identifiers needed padding.")
        }
    }

    function trimValues() {
        var rs = effectiveRows()
        var cs = effectiveCols()
        var changes = []
        for (var i = 0; i < rs.length; ++i) {
            for (var j = 0; j < cs.length; ++j) {
                var before = String(grid.get(rs[i])["c" + cs[j]] || "")
                var after = before.trim()
                if (before !== after) {
                    changes.push({ row: rs[i], col: cs[j], before: before })
                    grid.setProperty(rs[i], "c" + cs[j], after)
                }
            }
        }
        if (changes.length) {
            pushUndo(changes, "Trim whitespace")
            dirty = true
            backend.say("Trimmed " + changes.length + " cell(s).")
        }
    }

    function clearSelectedValues() {
        var rs = effectiveRows()
        var cs = effectiveCols()
        var changes = []
        for (var i = 0; i < rs.length; ++i) {
            for (var j = 0; j < cs.length; ++j) {
                var before = String(grid.get(rs[i])["c" + cs[j]] || "")
                if (before) {
                    changes.push({ row: rs[i], col: cs[j], before: before })
                    grid.setProperty(rs[i], "c" + cs[j], "")
                }
            }
        }
        if (changes.length) {
            pushUndo(changes, "Clear selected values")
            dirty = true
            backend.say("Cleared " + changes.length + " cell(s).")
        }
    }

    function normalizeBooleans() {
        var rs = effectiveRows()
        var cs = effectiveCols()
        var changes = []
        for (var i = 0; i < rs.length; ++i) {
            for (var j = 0; j < cs.length; ++j) {
                var c = cs[j]
                if (c !== 10 && c !== 11 && c !== 12)
                    continue
                var before = String(grid.get(rs[i])["c" + c] || "").trim().toLowerCase()
                var after = before
                if (["1", "1.0", "true", "yes", "active"].indexOf(before) >= 0)
                    after = "1"
                else if (["0", "0.0", "false", "no", "inactive"].indexOf(before) >= 0)
                    after = "0"
                if (after !== before) {
                    changes.push({ row: rs[i], col: c, before: before })
                    grid.setProperty(rs[i], "c" + c, after)
                }
            }
        }
        if (changes.length) {
            pushUndo(changes, "Normalize flags to 0/1")
            dirty = true
            backend.say("Normalized " + changes.length + " flag value(s) to 0/1.")
        }
    }

    FileDialog {
        id: saveDlg
        fileMode: FileDialog.SaveFile
        nameFilters: ["CSV (*.csv)"]
        onAccepted: backend.exportCreator(rowsJson(), selectedFile.toString())
    }

    Dialog {
        id: bulkDialog
        modal: true
        title: "Bulk Actions"
        standardButtons: Dialog.Cancel
        width: 460

        ColumnLayout {
            anchors.fill: parent
            spacing: 10

            Text {
                text: "Selected rows: " + selectedRowIndices().length + "  •  Selected columns: " + selectedColIndices().length
                color: "#94a3b8"
            }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "Value:"; color: "#f8fafc" }
                TextField { id: bulkValue; Layout.fillWidth: true; placeholderText: "Value to apply" }
                Button { text: "Set Value"; onClicked: { applyBulkValue(bulkValue.text); bulkDialog.close() } }
            }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "Zero-pad width:"; color: "#f8fafc" }
                SpinBox { id: padWidth; from: 1; to: 100; value: 8 }
                Button { text: "Pad SID / Nielsen"; onClicked: { padZeros(padWidth.value); bulkDialog.close() } }
            }

            RowLayout {
                Layout.fillWidth: true
                Button { text: "Fill Down"; onClicked: { fillDown(); bulkDialog.close() } }
                Button { text: "Trim Whitespace"; onClicked: { trimValues(); bulkDialog.close() } }
                Button { text: "Normalize 0/1"; onClicked: { normalizeBooleans(); bulkDialog.close() } }
            }

            RowLayout {
                Layout.fillWidth: true
                Button { text: "Clear Values"; onClicked: { clearSelectedValues(); bulkDialog.close() } }
                Button { text: "Undo Last Bulk Action"; enabled: undoStack.length > 0; onClicked: { undoBulk(); bulkDialog.close() } }
            }

            Text {
                text: lastBulkSummary
                color: "#60a5fa"
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
        }
    }

    Connections {
        target: backend
        function onCreatorReady(payload) {
            var d = JSON.parse(payload)
            validationCount = Number(d.count || 0)
            validation.clear()
            var map = {}
            for (var i = 0; i < d.findings.length; ++i) {
                var x = d.findings[i]
                var rn = String(x.row)
                map[rn] = true
                validation.append({ row: rn, field: String(x.field), message: String(x.message) })
            }
            findingRows = map
        }
        function onCreatorExported(path) {
            dirty = false
            backend.say("Store CSV exported successfully: " + path)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                PageTitle { text: "Store Builder" }
                Text { text: "Build, paste, validate and export store records in one spreadsheet workspace."; color: "#94a3b8" }
            }
            Rectangle {
                radius: 12
                color: dirty ? "#3b2b12" : "#113426"
                implicitWidth: 150
                implicitHeight: 38
                Text {
                    anchors.centerIn: parent
                    text: dirty ? "● UNSAVED CHANGES" : "✓ READY"
                    color: dirty ? "#fbbf24" : "#4ade80"
                    font.bold: true
                }
            }
        }

        Card {
            Layout.fillWidth: true
            implicitHeight: 68
            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                PrimaryButton {
                    text: "Paste Stores"
                    onClicked: pasteText(backend.clipboardText())
                    ToolTip.visible: hovered
                    ToolTip.text: "Paste rows from Excel, Google Sheets, CSV or TSV"
                }
                AppButton { text: "+ Add Row"; onClicked: addBlank(true) }
                AppButton { text: "Select All"; onClicked: setAllIncluded(true) }
                AppButton { text: "Deselect All"; onClicked: setAllIncluded(false) }
                AppButton { text: "Delete Selected"; enabled: selectedCount() > 0; onClicked: deleteCheckedRows() }
                AppButton { text: "Clear"; onClicked: clearAll() }
                AppButton { text: "Select Rows"; checkable: true; checked: selectingRows; onClicked: selectingRows = checked }
                AppButton { text: "Select Columns"; checkable: true; checked: selectingCols; onClicked: selectingCols = checked }
                AppButton { text: "Bulk Actions"; enabled: selectedRowIndices().length > 0 || selectedColIndices().length > 0; onClicked: bulkDialog.open() }
                Item { Layout.fillWidth: true }
                Column {
                    Text { text: populatedCount() + " entered  •  " + includedCount() + " included"; color: "#f8fafc"; font.bold: true }
                    Text { text: grid.count + " rows available — expands automatically"; color: "#94a3b8"; font.pixelSize: 9 }
                }
                AppButton { text: "Validate"; enabled: includedCount() > 0; onClicked: backend.validateCreator(rowsJson()) }
                PrimaryButton { text: "Export CSV"; enabled: includedCount() > 0; onClicked: saveDlg.open() }
            }
        }

        Rectangle {
            visible: validationCount > 0
            Layout.fillWidth: true
            implicitHeight: 42
            radius: 6
            color: "#433614"
            Text {
                anchors.fill: parent
                anchors.margins: 8
                text: "⚠ " + validationCount + " value(s) need review. Problem rows are highlighted in the grid."
                color: "#fde68a"
                verticalAlignment: Text.AlignVCenter
            }
        }

        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Flickable {
                id: flick
                anchors.fill: parent
                anchors.margins: 8
                contentWidth: 84 + headers.length * 155
                contentHeight: headerRow.height + Math.max(rowList.contentHeight, 1)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.HorizontalFlick

                Row {
                    id: headerRow
                    height: 40
                    Rectangle {
                        width: 84
                        height: 40
                        color: "#10233d"
                        border.color: "#3b5575"
                        Text { anchors.centerIn: parent; text: "USE / ROW"; color: "#bfdbfe"; font.bold: true }
                    }
                    Repeater {
                        model: headers
                        delegate: Rectangle {
                            required property string modelData
                            width: 155
                            height: 40
                            color: page.colSelected(index) ? "#17375f" : "#10233d"
                            border.color: "#3b5575"
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (page.selectingCols)
                                        page.toggleCol(index)
                                    else {
                                        selectedCol = index
                                        selectedRow = 0
                                    }
                                }
                            }
                            Text {
                                anchors.fill: parent
                                anchors.margins: 6
                                text: modelData
                                elide: Text.ElideRight
                                color: "#bfdbfe"
                                font.bold: true
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }

                ListView {
                    id: rowList
                    x: 0
                    y: headerRow.height
                    width: flick.width
                    height: flick.height - headerRow.height
                    contentWidth: flick.contentWidth
                    model: grid
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    cacheBuffer: 120
                    reuseItems: true

                    delegate: Row {
                        id: dataRow
                        required property int index
                        property int rr: index
                        width: flick.contentWidth
                        height: 38

                        Rectangle {
                            width: 84
                            height: 38
                            color: page.rowSelected(dataRow.rr) ? "#17375f" : page.rowBackground(dataRow.rr)
                            border.color: page.rowBorder(dataRow.rr)
                            RowLayout {
                                anchors.fill: parent
                                spacing: 0
                                CheckBox {
                                    checked: grid.get(dataRow.rr).included
                                    onToggled: {
                                        grid.setProperty(dataRow.rr, "included", checked)
                                        dirty = true
                                    }
                                }
                                CheckBox {
                                    visible: page.selectingRows
                                    checked: page.rowSelected(dataRow.rr)
                                    onToggled: page.toggleRow(dataRow.rr)
                                }
                                Text { text: String(dataRow.rr + 1); color: "#94a3b8"; Layout.fillWidth: true }
                            }
                        }

                        Repeater {
                            model: headers.length
                            delegate: TextField {
                                required property int index
                                property int cc: index
                                width: 155
                                height: 38
                                padding: 6
                                text: grid.get(dataRow.rr)["c" + cc] || ""
                                selectByMouse: true
                                background: Rectangle {
                                    color: page.cellBackground(dataRow.rr, cc)
                                    border.width: page.cellBorderWidth(dataRow.rr, cc)
                                    border.color: page.cellBorder(dataRow.rr, cc)
                                }
                                color: page.cellTextColor(dataRow.rr)
                                onActiveFocusChanged: {
                                    if (activeFocus) {
                                        selectedRow = dataRow.rr
                                        selectedCol = cc
                                    }
                                }
                                onEditingFinished: {
                                    grid.setProperty(dataRow.rr, "c" + cc, text)
                                    dirty = true
                                }
                            }
                        }
                    }

                    ScrollBar.vertical: ScrollBar { }
                }

                ScrollBar.horizontal: ScrollBar { }
            }
        }

        Card {
            visible: validation.count > 0
            Layout.fillWidth: true
            implicitHeight: Math.min(150, 42 + validation.count * 28)
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Validation Review"; color: "#f8fafc"; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { text: validation.count + " finding(s)"; color: "#f59e0b" }
                }
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: validation
                    delegate: Text {
                        required property string row
                        required property string field
                        required property string message
                        width: ListView.view.width
                        height: 26
                        text: "Row " + row + "  •  " + field + "  —  " + message
                        color: "#f59e0b"
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
