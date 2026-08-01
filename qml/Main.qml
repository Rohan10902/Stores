import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    visible: true
    width: 1024
    height: 768
    title: "StoreLens"
    
    // Background color
    color: "#1e1e2e"

    // ---------------------------------------------------------
    // GLOBAL CONNECTION TO BACKEND
    // ---------------------------------------------------------
    Connections {
        target: backend // Connected directly to MainBackendController
        
        function onErrorOccurred(title, details) {
            toast.showError(title, details)
        }
    }

    // ---------------------------------------------------------
    // MAIN UI CONTENT
    // ---------------------------------------------------------
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 20

        Text {
            // Defensive Binding: Fallback to "Unknown State" if backend is unavailable
            text: "Status: " + (backend ? (backend.currentStatus ?? "Ready") : "Offline")
            color: "#cdd6f4"
            font.pixelSize: 18
            Layout.alignment: Qt.AlignHCenter
        }

        RowLayout {
            spacing: 15
            Layout.alignment: Qt.AlignHCenter

            Button {
                text: "Load Valid Data"
                onClicked: {
                    if (backend) backend.loadDataSafely("valid_dataset.csv")
                }
            }

            Button {
                text: "Simulate Critical Failure"
                // This triggers the try-catch block in Python and shows the Toast UI
                onClicked: {
                    if (backend) backend.loadDataSafely("crash_test.csv")
                }
            }
        }
    }

    // ---------------------------------------------------------
    // GLOBAL TOAST NOTIFICATION (ERROR BANNER)
    // ---------------------------------------------------------
    Rectangle {
        id: toast
        width: parent.width * 0.4
        height: 60
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        
        // Start hidden above the screen
        y: -height - 20 
        radius: 8
        color: "#f38ba8" // Soft red color for errors
        
        property string errorTitle: ""
        property string errorMessage: ""

        // Animation states
        states: [
            State {
                name: "visible"
                PropertyChanges { target: toast; y: 20 }
            }
        ]

        transitions: Transition {
            NumberAnimation { properties: "y"; duration: 300; easing.type: Easing.OutBack }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 15

            Text {
                text: "⚠️"
                font.pixelSize: 24
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: toast.errorTitle
                    font.bold: true
                    color: "#11111b"
                    font.pixelSize: 14
                }
                Text {
                    text: toast.errorMessage
                    color: "#181825"
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }

        // Timer to auto-hide the notification after 4 seconds
        Timer {
            id: hideTimer
            interval: 4000
            onTriggered: toast.state = ""
        }

        function showError(title, message) {
            toast.errorTitle = title
            toast.errorMessage = message
            toast.state = "visible"
            hideTimer.restart()
        }
    }
}
