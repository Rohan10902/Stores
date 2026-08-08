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
        function onNotify(type, message) {
            toastManager.show(message, type);
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // SIDEBAR
        Rectangle {
            id: sidebar
            Layout.preferredWidth: Theme.sidebarWidth
            Layout.fillHeight: true
            color: Theme.surface
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingMedium
                spacing: Theme.spacingSmall

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.headerHeight
                    
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "StoreLens"
                        color: Theme.textPrimary
                        font.pixelSize: 24
                        font.bold: true
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.border
                    Layout.bottomMargin: Theme.spacingMedium
                }

                SidebarButton { text: "Dashboard"; onClicked: stackView.replace(homePage) }
                SidebarButton { text: "Match / Verify"; onClicked: stackView.replace(comparePage) }
                SidebarButton { text: "File Review"; onClicked: stackView.replace(reviewPage) }
                SidebarButton { text: "Record Repair"; onClicked: stackView.replace(repairPage) }
                SidebarButton { text: "Store Builder"; onClicked: stackView.replace(createPage) }
                SidebarButton { text: "Data Intelligence"; onClicked: stackView.replace(healthPage) }
                SidebarButton { text: "Query Studio"; onClicked: stackView.replace(explorePage) }

                Item { Layout.fillHeight: true }
            }
        }

        // DIVIDER
        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            color: Theme.border
        }

        // MAIN CONTENT
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            StackView {
                id: stackView
                anchors.fill: parent
                initialItem: homePage
                
                replaceEnter: Transition {
                    PropertyAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durationMedium }
                }
                replaceExit: Transition {
                    PropertyAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.durationMedium }
                }
            }
        }
    }

    // StackView Components
    Component { 
        id: homePage; 
        HomePage {
            onNavigateRequested: function(pageId) {
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
