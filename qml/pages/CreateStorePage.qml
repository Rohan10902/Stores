pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"
import "../theme"

Item {
    id: root

    readonly property var headers: ["Store Name","SID","Banner","Nielsen Store Code","Trip Received","Last Trip","Address 1","Address 2","Address 3","ZIP","Active / Inactive","Is Census","Is Exceptions","Updated By"]
    readonly property var widths: [180,120,140,180,150,150,200,200,200,110,155,120,135,155]
    readonly property int controlColumnWidth: 116
    readonly property int tableWidth: 2400
    readonly property int minimumRows: 10
    readonly property int previewRowCount: 8

    property var rows: []
    property var selected: []
    property var findings: []
    property bool validated: false
    property bool validationPending: false
    property bool exporting: false
    property string destinationPath: ""
    property bool pasteVisible: false
    property bool importPreviewVisible: false
    property bool importPending: false
    property var importedHeaders: []
    property var importedRows: []
    property int importedTotal: 0
    property string importError: ""

    function blankRow() { var result = []; for (var i = 0; i < root.headers.length; ++i) result.push(""); return result }
    function hasData(row) { if (!row) return false; for (var i = 0; i < row.length; ++i) if (String(row[i] || "").trim() !== "") return true; return false }
    function resetRows() { var nextRows = [], nextSelected = []; for (var i = 0; i < root.minimumRows; ++i) { nextRows.push(root.blankRow()); nextSelected.push(true) } root.rows = nextRows; root.selected = nextSelected; root.findings = []; root.validated = false; root.validationPending = false }
    function invalidate() { root.validated = false; root.findings = [] }
    function setCell(rowIndex, columnIndex, value) { if (rowIndex < 0 || rowIndex >= root.rows.length) return; var next = root.rows.slice(); var row = next[rowIndex].slice(); row[columnIndex] = value; next[rowIndex] = row; root.rows = next; root.invalidate() }
    function setSelected(rowIndex, value) { if (rowIndex < 0 || rowIndex >= root.selected.length) return; var next = root.selected.slice(); next[rowIndex] = Boolean(value); root.selected = next; root.invalidate() }
    function addRow() { var next = root.rows.slice(), chosen = root.selected.slice(); next.push(root.blankRow()); chosen.push(true); root.rows = next; root.selected = chosen; root.invalidate() }
    function selectAll(value) { var next = []; for (var i = 0; i < root.rows.length; ++i) next.push(Boolean(value)); root.selected = next; root.invalidate() }
    function deleteSelected() { var next = [], chosen = []; for (var i = 0; i < root.rows.length; ++i) if (!root.selected[i]) { next.push(root.rows[i]); chosen.push(false) } while (next.length < root.minimumRows) { next.push(root.blankRow()); chosen.push(true) } root.rows = next; root.selected = chosen; root.invalidate() }
    function enteredCount() { var count = 0; for (var i = 0; i < root.rows.length; ++i) if (root.hasData(root.rows[i])) ++count; return count }
    function includedCount() { var count = 0; for (var i = 0; i < root.rows.length; ++i) if (root.selected[i] && root.hasData(root.rows[i])) ++count; return count }
    function backendAvailable() { return typeof backend !== "undefined" && backend !== null && backend.creator !== undefined && backend.creator !== null }
    function urlToPath(value) { var text = String(value || ""); if (text.indexOf("file:///") === 0) text = text.substring(8); else if (text.indexOf("file://") === 0) text = text.substring(7); if (Qt.platform.os === "windows") text = text.replace(/^\/+/, ""); try { return decodeURIComponent(text) } catch (e) { return text } }
    function normalizeHeader(value) { return String(value || "").trim().toLowerCase().replace(/[_-]+/g, " ").replace(/\s+/g, " ") }
    function mapIndex(value) {
        var header = root.normalizeHeader(value)
        var aliases = [["store name","store","name"],["sid","store id","storeid","store code","store_id","id"],["banner","brand"],["nielsen store code","nielsen code","nielsen store","nielsen"],["trip received","trip_received"],["last trip","last_trip"],["address 1","address1","address","addr","street","address line 1"],["address 2","address2","address line 2"],["address 3","address3","address line 3"],["zip","zipcode","zip code","postal code","postcode","pincode","pin code"],["active / inactive","active/inactive","active inactive","status","active"],["is census","census","census flag","is_census"],["is exceptions","is exception","exceptions","exception","is_exceptions"],["updated by","updated_by","modified by","modified_by","last updated by"]]
        for (var i = 0; i < aliases.length; ++i) for (var j = 0; j < aliases[i].length; ++j) if (header === root.normalizeHeader(aliases[i][j])) return i
        return -1
    }
    function mappedCount() { var count = 0; for (var i = 0; i < root.importedHeaders.length; ++i) if (root.mapIndex(root.importedHeaders[i]) >= 0) ++count; return count }
    function loadImported() {
        var nextRows = [], nextSelected = []
        for (var r = 0; r < root.importedRows.length; ++r) {
            var source = root.importedRows[r] || [], target = root.blankRow()
            for (var c = 0; c < root.importedHeaders.length; ++c) { var targetIndex = root.mapIndex(root.importedHeaders[c]); if (targetIndex >= 0) target[targetIndex] = source[c] === undefined || source[c] === null ? "" : String(source[c]).trim() }
            if (root.hasData(target)) { nextRows.push(target); nextSelected.push(true) }
        }
        while (nextRows.length < root.minimumRows) { nextRows.push(root.blankRow()); nextSelected.push(true) }
        root.rows = nextRows; root.selected = nextSelected; root.invalidate(); root.importPreviewVisible = false
    }
    function validationJson() { var output = []; for (var r = 0; r < root.rows.length; ++r) if (root.selected[r] && root.hasData(root.rows[r])) { var record = {}; for (var c = 0; c < root.headers.length; ++c) record[root.headers[c]] = String(root.rows[r][c] || "").trim(); output.push(record) } return JSON.stringify(output) }
    function validateRows() { if (!root.includedCount() || root.validationPending || !root.backendAvailable()) return; root.validationPending = true; root.validated = false; root.findings = []; backend.creator.validate_creator(root.validationJson()) }
    function exportRows() { if (!root.validated || root.findings.length || !root.includedCount() || root.exporting || !root.backendAvailable()) return; var output = []; for (var i = 0; i < root.rows.length; ++i) if (root.selected[i] && root.hasData(root.rows[i])) output.push(root.rows[i]); root.exporting = true; backend.creator.export_builder_file(JSON.stringify(output), root.destinationPath, JSON.stringify(root.headers)) }

    Component.onCompleted: root.resetRows()

    FileDialog {
        id: importDialog
        title: "Import Store Dataset"
        fileMode: FileDialog.OpenFile
        nameFilters: ["Store Data (*.csv *.tsv *.txt *.xlsx *.xls *.xlsm *.json *.xml)", "All Files (*)"]
        onAccepted: {
            root.importPending = true; root.importPreviewVisible = true; root.importError = "Reading file and preparing preview..."; root.importedHeaders = []; root.importedRows = []; root.importedTotal = 0
            if (root.backendAvailable()) backend.creator.load_creator_file(root.urlToPath(selectedFile))
            else { root.importPending = false; root.importError = "Store Builder backend is unavailable." }
        }
    }
    FileDialog {
        id: exportDialog
        title: "Export Store Builder CSV"
        fileMode: FileDialog.SaveFile
        currentFile: "store_builder.csv"
        nameFilters: ["CSV Files (*.csv)", "All Files (*)"]
        onAccepted: { root.destinationPath = root.urlToPath(selectedFile); root.exportRows() }
    }
    Popup {
        id: pastePopup
        parent: Overlay.overlay; modal: true; width: Math.min(root.width - 80, 1000); height: Math.min(root.height - 100, 650); x: Math.round((root.width - width) / 2); y: Math.round((root.height - height) / 2); padding: 0; closePolicy: Popup.CloseOnEscape
        background: Rectangle { color: Theme.surfaceElevated; radius: Theme.radiusXLarge; border.color: Theme.borderStrong }
        ColumnLayout {
            anchors.fill: parent; anchors.margins: Theme.spacingLarge; spacing: Theme.spacingMedium
            RowLayout { Layout.fillWidth: true; Text { text: "Paste Stores"; color: Theme.textPrimary; font.pixelSize: 22; font.bold: true; Layout.fillWidth: true }; AppButton { text: "Close"; onClicked: pastePopup.close() } }
            Text { text: "Paste rows copied from Excel or CSV. The first row is treated as the source header."; color: Theme.textSecondary; Layout.fillWidth: true; wrapMode: Text.WordWrap }
            TextArea { id: pasteArea; Layout.fillWidth: true; Layout.fillHeight: true; placeholderText: "Store Name\tSID\tBanner\tNielsen Store Code\t...\nExample Store\tS001\tBanner\t12345\t..."; selectByMouse: true; wrapMode: TextEdit.NoWrap; color: Theme.textPrimary }
            RowLayout { Layout.fillWidth: true; Text { text: "Excel clipboard data is normally tab-separated."; color: Theme.textMuted; Layout.fillWidth: true }; AppButton { text: "Clear"; onClicked: pasteArea.clear() }; PrimaryButton { text: "Preview Paste"; enabled: pasteArea.text.trim() !== "" && root.backendAvailable(); onClicked: { root.importPending = true; root.importPreviewVisible = true; root.importError = "Parsing pasted stores..."; backend.creator.load_creator_text(pasteArea.text); pastePopup.close() } } }
        }
    }

    Connections {
        target: root.backendAvailable() ? backend : null
        ignoreUnknownSignals: true
        function onCreatorLoaded(payload) {
            root.importPending = false
            try { var data = JSON.parse(String(payload || "{}")); root.importedHeaders = Array.isArray(data.headers) ? data.headers : []; root.importedRows = Array.isArray(data.rows) ? data.rows : []; root.importedTotal = Number(data.total || root.importedRows.length || 0); root.importError = String(data.error || ""); if (!root.importedHeaders.length && !root.importError) root.importError = "No header row was detected." }
            catch (error) { root.importedHeaders = []; root.importedRows = []; root.importedTotal = 0; root.importError = String(error) }
            root.importPreviewVisible = true
        }
        function onCreatorReady(payload) { try { var data = JSON.parse(String(payload || "{}")); root.findings = Array.isArray(data.findings) ? data.findings : [] } catch (error) { root.findings = [{row:0,field:"SYSTEM",message:String(error),severity:"ERROR"}] }; root.validated = true; root.validationPending = false }
        function onBuilderExported() { root.exporting = false; root.destinationPath = "" }
    }

    ScrollView {
        id: pageScroll
        anchors.fill: parent; clip: true; contentWidth: availableWidth; ScrollBar.vertical.policy: ScrollBar.AsNeeded
        ColumnLayout {
            width: pageScroll.availableWidth; spacing: Theme.spacingLarge
            PageTitle { Layout.fillWidth: true; Layout.leftMargin: Theme.spacingXLarge; Layout.rightMargin: Theme.spacingXLarge; Layout.topMargin: Theme.spacingLarge; title: "Store Builder"; subtitle: "Paste, import, edit, validate and export stores in one canonical workspace." }

            Card {
                Layout.fillWidth: true; Layout.leftMargin: Theme.spacingXLarge; Layout.rightMargin: Theme.spacingXLarge; Layout.preferredHeight: 92; hoverable: false
                RowLayout { anchors.fill: parent; anchors.margins: Theme.spacingMedium; spacing: Theme.spacingSmall
                    PrimaryButton { text: "Paste Stores"; onClicked: pastePopup.open() }
                    AppButton { text: root.importPending ? "Importing..." : "Import File"; enabled: !root.importPending; onClicked: importDialog.open() }
                    AppButton { text: "+ Add Row"; onClicked: root.addRow() }
                    AppButton { text: "Select All"; onClicked: root.selectAll(true) }
                    AppButton { text: "Deselect All"; onClicked: root.selectAll(false) }
                    AppButton { text: "Delete Selected"; onClicked: root.deleteSelected() }
                    AppButton { text: "Clear"; onClicked: root.resetRows() }
                    Item { Layout.fillWidth: true }
                    ColumnLayout { spacing: 1; Text { text: root.enteredCount() + " entered"; color: Theme.textPrimary; font.bold: true; Layout.alignment: Qt.AlignRight }; Text { text: root.includedCount() + " included • " + root.headers.length + " columns"; color: Theme.textSecondary; font.pixelSize: 10; Layout.alignment: Qt.AlignRight } }
                    AppButton { text: root.validationPending ? "Validating..." : "Validate"; enabled: root.enteredCount() > 0 && !root.validationPending; onClicked: root.validateRows() }
                    PrimaryButton { text: root.exporting ? "Exporting..." : "Export CSV"; enabled: root.includedCount() > 0 && root.validated && root.findings.length === 0 && !root.validationPending && !root.exporting; onClicked: exportDialog.open() }
                }
            }

            Card {
                visible: root.importPreviewVisible; Layout.fillWidth: true; Layout.leftMargin: Theme.spacingXLarge; Layout.rightMargin: Theme.spacingXLarge; Layout.preferredHeight: 350; hoverable: false
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: Theme.spacingMedium; spacing: Theme.spacingSmall
                    RowLayout { Layout.fillWidth: true; ColumnLayout { Layout.fillWidth: true; Text { text: root.importPending ? "Preparing Source Preview..." : "Source Preview"; color: Theme.textPrimary; font.pixelSize: 16; font.bold: true }; Text { text: root.importPending ? "Reading the selected file." : root.importedTotal + " records • " + root.importedHeaders.length + " source columns • " + root.mappedCount() + " mapped"; color: Theme.textSecondary; font.pixelSize: 11 } }; AppButton { text: "Hide"; onClicked: root.importPreviewVisible = false }; PrimaryButton { text: "Load into Store Builder"; enabled: root.importedHeaders.length > 0 && !root.importPending && root.mappedCount() > 0; onClicked: root.loadImported() } }
                    Rectangle { visible: root.importError !== ""; Layout.fillWidth: true; Layout.preferredHeight: 48; color: root.importPending ? Theme.infoSoft : Theme.errorSoft; border.color: root.importPending ? Theme.info : Theme.error; radius: Theme.radiusMedium; Text { anchors.fill: parent; anchors.margins: 8; text: root.importError; color: Theme.textPrimary; wrapMode: Text.WordWrap; verticalAlignment: Text.AlignVCenter } }
                    Rectangle {
                        visible: root.importError === "" && root.importedHeaders.length > 0; Layout.fillWidth: true; Layout.fillHeight: true; color: Theme.background; border.color: Theme.border; radius: Theme.radiusMedium; clip: true
                        Flickable { id: previewFlickable; anchors.fill: parent; contentWidth: Math.max(width, previewTable.width); contentHeight: previewTable.height; clip: true; boundsBehavior: Flickable.StopAtBounds; ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }; ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
                            Column { id: previewTable; width: Math.max(previewFlickable.width, root.importedHeaders.length * 155); spacing: 0
                                Rectangle { width: previewTable.width; height: 36; color: Theme.surfaceHover; border.color: Theme.borderStrong; Row { anchors.fill: parent; Repeater { model: root.importedHeaders; delegate: Rectangle { id: headerDelegate; required property string modelData; width: 155; height: 36; color: "transparent"; border.color: Theme.border; Text { anchors.fill: parent; anchors.margins: 7; text: headerDelegate.modelData; color: Theme.textPrimary; font.pixelSize: 10; font.bold: true; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter } } } } }
                                Repeater { model: Math.min(root.previewRowCount, root.importedRows.length); delegate: Rectangle { id: sourceRowDelegate; required property var modelData; required property int index; readonly property var previewRow: modelData; width: previewTable.width; height: 30; color: sourceRowDelegate.index % 2 === 0 ? Theme.background : Theme.surface; border.color: Theme.border
                                    Row { anchors.fill: parent; Repeater { model: root.importedHeaders.length; delegate: Rectangle { id: sourceCellDelegate; required property int index; width: 155; height: 30; color: "transparent"; border.color: Theme.border; Text { anchors.fill: parent; anchors.margins: 7; text: sourceCellDelegate.index < sourceRowDelegate.previewRow.length && sourceRowDelegate.previewRow[sourceCellDelegate.index] !== undefined ? String(sourceRowDelegate.previewRow[sourceCellDelegate.index]) : ""; color: Theme.textPrimary; font.pixelSize: 10; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter } } } }
                                } }
                            }
                        }
                    }
                }
            }

            Card {
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 610; Layout.leftMargin: Theme.spacingXLarge; Layout.rightMargin: Theme.spacingXLarge; Layout.bottomMargin: Theme.spacingXLarge; hoverable: false
                Flickable { id: builderFlickable; anchors.fill: parent; anchors.margins: Theme.spacingSmall; contentWidth: Math.max(width, root.tableWidth); contentHeight: builderTable.height; clip: true; boundsBehavior: Flickable.StopAtBounds; ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }; ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
                    Column { id: builderTable; width: Math.max(builderFlickable.width, root.tableWidth); spacing: 0
                        Rectangle { width: builderTable.width; height: 44; color: Theme.surfaceHover; border.color: Theme.borderStrong; Row { anchors.fill: parent; Rectangle { width: root.controlColumnWidth; height: 44; color: Theme.surfaceActive; border.color: Theme.borderStrong; Text { anchors.fill: parent; anchors.margins: 7; text: "USE / ROW"; color: Theme.textPrimary; font.pixelSize: 10; font.bold: true; verticalAlignment: Text.AlignVCenter } }; Repeater { model: root.headers; delegate: Rectangle { id: headerCell; required property string modelData; required property int index; width: root.widths[headerCell.index]; height: 44; color: "transparent"; border.color: Theme.borderStrong; Text { anchors.fill: parent; anchors.margins: 7; text: headerCell.modelData; color: Theme.textPrimary; font.pixelSize: 10; font.bold: true; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter } } } } }
                        Repeater { model: root.rows; delegate: Rectangle { id: rowDelegate; required property var modelData; required property int index; readonly property var rowData: modelData; readonly property int rowIndex: index; width: builderTable.width; height: 42; color: rowDelegate.rowIndex % 2 === 0 ? Theme.background : Theme.surface; border.color: Theme.border
                            Row { anchors.fill: parent
                                Rectangle { width: root.controlColumnWidth; height: 42; color: root.selected[rowDelegate.rowIndex] ? Theme.primarySoft : "transparent"; border.color: Theme.border; RowLayout { anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; Rectangle { Layout.preferredWidth: 20; Layout.preferredHeight: 20; radius: 4; color: root.selected[rowDelegate.rowIndex] ? Theme.primary : "transparent"; border.color: root.selected[rowDelegate.rowIndex] ? Theme.primary : Theme.borderStrong; Text { anchors.centerIn: parent; text: "✓"; visible: root.selected[rowDelegate.rowIndex]; color: Theme.textPrimary; font.bold: true }; MouseArea { anchors.fill: parent; onClicked: root.setSelected(rowDelegate.rowIndex, !root.selected[rowDelegate.rowIndex]) } }; Text { text: String(rowDelegate.rowIndex + 1); color: Theme.textSecondary; font.pixelSize: 11; Layout.fillWidth: true; verticalAlignment: Text.AlignVCenter } } }
                                Repeater { model: root.headers.length; delegate: Rectangle { id: cellDelegate; required property int index; width: root.widths[cellDelegate.index]; height: 42; color: "transparent"; border.color: Theme.border; TextField { id: cellEditor; anchors.fill: parent; anchors.margins: 1; text: cellDelegate.index < rowDelegate.rowData.length && rowDelegate.rowData[cellDelegate.index] !== undefined ? String(rowDelegate.rowData[cellDelegate.index]) : ""; color: Theme.textPrimary; selectByMouse: true; background: Rectangle { color: cellEditor.activeFocus ? Theme.primarySoft : "transparent"; border.color: cellEditor.activeFocus ? Theme.primary : "transparent"; radius: Theme.radiusSmall }; onEditingFinished: root.setCell(rowDelegate.rowIndex, cellDelegate.index, text) } } }
                            }
                        } }
                    }
                }
            }

            Card {
                visible: root.findings.length > 0; Layout.fillWidth: true; Layout.leftMargin: Theme.spacingXLarge; Layout.rightMargin: Theme.spacingXLarge; Layout.bottomMargin: Theme.spacingXLarge; Layout.preferredHeight: Math.min(300, 90 + root.findings.length * 34); hoverable: false
                ColumnLayout { anchors.fill: parent; anchors.margins: Theme.spacingMedium; Text { text: "Validation Findings • " + root.findings.length; color: Theme.error; font.pixelSize: 14; font.bold: true }; ListView { Layout.fillWidth: true; Layout.fillHeight: true; clip: true; model: root.findings; delegate: Text { required property var modelData; width: ListView.view.width; text: "Row " + String(modelData.row) + " • " + String(modelData.field) + ": " + String(modelData.message); color: Theme.textPrimary; font.pixelSize: 11; elide: Text.ElideRight } } }
            }
        }
    }
}
