pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Item {
    id: root

    width: previewVisible ? 1180 : 350
    height: previewVisible ? 700 : 60
    visible: previewVisible || toastVisible
    opacity: 1
    z: 5000

    property string message: ""
    property string type: "info"
    property bool toastVisible: false
    property bool previewVisible: false
    property int previewMode: 0
    property var masterColumns: []
    property var masterRows: []
    property int masterTotal: 0
    property var uploadColumns: []
    property var uploadRows: []
    property int uploadTotal: 0
    property string previewError: ""

    function show(msg, msgType) {
        var text = String(msg || "")
        if (text.indexOf("__STORELENS_PREVIEW_MASTER__") === 0) {
            root.openPreview(text.substring("__STORELENS_PREVIEW_MASTER__".length), true)
            return
        }
        if (text.indexOf("__STORELENS_PREVIEW_UPLOAD__") === 0) {
            root.openPreview(text.substring("__STORELENS_PREVIEW_UPLOAD__".length), false)
            return
        }
        root.message = text
        if (msgType)
            root.type = String(msgType).toLowerCase()
        root.toastVisible = true
        showAnim.restart()
        hideTimer.restart()
    }

    function openPreview(payload, isMaster) {
        try {
            var data = JSON.parse(String(payload || "{}"))
            var columns = Array.isArray(data.columns) ? data.columns : []
            var rows = Array.isArray(data.rows) ? data.rows : []
            if (isMaster) {
                root.masterColumns = columns
                root.masterRows = rows
                root.masterTotal = Number(data.total || rows.length || 0)
                root.previewMode = 0
            } else {
                root.uploadColumns = columns
                root.uploadRows = rows
                root.uploadTotal = Number(data.total || rows.length || 0)
                root.previewMode = 1
            }
            root.previewError = columns.length ? "" : "No columns were detected in the selected file."
            root.previewVisible = true
            root.toastVisible = false
        } catch (error) {
            root.previewError = "Unable to display the dataset preview."
            root.previewVisible = true
            root.toastVisible = false
        }
    }

    function activeColumns() { return root.previewMode === 0 ? root.masterColumns : root.uploadColumns }
    function activeRows() { return root.previewMode === 0 ? root.masterRows : root.uploadRows }
    function activeTotal() { return root.previewMode === 0 ? root.masterTotal : root.uploadTotal }
    function cellValue(row, column) {
        if (!Array.isArray(row) || column < 0 || column >= row.length)
            return ""
        var value = row[column]
        return value === undefined || value === null ? "" : String(value)
    }
    function closePreview() { root.previewVisible = false }

    Rectangle {
        visible: root.toastVisible
        anchors.fill: parent
        radius: Theme.radiusMedium
        color: Theme.surface
        border.color: root.type === "success" ? Theme.success : root.type === "error" ? Theme.error : root.type === "warning" ? Theme.warning : Theme.info
        border.width: 2
        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingMedium
            Text { text: root.message; color: Theme.textPrimary; font.pixelSize: 14; Layout.fillWidth: true; wrapMode: Text.WordWrap; verticalAlignment: Text.AlignVCenter }
        }
    }

    Rectangle {
        visible: root.previewVisible
        anchors.fill: parent
        radius: Theme.radiusLarge
        color: Theme.surface
        border.color: Theme.primary
        border.width: 2

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingMedium
            spacing: Theme.spacingMedium

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: root.previewMode === 0 ? "Master Dataset Preview" : "Uploaded Dataset Preview"
                    color: Theme.textPrimary
                    font.pixelSize: 19
                    font.bold: true
                    Layout.fillWidth: true
                }
                Text { text: root.activeTotal().toLocaleString() + " records • " + root.activeColumns().length + " columns • first " + root.activeRows().length + " rows"; color: Theme.textSecondary }
                AppButton { text: "Master"; enabled: root.masterColumns.length > 0; onClicked: root.previewMode = 0 }
                AppButton { text: "Uploaded"; enabled: root.uploadColumns.length > 0; onClicked: root.previewMode = 1 }
                AppButton { text: "Close"; onClicked: root.closePreview() }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Theme.background
                border.color: Theme.border
                radius: Theme.radiusMedium
                clip: true

                Text { visible: root.previewError !== ""; anchors.centerIn: parent; text: root.previewError; color: Theme.error; font.pixelSize: 14 }

                Flickable {
                    visible: root.previewError === ""
                    anchors.fill: parent
                    anchors.margins: 1
                    clip: true
                    contentWidth: Math.max(width, root.activeColumns().length * 170)
                    contentHeight: previewTable.height
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { }
                    ScrollBar.horizontal: ScrollBar { }

                    Column {
                        id: previewTable
                        width: Math.max(parent.width, root.activeColumns().length * 170)
                        spacing: 0

                        Rectangle {
                            width: previewTable.width
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
                                        width: 170
                                        height: 42
                                        color: "transparent"
                                        border.color: Theme.border
                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            text: headerDelegate.modelData
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
                            model: root.activeRows()
                            delegate: Rectangle {
                                id: rowDelegate
                                required property var modelData
                                required property int index
                                width: previewTable.width
                                height: 36
                                color: rowDelegate.index % 2 === 0 ? Theme.background : Theme.surface
                                border.color: Theme.border
                                Row {
                                    anchors.fill: parent
                                    Repeater {
                                        model: root.activeColumns().length
                                        delegate: Rectangle {
                                            id: cellDelegate
                                            required property int index
                                            width: 170
                                            height: 36
                                            color: "transparent"
                                            border.color: Theme.border
                                            Text {
                                                anchors.fill: parent
                                                anchors.leftMargin: 8
                                                anchors.rightMargin: 8
                                                text: root.cellValue(rowDelegate.modelData, cellDelegate.index)
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

    SequentialAnimation {
        id: showAnim
        NumberAnimation { target: root; property: "opacity"; from: 0; to: 1; duration: Theme.durationMedium }
    }
    SequentialAnimation {
        id: hideAnim
        NumberAnimation { target: root; property: "opacity"; from: 1; to: 0; duration: Theme.durationMedium }
        PropertyAction { target: root; property: "toastVisible"; value: false }
    }
    Timer { id: hideTimer; interval: 3500; onTriggered: hideAnim.start() }
}
