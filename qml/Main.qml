import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "components"
import "pages"
import "theme"

ApplicationWindow {
    id: window
    width: 1280
    height: 720
    minimumWidth: 1024
    minimumHeight: 600
    visible: true
    title: qsTr("StoreLens - Data Quality Studio")
    color: Theme.background

    property string activePageId: "dashboard"

    Toast {
        id: toastManager
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: Theme.spacingLarge
        z: 100
    }

    Connections {
        target: typeof notificationController !== "undefined" ? notificationController : null
        ignoreUnknownSignals: true
        function onNotify(type, message) { toastManager.show(message, type); }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // TOP BAR
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            color: Theme.surface
            border.color: Theme.border
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingLarge
                anchors.rightMargin: Theme.spacingLarge
                spacing: Theme.spacingMedium

                Text { text: "StoreLens"; color: Theme.primary; font.pixelSize: 18; font.bold: true }
                Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 20; color: Theme.border }
                Text { text: "Data Quality Studio"; color: Theme.textSecondary; font.pixelSize: 14 }
                Item { Layout.fillWidth: true }
                Text { text: "v1.2.0-prod"; color: Theme.textSecondary; font.pixelSize: 12 }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // SIDEBAR
            Rectangle {
                Layout.preferredWidth: 240
                Layout.fillHeight: true
                color: Theme.background
                border.color: Theme.border
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMedium
                    anchors.topMargin: Theme.spacingLarge
                    spacing: 4

                    Text {
                        text: "MODULES"
                        color: Theme.textSecondary
                        font.pixelSize: 11
                        font.bold: true
                        Layout.bottomMargin: Theme.spacingSmall
                        Layout.leftMargin: Theme.spacingSmall
                    }

                    SidebarButton { text: "Dashboard"; isActive: window.activePageId === "dashboard"; onClicked: { window.activePageId = "dashboard"; stackView.replace(homePage) } }
                    SidebarButton { text: "Match / Verify"; isActive: window.activePageId === "compare"; onClicked: { window.activePageId = "compare"; stackView.replace(comparePage) } }
                    SidebarButton { text: "File Review"; isActive: window.activePageId === "review"; onClicked: { window.activePageId = "review"; stackView.replace(reviewPage) } }
                    SidebarButton { text: "Record Repair"; isActive: window.activePageId === "repair"; onClicked: { window.activePageId = "repair"; stackView.replace(repairPage) } }
                    SidebarButton { text: "Store Builder"; isActive: window.activePageId === "create"; onClicked: { window.activePageId = "create"; stackView.replace(createPage) } }
                    SidebarButton { text: "Data Intelligence"; isActive: window.activePageId === "health"; onClicked: { window.activePageId = "health"; stackView.replace(healthPage) } }
                    SidebarButton { text: "Query Studio"; isActive: window.activePageId === "explore"; onClicked: { window.activePageId = "explore"; stackView.replace(explorePage) } }

                    Item { Layout.fillHeight: true }
                }
            }

            // MAIN CONTENT
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                
                StackView {
                    id: stackView
                    anchors.fill: parent
                    initialItem: homePage
                    
                    replaceEnter: Transition { PropertyAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durationFast } }
                    replaceExit: Transition { PropertyAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.durationFast } }
                }
            }
        }
    }

    Component { 
        id: homePage; 
        HomePage {
            onNavigateRequested: function(pageId) {
                window.activePageId = pageId;
                if (pageId === "compare") stackView.replace(comparePage)
                else if (pageId === "review") stackView.replace(reviewPage)
                else if (pageId === "repair") stackView.replace(repairPage)
                else if (pageId === "create") stackView.replace(createPage)
                else if (pageId === "health") stackView.replace(healthPage)
                else if (pageId === "explore") stackView.replace(explorePage)
            }
        } 
    }
    
    Component { id: comparePage; ComparePage {} }
    Component { id: reviewPage; SingleReviewPage {} }
    Component { id: repairPage; RepairPage {} }
    Component { id: createPage; CreateStorePage {} }
    Component { id: healthPage; HealthPage {} }
    Component { id: explorePage; ExplorePage {} }
}
