import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../theme"

Item {
    id: root
    signal navigateRequested(string pageId)

    ScrollView {
        id: scrollView
        anchors.fill: parent
        clip: true

        ColumnLayout {
            width: scrollView.availableWidth
            spacing: Theme.spacingLarge
            
            PageTitle {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacingXLarge
                Layout.topMargin: Theme.spacingLarge
                title: "Dashboard"
                subtitle: "Select a module to begin data processing."
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.margins: Theme.spacingXLarge
                Layout.topMargin: 0
                Layout.alignment: Qt.AlignTop
                // FIXED: Strictly enforces a 2-column store-lens desktop layout
                columns: 2 
                columnSpacing: Theme.spacingLarge
                rowSpacing: Theme.spacingLarge

                DashboardCard { title: "Compare & Validate"; description: "Master vs Uploaded key-based comparison."; buttonText: "Start Validation"; onClicked: root.navigateRequested("compare") }
                DashboardCard { title: "Review One File"; description: "Analyze one dataset without a Master and review formatting."; buttonText: "Open File Review"; onClicked: root.navigateRequested("review") }
                DashboardCard { title: "Repair CSV / Text"; description: "Inspect broken records and save a reviewed copy."; buttonText: "Launch Repair"; onClicked: root.navigateRequested("repair") }
                DashboardCard { title: "Create Store File"; description: "Paste tabular values into the fixed Store schema and export CSV."; buttonText: "Build Store"; onClicked: root.navigateRequested("create") }
                DashboardCard { title: "Data Health & Statistics"; description: "Quality score and on-demand statistics."; buttonText: "View Intelligence"; onClicked: root.navigateRequested("health") }
                DashboardCard { title: "Explore & Analyze"; description: "Search and read-only SQL with table output."; buttonText: "Open Query Studio"; onClicked: root.navigateRequested("explore") }
            }
            
            Item { Layout.fillHeight: true }
        }
    }
}
