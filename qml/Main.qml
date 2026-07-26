import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    visible: true
    width: 1440
    height: 900
    minimumWidth: 1050
    minimumHeight: 680
    title: "Store Data Assistant 7.1.5.1"
    color: "#07111f"

    // One application-wide palette keeps every Qt Quick Control readable on
    // Windows regardless of the user's OS light/dark theme.
    palette.window: "#07111f"
    palette.windowText: "#f8fafc"
    palette.base: "#081321"
    palette.alternateBase: "#0d1b2e"
    palette.text: "#f8fafc"
    palette.button: "#14243a"
    palette.buttonText: "#f8fafc"
    palette.highlight: "#3b82f6"
    palette.highlightedText: "#ffffff"
    palette.placeholderText: "#64748b"
    palette.mid: "#263850"
    palette.dark: "#07111f"
    palette.light: "#334155"

    property int page: 0
    property real uiScale: Math.max(0.9, Math.min(1.18, width / 1440))
    property var pageSources: [
        "pages/HomePage.qml",
        "pages/ComparePage.qml",
        "pages/SingleReviewPage.qml",
        "pages/RepairPage.qml",
        "pages/CreateStorePage.qml",
        "pages/HealthPage.qml",
        "pages/ExplorePage.qml"
    ]
    property var pageNames: [
        "Home",
        "Compare & Validate",
        "Review One File",
        "Repair CSV / Text",
        "Create Store File",
        "Data Health & Statistics",
        "Explore & Analyze"
    ]

    function navigateTo(index) {
        if (index >= 0 && index < pageSources.length)
            page = index
    }

    header: Rectangle {
        height: 58 * root.uiScale
        color: "#081321"
        border.width: 1
        border.color: "#263850"
        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            Rectangle {
                width: 34; height: 34; radius: 8; color: "#3b82f6"
                Text { anchors.centerIn: parent; text: "DA"; color: "white"; font.bold: true }
            }
            Column {
                Text { text: "Store Data Assistant 7.1.5.1"; color: "#f8fafc"; font.pixelSize: 15 * root.uiScale; font.bold: true }
                Text { text: "Local data quality, repair, comparison and analysis"; color: "#94a3b8"; font.pixelSize: 9 * root.uiScale }
            }
            Item { Layout.fillWidth: true }
            Text { text: "● LOCAL ONLY"; color: "#86efac"; font.bold: true }
        }
    }

    footer: Rectangle {
        height: 30
        color: "#081321"
        border.width: 1
        border.color: "#263850"
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            Text { text: backend.message; color: "#94a3b8"; font.pixelSize: 10; Layout.fillWidth: true; elide: Text.ElideRight }
            Text { text: "7.1.5.1"; color: "#94a3b8"; font.pixelSize: 9 }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.preferredWidth: Math.max(210, 220 * root.uiScale)
            Layout.fillHeight: true
            color: "#0b1728"
            border.width: 1
            border.color: "#263850"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                Text { text: "WORKSPACE"; color: "#94a3b8"; font.pixelSize: 9; font.bold: true; Layout.leftMargin: 8 }
                Repeater {
                    model: root.pageNames
                    Button {
                        required property string modelData
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: 42 * root.uiScale
                        text: modelData
                        palette.button: root.page === index ? "#1d4777" : "#0b1728"
                        palette.buttonText: "#f8fafc"
                        onClicked: root.navigateTo(index)
                    }
                }
                Item { Layout.fillHeight: true }
                Text {
                    text: "Source files remain unchanged until you explicitly export."
                    color: "#94a3b8"
                    font.pixelSize: 9
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }

        Loader {
            id: pageLoader
            Layout.fillWidth: true
            Layout.fillHeight: true
            source: root.pageSources[root.page]
            onLoaded: {
                if (item && item.navigate)
                    item.navigate.connect(root.navigateTo)
            }
            onStatusChanged: {
                if (status === Loader.Error)
                    backend.say("This workspace could not be loaded. See the application log for details.")
            }
        }
    }
}