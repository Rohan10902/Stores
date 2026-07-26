import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: home
    signal navigate(int p)

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            width: parent.width
            spacing: 16

            Item { implicitHeight: 18 }

            Text {
                text: "Data Workspace"
                color: "#f8fafc"
                font.pixelSize: 26
                font.bold: true
                Layout.leftMargin: 25
            }

            Text {
                text: "Choose a local workflow. Source files are never modified unless you explicitly export a new copy."
                color: "#94a3b8"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                Layout.leftMargin: 25
                Layout.rightMargin: 25
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 25
                Layout.rightMargin: 25
                columns: width >= 900 ? 2 : 1
                columnSpacing: 12
                rowSpacing: 12

                Repeater {
                    model: [
                        {"title":"Compare & Validate", "description":"Master vs Uploaded key-based comparison.", "page":1},
                        {"title":"Review One File", "description":"Analyze a standalone dataset and review formatting issues.", "page":2},
                        {"title":"Repair CSV / Text", "description":"Inspect malformed records and export a reviewed copy.", "page":3},
                        {"title":"Create Store File", "description":"Paste values into the fixed Store schema and export CSV.", "page":4},
                        {"title":"Data Health & Statistics", "description":"Profile quality and calculate useful statistics.", "page":5},
                        {"title":"Explore & Analyze", "description":"Search locally and run read-only SQL.", "page":6}
                    ]

                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 132
                        radius: 10
                        color: "#0b1728"
                        border.width: 1
                        border.color: "#263850"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 15
                            Text { text: modelData.title; color: "#f8fafc"; font.pixelSize: 16; font.bold: true }
                            Text { text: modelData.description; color: "#94a3b8"; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                            Item { Layout.fillHeight: true }
                            Button {
                                text: "Open"
                                onClicked: home.navigate(modelData.page)
                            }
                        }
                    }
                }
            }
            Item { implicitHeight: 20 }
        }
    }
}
