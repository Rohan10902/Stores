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

    readonly property var pageNames: [
        "Dashboard",
        "Compare & Validate",
        "Record Repair",
        "Single File Review",
        "Store Builder",
        "Explore / Data",
        "Health"
    ]

    readonly property var pageIds: [
        "home",
        "compare",
        "repair",
        "review",
        "create",
        "explore",
        "health"
    ]

    property var masterPreviewColumns: []
    property var masterPreviewRows: []
    property int masterPreviewTotal: 0
    property var uploadPreviewColumns: []
    property var uploadPreviewRows: []
    property int uploadPreviewTotal: 0
    property int previewMode: 0
    property bool previewVisible: false

    function navigateTo(pageId) {
        var index = pageIds.indexOf(pageId)
        if (index >= 0) currentPage = index
    }

    function navigateToIndex(index) {
        if (index >= 0 && index < pageIds.length) currentPage = index
    }

    function parsePreview(payload, isMaster) {
        try {
            var data = JSON.parse(payload || "{}")
            var columns = Array.isArray(data.columns) ? data.columns : []
            var rows = Array.isArray(data.rows) ? data.rows : []

            if (isMaster) {
                masterPreviewColumns = columns
                masterPreviewRows = rows
                masterPreviewTotal = Number(data.total || 0)
                previewMode = 0
            } else {
                uploadPreviewColumns = columns
                uploadPreviewRows = rows
                uploadPreviewTotal = Number(data.total || 0)
                previewMode = 1
            }

            if (columns.length > 0) {
                previewVisible = true
                previewDialog.open()
            }
        } catch (error) {
            previewVisible = false
        }
    }

    function previewColumns() {
        return previewMode === 0 ? masterPreviewColumns : uploadPreviewColumns
    }

    function previewRows() {
        return previewMode === 0 ? masterPreviewRows : uploadPreviewRows
    }

    function previewTotal() {
        return previewMode === 0 ? masterPreviewTotal : uploadPreviewTotal
    }

    function previewCell(row, columnIndex) {
        if (!Array.isArray(row) || columnIndex < 0 || columnIndex >= row.length)
            return ""
        var value = row[columnIndex]
        return value === null || value === undefined ? "" : String(value)
    }

    function closePreview() {
        previewVisible = false
        previewDialog.close()
    }

    Component.onCompleted: currentPage = 0

    Connections {
        target: typeof backend !== "undefined" ? backend : null
        ignoreUnknownSignals: true

        function onNotifySignal(title, message, level) {
            var prefix = String(title || "").trim()
            var body = String(message || "").trim()
            if (prefix !== "" && body !== "") toast.show(prefix + ": " + body, level)
            else if (body !== "") toast.show(body, level)
            else if (prefix !== "") toast.show(prefix, level)
        }

        function onSaySignal(message) {
            var text = String(message || "").trim()
            if (text !== "") toast.show(text, "info")
        }
    }

    Connections {
        target: typeof backend !== "undefined" && backend.validate !== undefined ? backend.validate : null
        ignoreUnknownSignals: true

        function onMasterPreviewReady(payload) {
            root.parsePreview(payload, true)
        }

        function onUploadPreviewReady(payload) {
            root.parsePreview(payload, false)
        }
    }

    Popup {
        id: previewDialog
        parent: Overlay.overlay
        modal: true
        focus: true
        visible: root.previewVisible
        width: Math.min(root.width - 120, 1250)
        height: Math.min(root.height - 120, 690)
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        onClosed: root.previewVisible = false

        background: Rectangle {
            color: Theme.surface
            radius: Theme.radiusLarge
            border.color: Theme.primary
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: Theme.spacingMedium

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                color: Theme.surfaceHover
                radius: Theme.radiusLarge

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingLarge
                    anchors.rightMargin: Theme.spacingMedium
                    spacing: Theme.spacingMedium

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: root.previewMode === 0 ? "Master Dataset Preview" : "Uploaded Dataset Preview"
                            color: Theme.textPrimary
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Text {
                            text: root.previewTotal().toLocaleString() + " records  •  " + root.previewColumns().length + " columns  •  first " + root.previewRows().length + " rows shown"
                            color: Theme.textSecondary
                            font.pixelSize: 11
                        }
                    }

                    ComboBox {
                        Layout.preferredWidth: 190
                        model: ["Master Dataset", "Uploaded Dataset"]
                        currentIndex: root.previewMode
                        onActivated: root.previewMode = currentIndex
                    }

                    AppButton {
                        text: "Close"
                        onClicked: root.closePreview()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: Theme.spacingMedium
                Layout.rightMargin: Theme.spacingMedium
                Layout.bottomMargin: Theme.spacingMedium
                color: Theme.background
                border.color: Theme.border
                radius: Theme.radiusMedium
                clip: true

                Flickable {
                    id: previewFlickable
                    anchors.fill: parent
                    anchors.margins: 1
                    clip: true
                    contentWidth: Math.max(width, root.previewColumns().length * 170)
                    contentHeight: previewColumn.height
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {}
                    ScrollBar.horizontal: ScrollBar {}

                    Column {
                        id: previewColumn
                        width: Math.max(previewFlickable.width, root.previewColumns().length * 170)
                        spacing: 0

                        Rectangle {
                            width: previewColumn.width
                            height: 40
                            color: Theme.surfaceHover
                            border.color: Theme.border

                            Row {
                                anchors.fill: parent
                                Repeater {
                                    model: root.previewColumns()
                                    delegate: Rectangle {
                                        required property string modelData
                                        width: 170
                                        height: 40
                                        color: "transparent"
                                        border.color: Theme.border

                                        Text {
                                            anchors.fill: parent
                                            anchors.leftMargin: Theme.spacingSmall
                                            anchors.rightMargin: Theme.spacingSmall
                                            text: modelData
                                            color: Theme.textPrimary
                                            font.bold: true
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }
                            }
                        }

                        Repeater {
                            model: root.previewRows()
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                width: previewColumn.width
                                height: 36
                                color: index % 2 === 0 ? Theme.background : Theme.surface
                                border.color: Theme.border

                                Row {
                                    anchors.fill: parent
                                    Repeater {
                                        model: root.previewColumns().length
                                        delegate: Rectangle {
                                            required property int index
                                            width: 170
                                            height: 36
                                            color: "transparent"
                                            border.color: Theme.border

                                            Text {
                                                anchors.fill: parent
                                                anchors.leftMargin: Theme.spacingSmall
                                                anchors.rightMargin: Theme.spacingSmall
                                                text: root.previewCell(parent.parent.parent.modelData, index)
                                                color: Theme.textPrimary
                                                font.pixelSize: 11
                                                elide: Text.ElideRight
                                                verticalAlignment: Text.AlignVCenter
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
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            id: sidebar
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

                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }
                Text { text: "WORKSPACE"; color: Theme.textMuted; font.pixelSize: 10; font.bold: true; Layout.leftMargin: Theme.spacingSmall; Layout.topMargin: Theme.spacingSmall }

                SidebarButton { text: "Dashboard"; isActive: root.currentPage === 0; onClicked: root.navigateToIndex(0) }
                SidebarButton { text: "Compare & Validate"; isActive: root.currentPage === 1; onClicked: root.navigateToIndex(1) }
                SidebarButton { text: "Record Repair"; isActive: root.currentPage === 2; onClicked: root.navigateToIndex(2) }
                SidebarButton { text: "Single File Review"; isActive: root.currentPage === 3; onClicked: root.navigateToIndex(3) }
                SidebarButton { text: "Store Builder"; isActive: root.currentPage === 4; onClicked: root.navigateToIndex(4) }
                SidebarButton { text: "Explore / Data"; isActive: root.currentPage === 5; onClicked: root.navigateToIndex(5) }
                SidebarButton { text: "Health"; isActive: root.currentPage === 6; onClicked: root.navigateToIndex(6) }

                Item { Layout.fillHeight: true }
                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

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
                        spacing: Theme.spacingMedium
                        Text { text: root.pageNames[root.currentPage]; color: Theme.textPrimary; font.pixelSize: 17; font.bold: true }
                        Item { Layout.fillWidth: true }
                        Rectangle { width: 8; height: 8; radius: 4; color: Theme.success }
                        Text { text: "Ready"; color: Theme.textSecondary; font.pixelSize: 11 }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

                StackLayout {
                    id: pageStack
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: root.currentPage

                    Loader { active: root.currentPage === 0; source: "pages/HomePage.qml"; Layout.fillWidth: true; Layout.fillHeight: true; onLoaded: { if (item && item.navigateRequested) item.navigateRequested.connect(root.navigateTo) } }
                    Loader { active: root.currentPage === 1; source: "pages/ComparePage.qml"; Layout.fillWidth: true; Layout.fillHeight: true }
                    Loader { active: root.currentPage === 2; source: "pages/RepairPage.qml"; Layout.fillWidth: true; Layout.fillHeight: true }
                    Loader { active: root.currentPage === 3; source: "pages/SingleReviewPage.qml"; Layout.fillWidth: true; Layout.fillHeight: true }
                    Loader { active: root.currentPage === 4; source: "pages/CreateStorePage.qml"; Layout.fillWidth: true; Layout.fillHeight: true }
                    Loader { active: root.currentPage === 5; source: "pages/ExplorePage.qml"; Layout.fillWidth: true; Layout.fillHeight: true }
                    Loader { active: root.currentPage === 6; source: "pages/HealthPage.qml"; Layout.fillWidth: true; Layout.fillHeight: true }
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
