import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "pages"

Window {
    id: window
    width: 1280
    height: 768
    visible: true
    title: "StoreLens 7.2.1"
    color: "#0b1829"

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Sidebar Navigation
        Rectangle {
            id: sidebar
            Layout.preferredWidth: 240
            Layout.fillHeight: true
            color: "#0f172a"
            border.color: "#1e293b"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // App Branding Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Rectangle {
                        width: 32; height: 32; radius: 6
                        color: "#2563eb"
                        Text { anchors.centerIn: parent; text: "SL"; color: "#ffffff"; font.bold: true }
                    }
                    Column {
                        Text { text: "StoreLens 7.2.1"; color: "#f8fafc"; font.bold: true; font.pixelSize: 14 }
                        Text { text: "Local data quality & repair"; color: "#64748b"; font.pixelSize: 10 }
                    }
                }

                Item { implicitHeight: 10 }

                Text {
                    text: "WORKSPACE"
                    color: "#64748b"
                    font.pixelSize: 10
                    font.bold: true
                }

                // Workspace Navigation Repeater
                Repeater {
                    model: [
                        { name: "Compare & Validate", index: 0 },
                        { name: "Review One File", index: 1 },
                        { name: "Record Repair", index: 2 },
                        { name: "Store Builder", index: 3 },
                        { name: "Data Intelligence", index: 4 },
                        { name: "Explore & Analyze", index: 5 }
                    ]

                    delegate: Button {
                        id: navBtn
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 40

                        background: Rectangle {
                            color: stackView.currentIndex === modelData.index ? "#1e3a8a" : (navBtn.hovered ? "#1e293b" : "transparent")
                            radius: 6
                        }

                        contentItem: Text {
                            text: modelData.name
                            color: "#f8fafc"
                            font.pixelSize: 13
                            font.bold: stackView.currentIndex === modelData.index
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 12
                        }

                        onClicked: {
                            stackView.currentIndex = modelData.index
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Text {
                    text: "Source files remain unchanged until you explicitly export."
                    color: "#64748b"
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }

        // Main Content Area
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#0b1829"

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Top Header Bar
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 48
                    color: "#0f172a"
                    border.color: "#1e293b"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        Text {
                            text: "Local data quality, repair, comparison and analysis"
                            color: "#94a3b8"
                            font.pixelSize: 12
                            Layout.fillWidth: true
                        }
                        Text {
                            text: "• LOCAL ONLY"
                            color: "#22c55e"
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }
                }

                // StackView / Pages Container
                StackLayout {
                    id: stackView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: 0

                    ComparePage { }
                    SingleReviewPage { }
                    RepairPage { }
                    CreateStorePage { }
                    HealthPage { }
                    ExplorePage { }
                }

                // Bottom Status Bar
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 28
                    color: "#0f172a"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        Text { text: backend.message; color: "#94a3b8"; font.pixelSize: 11; Layout.fillWidth: true }
                        Text { text: "StoreLens 7.2.1"; color: "#64748b"; font.pixelSize: 11 }
                    }
                }
            }
        }
    }
}
