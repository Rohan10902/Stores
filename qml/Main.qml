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

    // Centralized Toast Notification System
    Toast {
        id: toastManager
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: Theme.spacingLarge
        z: 100
    }

    // Connect Python backend signals to Toast
    Connections {
        target: notificationController // Assuming this is your Python backend controller for notifications
        ignoreUnknownSignals: true
        function onNotify(type, message) {
            toastManager.show(message, type);
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ---------------------------------------------------
        // SIDEBAR NAVIGATION
        // ---------------------------------------------------
        Rectangle {
            id: sidebar
            Layout.preferredWidth: Theme.sidebarWidth
            Layout.fillHeight: true
            color: Theme.surface
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingMedium
                spacing: Theme.spacingSmall

                // Logo/Header Area
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

                // Navigation Links
                SidebarButton { text: "Dashboard"; iconSource: "qrc:/icons/home.png"; onClicked: stackView.replace(homePage) }
                SidebarButton { text: "Match / Verify"; iconSource: "qrc:/icons/compare.png"; onClicked: stackView.replace(comparePage) }
                SidebarButton { text: "File Review"; iconSource: "qrc:/icons/review.png"; onClicked: stackView.replace(reviewPage) }
                SidebarButton { text: "Record Repair"; iconSource: "qrc:/icons/repair.png"; onClicked: stackView.replace(repairPage) }
                SidebarButton { text: "Store Builder"; iconSource: "qrc:/icons/build.png"; onClicked: stackView.replace(createPage) }
                SidebarButton { text: "Data Intelligence"; iconSource: "qrc:/icons/health.png"; onClicked: stackView.replace(healthPage) }
                SidebarButton { text: "Query Studio"; iconSource: "qrc:/icons/explore.png"; onClicked: stackView.replace(explorePage) }

                Item { Layout.fillHeight: true } // Spacer
            }
        }

        // Vertical Divider
        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            color: Theme.border
        }

        // ---------------------------------------------------
        // MAIN CONTENT AREA
        // ---------------------------------------------------
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            StackView {
                id: stackView
                anchors.fill: parent
                initialItem: homePage
                
                // Restrained transitions
                replaceEnter: Transition {
                    PropertyAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durationMedium }
                }
                replaceExit: Transition {
                    PropertyAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.durationMedium }
                }
            }
        }
    }

    // Page Instances (Lazy loaded or instantiated for the stack view)
    Component { id: homePage; HomePage {} }
    Component { id: comparePage; ComparePage {} }
    Component { id: reviewPage; SingleReviewPage {} }
    Component { id: repairPage; RepairPage {} }
    Component { id: createPage; CreateStorePage {} }
    Component { id: healthPage; HealthPage {} }
    Component { id: explorePage; ExplorePage {} }

    // Reusable Sidebar Button Component inside Main
    component SidebarButton: Rectangle {
        property string text: ""
        property string iconSource: ""
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredHeight: 44
        radius: Theme.radiusMedium
        color: mouseArea.containsMouse ? Theme.surfaceHover : "transparent"

        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacingMedium
            spacing: Theme.spacingMedium

            Text {
                text: parent.parent.text
                color: Theme.textPrimary
                font.pixelSize: 15
                Layout.fillWidth: true
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: parent.clicked()
        }
    }
}
