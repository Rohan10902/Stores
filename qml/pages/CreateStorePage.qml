pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"
import "../theme"

Item {
    id: root

    readonly property var headers: [
        "Store Name", "SID", "Banner", "Nielsen Store Code",
        "Trip Received", "Last Trip", "Address 1", "Address 2",
        "Address 3", "ZIP", "Active / Inactive", "Is Census",
        "Is Exceptions", "Updated By"
    ]
    readonly property var widths: [180, 120, 140, 180, 150, 150, 200, 200, 200, 110, 155, 120, 135, 155]
    readonly property int previewRowCount: 50

    property bool importPreviewVisible: false
    property bool importPending: false
    property bool validationPending: false
    property bool exporting: false
    property var importedHeaders: []
    property var importedRows: []
    property int importedTotal: 0
    property string importError: ""
    property var findings: []
    property bool validated: false
    property string destinationPath: ""
    property int modelRevision: 0

    function backendAvailable() {
        return typeof backend !== "undefined" && backend !== null && backend.creator !== undefined && backend.creator !== null
    }
    function urlToPath(value) {
        var text = String(value || "")
        if (text.indexOf("file:///") === 0) text = text.substring(8)
        else if (text.indexOf("file://") === 0) text = text.substring(7)
        if (Qt.platform.os === "windows") text = text.replace(/^\/+/, "")
        try { return decodeURIComponent(text) } catch (error) { return text }
    }
    function normalizeHeader(value) {
        return String(value || "").trim().toLowerCase().replace(/[_-]+/g, " ").replace(/\s+/g, " ")
    }
    function mapIndex(value) {
        var header = root.normalizeHeader(value)
        var aliases = [
            ["store name", "store", "name"], ["sid", "store id", "storeid", "store code", "store_id", "id"],
            ["banner", "brand"], ["nielsen store code", "nielsen code", "nielsen store", "nielsen"],
            ["trip received", "trip_received"], ["last trip", "last_trip"],
            ["address 1", "address1", "address", "addr", "street", "address line 1"],
            ["address 2", "address2", "address line 2"], ["address 3", "address3", "address line 3"],
            ["zip", "zipcode", "zip code", "postal code", "postcode", "pincode", "pin code"],
            ["active / inactive", "active/inactive", "active inactive", "status", "active", "isactive", "is active"],
            ["is census", "census", "census flag", "is_census", "iscensus", "is census"],
            ["is exceptions", "is exception", "exceptions", "exception", "is_exceptions", "isexception", "is exception"],
            ["updated by", "updated_by", "modified by", "modified_by", "last updated by"]
        ]
        for (var i = 0; i < aliases.length; ++i)
            for (var j = 0; j < aliases[i].length; ++j)
                if (header === root.normalizeHeader(aliases[i][j])) return i
        return -1
    }
    function mappedCount() {
        var count = 0
        for (var i = 0; i < root.importedHeaders.length; ++i)
            if (root.mapIndex(root.importedHeaders[i]) >= 0) ++count
        return count
    }
    function resetBuilder() {
        if (!root.backendAvailable()) return
        backend.creator.reset_builder_rows()
        root.findings = []
        root.validated = false
        root.modelRevision++
    }
    function validateRows() {
        if (!root.backendAvailable() || root.validationPending) return
        if (backend.creator.storeModel.selectedRowCount() === 0) return
        root.validationPending = true
        root.validated = false
        root.findings = []
        backend.creator.validate_creator(backend.creator.storeModel.selectedRecordsJson())
    }
    function exportRows() {
        if (!root.backendAvailable() || root.exporting || !root.validated || root.findings.length > 0) return
        if (backend.creator.storeModel.selectedRowCount() === 0) return
        root.exporting = true
        backend.creator.export_builder_file(backend.creator.storeModel.selectedRowsJson(), root.destinationPath, JSON.stringify(root.headers))
    }

    FileDialog {
        id: importDialog
        title: "Import Store Dataset"
        fileMode: FileDialog.OpenFile
        nameFilters: ["Store Data (*.csv *.tsv *.txt *.xlsx *.xls *.xlsm *.json *.xml)", "All Files (*)"]
        onAccepted: {
            root.importPending = true
            root.importPreviewVisible = true
            root.importError = "Reading file and preparing preview..."
            root.importedHeaders = []
            root.importedRows = []
            root.importedTotal = 0
            if (root.backendAvailable()) backend.creator.load_creator_file(root.urlToPath(selectedFile))
        }
    }

    FileDialog {
        id: exportDialog
        title: "Export Store Builder CSV"
        fileMode: FileDialog.SaveFile
        currentFile: "store_builder.csv"
        nameFilters: ["CSV Files (*.csv)", "All Files (*)"]
        onAccepted: {
            root.destinationPath = root.urlToPath(selectedFile)
            root.exportRows()
        }
    }

    Popup {
        id: pastePopup
        parent: Overlay.overlay
        modal: true
        width: Math.min(root.width - 80, 1000)
        height: Math.min(root.height - 100, 650)
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        padding: 0
        closePolicy: Popup.CloseOnEscape
        background: Rectangle { color: Theme.surfaceElevated; radius: Theme.radiusXLarge; border.color: Theme.borderStrong }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingLarge
            spacing: Theme.spacingMedium
            RowLayout {
                Layout.fillWidth: true
                Text { text: "Paste Stores"; color: Theme.textPrimary; font.pixelSize: 22; font.bold: true; Layout.fillWidth: true }
                AppButton { text: "Close"; onClicked: pastePopup.close() }
            }
            Text { text: "Paste rows copied from Excel or CSV. The first row is treated as the source header."; color: Theme.textSecondary; Layout.fillWidth: true; wrapMode: Text.WordWrap }
            TextArea { id: pasteArea; Layout.fillWidth: true; Layout.fillHeight: true; placeholderText: "Store Name\tSID\tBanner\tNielsen Store Code\t..."; selectByMouse: true; wrapMode: TextEdit.NoWrap; color: Theme.textPrimary }
            RowLayout {
                Layout.fillWidth: true
                Text { text: "Large pastes stay in the Python model; only visible cells are rendered."; color: Theme.textMuted; Layout.fillWidth: true }
                AppButton { text: "Clear"; onClicked: pasteArea.clear() }
                PrimaryButton {
                    text: "Preview Paste"
                    enabled: pasteArea.text.trim() !== "" && root.backendAvailable()
                    onClicked: {
                        root.importPending = true
                        root.importPreviewVisible = true
                        root.importError = "Parsing pasted stores..."
                        backend.creator.load_creator_text(pasteArea.text)
                        pastePopup.close()
                    }
                }
            }
        }
    }

    Connections {
        target: root.backendAvailable() ? backend.creator : null
        ignoreUnknownSignals: true
        function onCreatorLoaded(payload) {
            root.importPending = false
            try {
                var data = JSON.parse(String(payload || "{}"))
                root.importedHeaders = Array.isArray(data.headers) ? data.headers : []
                root.importedRows = Array.isArray(data.rows) ? data.rows : []
                root.importedTotal = Number(data.total || 0)
                root.importError = String(data.error || "")
                if (!root.importedHeaders.length && !root.importError) root.importError = "No header row was detected."
            } catch (error) {
                root.importedHeaders = []
                root.importedRows = []
                root.importedTotal = 0
                root.importError = String(error)
            }
            root.importPreviewVisible = true
        }
        function onCreatorReady(payload) {
            root.validationPending = false
            try {
                var data = JSON.parse(String(payload || "{}"))
                root.findings = Array.isArray(data.findings) ? data.findings : []
            } catch (error) {
                root.findings = [{ row: 0, field: "SYSTEM", message: String(error), severity: "ERROR" }]
            }
            root.validated = true
        }
        function onBuilderExported() { root.exporting = false; root.destinationPath = "" }
    }

    Connections {
        target: root.backendAvailable() ? backend.creator.storeModel : null
        ignoreUnknownSignals: true
        function onModelChangedExternally() { root.modelRevision++ }
    }

    ScrollView {
        id: pageScroll
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        ColumnLayout {
            width: pageScroll.availableWidth
            spacing: Theme.spacingLarge
            PageTitle {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacingXLarge
                Layout.rightMargin: Theme.spacingXLarge
                Layout.topMargin: Theme.spacingLarge
                title: "Store Builder"
                subtitle: "Paste, import, edit, validate and export stores in one canonical workspace."
            }
            Card {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacingXLarge
                Layout.rightMargin: Theme.spacingXLarge
                Layout.preferredHeight: 92
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMedium
                    PrimaryButton { text: "Paste Stores"; onClicked: pastePopup.open() }
                    AppButton { text: root.importPending ? "Importing..." : "Import File"; enabled: !root.importPending; onClicked: importDialog.open() }
                    AppButton { text: "Select All"; onClicked: { backend.creator.storeModel.selectAll(true); root.validated = false } }
                    AppButton { text: "Deselect All"; onClicked: { backend.creator.storeModel.selectAll(false); root.validated = false } }
                    AppButton { text: "Clear"; onClicked: root.resetBuilder() }
                    Item { Layout.fillWidth: true }
                    ColumnLayout {
                        spacing: 1
                        Text { text: root.backendAvailable() ? backend.creator.storeModel.nonEmptyRowCount() + " entered" : "0 entered"; color: Theme.textPrimary; font.bold: true; Layout.alignment: Qt.AlignRight }
                        Text { text: root.backendAvailable() ? backend.creator.storeModel.selectedRowCount() + " selected • 14 columns" : "0 selected • 14 columns"; color: Theme.textSecondary; font.pixelSize: 10; Layout.alignment: Qt.AlignRight }
                    }
                    AppButton { text: root.validationPending ? "Validating..." : "Validate"; enabled: !root.validationPending && root.backendAvailable() && backend.creator.storeModel.selectedRowCount() > 0; onClicked: root.validateRows() }
                    PrimaryButton { text: root.exporting ? "Exporting..." : "Export CSV"; enabled: root.validated && root.findings.length === 0 && !root.validationPending && !root.exporting && root.backendAvailable() && backend.creator.storeModel.selectedRowCount() > 0; onClicked: exportDialog.open() }
                }
            }
            Card {
                visible: root.importPreviewVisible
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacingXLarge
                Layout.rightMargin: Theme.spacingXLarge
                Layout.preferredHeight: 390
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMedium
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true
                            Text { text: root.importPending ? "Preparing Source Preview..." : "Source Preview"; color: Theme.textPrimary; font.pixelSize: 16; font.bold: true }
                            Text { text: root.importPending ? "Reading the selected file." : root.importedTotal.toLocaleString() + " records • " + root.importedHeaders.length + " source columns • " + root.mappedCount() + " mapped • showing " + Math.min(root.previewRowCount, root.importedRows.length); color: Theme.textSecondary; font.pixelSize: 11 }
                        }
                        AppButton { text: "Hide"; onClicked: root.importPreviewVisible = false }
                        PrimaryButton { text: "Load into Store Builder"; enabled: root.importedHeaders.length > 0 && !root.importPending && root.mappedCount() > 0; onClicked: { backend.creator.load_imported_into_builder(); root.importPreviewVisible = false; root.validated = false; root.findings = [] } }
                    }
                    Rectangle {
                        visible: root.importError !== ""
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        color: root.importPending ? Theme.infoSoft : Theme.errorSoft
                        border.color: root.importPending ? Theme.info : Theme.error
                        radius: Theme.radiusMedium
                        Text { anchors.fill: parent; anchors.margins: 8; text: root.importError; color: Theme.textPrimary; wrapMode: Text.WordWrap; verticalAlignment: Text.AlignVCenter }
                    }
                    Rectangle {
                        visible: root.importError === "" && root.importedHeaders.length > 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: Theme.background
                        border.color: Theme.border
                        radius: Theme.radiusMedium
                        clip: true
                        ListView {
                            anchors.fill: parent
                            anchors.margins: 1
                            model: root.importedRows
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            delegate: Rectangle {
                                id: previewRow
                                required property var modelData
                                required property int index
                                width: root.importedHeaders.length * 155
                                height: 30
                                color: index % 2 === 0 ? Theme.background : Theme.surface
                                Row {
                                    anchors.fill: parent
                                    Repeater {
                                        model: root.importedHeaders.length
                                        delegate: Rectangle {
                                            id: previewCell
                                            required property int index
                                            width: 155
                                            height: 30
                                            color: "transparent"
                                            border.color: Theme.border
                                            Text { anchors.fill: parent; anchors.margins: 7; text: previewCell.index < previewRow.modelData.length ? String(previewRow.modelData[previewCell.index] || "") : ""; color: Theme.textPrimary; font.pixelSize: 10; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Card {
                id: builderCard
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 620
                Layout.leftMargin: Theme.spacingXLarge
                Layout.rightMargin: Theme.spacingXLarge
                Layout.bottomMargin: Theme.spacingXLarge
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingSmall
                    HorizontalHeaderView {
                        id: tableHeader
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        syncView: storeTable
                        clip: true
                        resizableColumns: false
                        delegate: Rectangle {
                            required property string display
                            implicitWidth: 140
                            implicitHeight: 44
                            color: Theme.surfaceHover
                            border.color: Theme.borderStrong
                            Text { anchors.fill: parent; anchors.margins: 7; text: display; color: Theme.textPrimary; font.pixelSize: 10; font.bold: true; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: Theme.background
                        border.color: Theme.border
                        clip: true
                        TableView {
                            id: storeTable
                            anchors.fill: parent
                            model: root.backendAvailable() ? backend.creator.storeModel : null
                            clip: true
                            reuseItems: true
                            rowSpacing: 1
                            columnSpacing: 1
                            boundsBehavior: Flickable.StopAtBounds
                            columnWidthProvider: function(column) { return column === 0 ? 116 : root.widths[column - 1] }
                            rowHeightProvider: function(row) { return 42 }
                            editTriggers: TableView.DoubleTapped | TableView.EditKeyPressed
                            delegate: Rectangle {
                                id: tableCell
                                required property string value
                                required property bool selected
                                required property int rowNumber
                                required property int row
                                required property int column
                                required property bool editing
                                implicitWidth: column === 0 ? 116 : root.widths[column - 1]
                                implicitHeight: 42
                                color: column === 0 && selected ? Theme.primarySoft : (row % 2 === 0 ? Theme.background : Theme.surface)
                                border.color: Theme.border
                                Text {
                                    visible: !tableCell.editing
                                    anchors.fill: parent
                                    anchors.margins: 7
                                    text: tableCell.column === 0 ? (tableCell.selected ? "✓  " : "○  ") + String(tableCell.rowNumber) : tableCell.value
                                    color: Theme.textPrimary
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: tableCell.column === 0
                                    onClicked: backend.creator.storeModel.setRowSelected(tableCell.row, !tableCell.selected)
                                }
                                TableView.editDelegate: TextField {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    visible: tableCell.column > 0
                                    text: tableCell.value
                                    color: Theme.textPrimary
                                    selectByMouse: true
                                    background: Rectangle { color: Theme.primarySoft; border.color: Theme.primary; radius: Theme.radiusSmall }
                                    Component.onCompleted: selectAll()
                                    TableView.onCommit: backend.creator.storeModel.setCell(tableCell.row, tableCell.column - 1, text)
                                }
                            }
                        }
                    }
                }
            }
            Card {
                visible: root.findings.length > 0
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacingXLarge
                Layout.rightMargin: Theme.spacingXLarge
                Layout.bottomMargin: Theme.spacingXLarge
                Layout.preferredHeight: Math.min(300, 90 + root.findings.length * 34)
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMedium
                    Text { text: "Validation Findings • " + root.findings.length; color: Theme.error; font.pixelSize: 14; font.bold: true }
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: root.findings
                        delegate: Text {
                            required property var modelData
                            width: ListView.view.width
                            text: "Row " + String(modelData.row) + " • " + String(modelData.field) + ": " + String(modelData.message)
                            color: Theme.textPrimary
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}