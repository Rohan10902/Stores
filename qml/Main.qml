import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"
import "theme"

ApplicationWindow {
    id: window
    width: 1280
    height: 800
    visible: true
    title: "StoreLens"
    color: Theme.background

    Connections {
        target: typeof backend !== "undefined" ? backend : null
        ignoreUnknownSignals: true

        function onNotifySignal(title, message, level) {
            if (typeof toast !== "undefined") {
                toast.show(title, message, level)
            }
        }

        function onSaySignal(message) {
            if (typeof toast !== "undefined") {
                toast.show("Message", message, "info")
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Modern Sidebar Navigation
        Rectangle {
            Layout.preferredWidth: 260
            Layout.fillHeight: true
            color: Theme.surface
            border.color: Theme.border
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingLarge
                spacing: Theme.spacingMedium

                Text {
                    text: "StoreLens"
                    color: Theme.primary
                    font.pixelSize: 24
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: Theme.spacingLarge
                }

                SidebarButton { text: "Compare & Validate"; onClicked: pageLoader.source = "pages/ComparePage.qml"; Layout.fillWidth: true }
                SidebarButton { text: "Record Repair"; onClicked: pageLoader.source = "pages/RepairPage.qml"; Layout.fillWidth: true }
                SidebarButton { text: "Single File Review"; onClicked: pageLoader.source = "pages/SingleReviewPage.qml"; Layout.fillWidth: true }
                SidebarButton { text: "Create Store"; onClicked: pageLoader.source = "pages/CreateStorePage.qml"; Layout.fillWidth: true }
                SidebarButton { text: "Explore Data"; onClicked: pageLoader.source = "pages/ExplorePage.qml"; Layout.fillWidth: true }
                SidebarButton { text: "Health & Stats"; onClicked: pageLoader.source = "pages/HealthPage.qml"; Layout.fillWidth: true }

                Item { Layout.fillHeight: true } 
            }
        }

        // Main Content Area
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.background

            Loader {
                id: pageLoader
                anchors.fill: parent
                source: "pages/ComparePage.qml"
            }
        }
    }

    Toast {
        id: toast
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: Theme.spacingLarge
    }
}
