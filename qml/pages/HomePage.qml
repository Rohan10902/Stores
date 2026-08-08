import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../theme"

Item {
    id: root
    
    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: Theme.spacingLarge
            
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                
                PageTitle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingXLarge
                    title: "Dashboard"
                    subtitle: "Select a module to begin data processing."
                }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.margins: Theme.spacingXLarge
                Layout.topMargin: 0
                columns: root.width > 1200 ? 3 : (root.width > 800 ? 2 : 1)
                columnSpacing: Theme.spacingLarge
                rowSpacing: Theme.spacingLarge

                DashboardCard {
                    title: "Compare & Validate"
                    description: "Master vs Uploaded key-based comparison."
                    buttonText: "Start Validation"
                    onClicked: stackView.replace(comparePage)
                }

                DashboardCard {
                    title: "Review One File"
                    description: "Analyze one dataset without a Master and review Nielsen code formatting."
                    buttonText: "Open File Review"
                    onClicked: stackView.replace(reviewPage)
                }

                DashboardCard {
                    title: "Repair CSV / Text"
                    description: "Inspect broken records and save a reviewed copy."
                    buttonText: "Launch Repair"
                    onClicked: stackView.replace(repairPage)
                }

                DashboardCard {
                    title: "Create Store File"
                    description: "Paste tabular values into the fixed Store schema and export CSV."
                    buttonText: "Build Store"
                    onClicked: stackView.replace(createPage)
                }

                DashboardCard {
                    title: "Data Health & Statistics"
                    description: "Quality score and on-demand statistics."
                    buttonText: "View Intelligence"
                    onClicked: stackView.replace(healthPage)
                }

                DashboardCard {
                    title: "Explore & Analyze"
                    description: "Search and read-only SQL with table output."
                    buttonText: "Open Query Studio"
                    onClicked: stackView.replace(explorePage)
                }
            }
            
            Item { Layout.fillHeight: true } // Bottom Spacer
        }
    }

    // Inline Component for Dashboard Cards to maintain consistency
    component DashboardCard: Card {
        property string title: ""
        property string description: ""
        property string buttonText: ""
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredHeight: 180
        Layout.minimumWidth: 300

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingLarge
            spacing: Theme.spacingMedium

            Text {
                text: parent.parent.title
                color: Theme.textPrimary
                font.pixelSize: 18
                font.bold: true
                Layout.fillWidth: true
            }

            Text {
                text: parent.parent.description
                color: Theme.textSecondary
                font.pixelSize: 14
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                Layout.fillHeight: true
                verticalAlignment: Text.AlignTop
            }

            PrimaryButton {
                text: parent.parent.buttonText
                Layout.alignment: Qt.AlignRight
                onClicked: parent.parent.clicked()
            }
        }
    }
}
