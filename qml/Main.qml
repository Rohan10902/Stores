pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "./components"
import "./theme"

ApplicationWindow {
    id: root

    visible: true
    width: 1500
    height: 920
    minimumWidth: 1150
    minimumHeight: 700
    title: "StoreLens"
    color: Theme.background

    property int currentPage: 0
    property var masterPreviewColumns: []
    property var masterPreviewRows: []
    property int masterPreviewTotal: 0
    property var uploadPreviewColumns: []
    property var uploadPreviewRows: []
    property int uploadPreviewTotal: 0
    property int previewMode: 0
    property bool previewVisible: false
    property string previewError: ""

    readonly property var pageNames: [
        "Dashboard", "Compare & Validate", "Record Repair", "Single File Review",
        "Store Builder", "Explore / Data", "Health"
    ]
    readonly property var pageIds: [
        "home", "compare", "repair", "review", "create", "explore", "health"
    ]
    readonly property int previewColumnWidth: 180
    readonly property int previewRowHeight: 38

    function navigateTo(pageId) {
        var index = root.pageIds.indexOf(pageId)
        if (index >= 0)
            root.currentPage = index
    }
    function navigateToIndex(index) {
        if (index >= 0 && index < root.pageIds.length)
            root.currentPage = index
    }
    function pageItem(index) {
        var loaders = [homeLoader, compareLoader, repairLoader, reviewLoader, createLoader, exploreLoader, healthLoader]
        return index >= 0 && index < loaders.length ? loaders[index].item : null
    }
    function pageLoaded(index) {
        return root.pageItem(index) !== null
    }
    function parsePreview(payload, isMaster) {
        try {
            var data = JSON.parse(String(payload || "{}"))
            var columns = Array.isArray(data.columns) ? data.columns : []
            var rows = Array.isArray(data.rows) ? data.rows : []
            var total = Number(data.total || rows.length || 0)
            if (isMaster) {
                root.masterPreviewColumns = columns
                root.masterPreviewRows = rows
                root.masterPreviewTotal = total
                root.previewMode = 0
            } else {
                root.uploadPreviewColumns = columns
                root.uploadPreviewRows = rows
                root.uploadPreviewTotal = total
                root.previewMode = 1
            }
            root.previewError = columns.length === 0 ? "No columns were detected in this file." : rows.length === 0 ? "The file loaded successfully, but it contains no data rows to preview." : ""
            root.previewVisible = true
        } catch (error) {
            root.previewError = "Unable to display the dataset preview."
            root.previewVisible = true
        }
    }
    function activeColumns() { return root.previewMode === 0 ? root.masterPreviewColumns : root.uploadPreviewColumns }
    function activeRows() { return root.previewMode === 0 ? root.masterPreviewRows : root.uploadPreviewRows }
    function activeTotal() { return root.previewMode === 0 ? root.masterPreviewTotal : root.uploadPreviewTotal }
    function activeLabel() { return root.previewMode === 0 ? "Master Dataset" : "Uploaded Dataset" }
    function cellValue(row, index) {
        if (!Array.isArray(row) || index < 0 || index >= row.length)
            return ""
        var value = row[index]
        return value === null || value === undefined ? "" : String(value)
    }
    function closePreview() {
        root.previewVisible = false
        root.previewError = ""
    }

    Connections {
        target: typeof backend !== "undefined" ? backend : null
        ignoreUnknownSignals: true
        function onNotifySignal(title, message, level) {
            var prefix = String(title || "").trim()
            var body = String(message || "").trim()
            if (prefix && body)
                toast.show(prefix + ": " + body, level)
            else if (body)
                toast.show(body, level)
            else if (prefix)
                toast.show(prefix, level)
        }
        function onSaySignal(message) {
            var text = String(message || "").trim()
            if (text)
                toast.show(text, "info")
        }
    }

    Connections {
        target: typeof backend !== "undefined" && backend.validate !== undefined ? backend.validate : null
        ignoreUnknownSignals: true
        function onMasterPreviewReady(payload) { root.parsePreview(payload, true) }
        function onUploadPreviewReady(payload) { root.parsePreview(payload, false) }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: Theme.sidebarWidth
            color: Theme.surface
            border.color: Theme.border
            border.width: 1
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingMedium
                spacing: Theme.spacingMedium
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 72
                    Column {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        Text { text: "StoreLens"; color: Theme.textPrimary; font.pixelSize: 22; font.bold: true }
                        Text { text: "Data Intelligence"; color: Theme.textSecondary; font.pixelSize: 11 }
                    }
                }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.border }
                Text { text: "WORKSPACE"; color: Theme.textMuted; font.pixelSize: 10; font.bold: true; Layout.leftMargin: Theme.spacingSmall }
                SidebarButton { text: "Dashboard"; isActive: root.currentPage === 0; onClicked: root.navigateToIndex(0) }
                SidebarButton { text: "Compare & Validate"; isActive: root.currentPage === 1; onClicked: root.navigateToIndex(1) }
                SidebarButton { text: "Record Repair"; isActive: root.currentPage === 2; onClicked: root.navigateToIndex(2) }
                SidebarButton { text: "Single File Review"; isActive: root.currentPage === 3; onClicked: root.navigateToIndex(3) }
                SidebarButton { text: "Store Builder"; isActive: root.currentPage === 4; onClicked: root.navigateToIndex(4) }
                SidebarButton { text: "Explore / Data"; isActive: root.currentPage === 5; onClicked: root.navigateToIndex(5) }
                SidebarButton { text: "Health"; isActive: root.currentPage === 6; onClicked: root.navigateToIndex(6) }
                Item { Layout.fillHeight: true }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.border }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    Text { text: "StoreLens"; color: Theme.textSecondary; font.pixelSize: 11 }
                    Text { text: "Data processing workspace"; color: Theme.textMuted; font.pixelSize: 10 }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.background
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.headerHeight
                    color: Theme.background
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingLarge
                        anchors.rightMargin: Theme.spacingLarge
                        Text { text: root.pageNames[root.currentPage]; color: Theme.textPrimary; font.pixelSize: 17; font.bold: true }
                        Item { Layout.fillWidth: true }
                        Rectangle { Layout.preferredWidth: 8; Layout.preferredHeight: 8; radius: 4; color: Theme.success }
                        Text { text: "Ready"; color: Theme.textSecondary; font.pixelSize: 11 }
                    }
                }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.border }
                StackLayout {
                    id: pageStack
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: root.currentPage
                    Loader {
                        id: homeLoader
                        active: root.currentPage === 0
                        source: "pages/HomePage.qml"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }
                    Loader { id: compareLoader; active: root.currentPage === 1; source: "pages/ComparePage.qml"; Layout.fillWidth: true; Layout.fillHeight: true }
                    Loader { id: repairLoader; active: root.currentPage === 2; source: "pages/RepairPage.qml"; Layout.fillWidth: true; Layout.fillHeight: true }
                    Loader { id: reviewLoader; active: root.currentPage === 3; source: "pages/SingleReviewPage.qml"; Layout.fillWidth: true; Layout.fillHeight: true }
                    Loader { id: createLoader; active: root.currentPage === 4; source: "pages/CreateStorePage.qml"; Layout.fillWidth: true; Layout.fillHeight: true }
                    Loader { id: exploreLoader; active: root.currentPage === 5; source: "pages/ExplorePage.qml"; Layout.fillWidth: true; Layout.fillHeight: true }
                    Loader { id: healthLoader; active: root.currentPage === 6; source: "pages/HealthPage.qml"; Layout.fillWidth: true; Layout.fillHeight: true }
                }
            }
        }
    }

    Connections {
        target: homeLoader.item
        ignoreUnknownSignals: true
        function onNavigateRequested(pageId) {
            root.navigateTo(String(pageId || ""))
        }
    }

    Rectangle {
        id: previewOverlay
        visible: root.previewVisible
        z: 900
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 1450)
        height: Math.min(parent.height - 40, 820)
        radius: Theme.radiusLarge
        color: Theme.surface
        border.color: Theme.primary
        border.width: 2
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingMedium
            spacing: Theme.spacingSmall
            RowLayout {
                Layout.fillWidth: true
                Text { text: root.activeLabel() + " Preview"; color: Theme.textPrimary; font.pixelSize: 20; font.bold: true; Layout.fillWidth: true }
                Text { text: root.activeTotal().toLocaleString() + " records • " + root.activeColumns().length + " columns • showing " + root.activeRows().length + " rows"; color: Theme.textSecondary }
                AppButton { text: "Master"; enabled: root.masterPreviewColumns.length > 0; onClicked: { root.previewMode = 0; root.previewError = root.masterPreviewRows.length ? "" : "Master loaded with no data rows." } }
                AppButton { text: "Uploaded"; enabled: root.uploadPreviewColumns.length > 0; onClicked: { root.previewMode = 1; root.previewError = root.uploadPreviewRows.length ? "" : "Uploaded file has no data rows." } }
                AppButton { text: "Close"; onClicked: root.closePreview() }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Theme.background
                border.color: Theme.border
                radius: Theme.radiusMedium
                clip: true
                Text { anchors.centerIn: parent; visible: root.previewError !== ""; text: root.previewError; color: Theme.error; font.pixelSize: 13 }
                Flickable {
                    id: rowsFlick
                    anchors.fill: parent
                    visible: root.previewError === "" && root.activeColumns().length > 0
                    clip: true
                    contentWidth: Math.max(width, root.activeColumns().length * root.previewColumnWidth)
                    contentHeight: previewRows.height
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
                    Column {
                        id: previewRows
                        width: Math.max(rowsFlick.width, root.activeColumns().length * root.previewColumnWidth)
                        Rectangle {
                            width: previewRows.width
                            height: 42
                            color: Theme.surfaceHover
                            border.color: Theme.border
                            Row {
                                anchors.fill: parent
                                Repeater {
                                    model: root.activeColumns()
                                    delegate: Rectangle {
                                        id: headerDelegate
                                        required property string modelData
                                        width: root.previewColumnWidth
                                        height: 42
                                        color: "transparent"
                                        border.color: Theme.border
                                        Text { anchors.fill: parent; anchors.margins: 8; text: headerDelegate.modelData; color: Theme.textPrimary; font.bold: true; font.pixelSize: 11; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter }
                                    }
                                }
                            }
                        }
                        Repeater {
                            model: root.activeRows()
                            delegate: Rectangle {
                                id: rowDelegate
                                required property var modelData
                                required property int index
                                width: previewRows.width
                                height: root.previewRowHeight
                                color: rowDelegate.index % 2 === 0 ? Theme.background : Theme.surface
                                border.color: Theme.border
                                Row {
                                    anchors.fill: parent
                                    Repeater {
                                        model: root.activeColumns().length
                                        delegate: Rectangle {
                                            id: cellDelegate
                                            required property int index
                                            width: root.previewColumnWidth
                                            height: root.previewRowHeight
                                            color: "transparent"
                                            border.color: Theme.border
                                            Text { anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; text: root.cellValue(rowDelegate.modelData, cellDelegate.index); color: Theme.textPrimary; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
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

    Toast {
        id: toast
        z: 1000
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: Theme.spacingLarge
        anchors.bottomMargin: Theme.spacingLarge
    }
}
