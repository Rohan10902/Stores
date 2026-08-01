import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    visible: true
    width: 1280
    height: 720
    title: "StoreLens"
    
    // ---------------------------------------------------------
    // 1. GLOBAL ERROR HANDLER CONNECTION
    // ---------------------------------------------------------
    Connections {
        target: backend 
        
        function onErrorOccurred(title, details) {
            toast.showError(title, details)
        }
    }

    // ---------------------------------------------------------
    // 2. YOUR ORIGINAL STORELENS UI GOES HERE
    // ---------------------------------------------------------
    // --> PASTE YOUR ORIGINAL LAYOUT, SIDEBARS, AND VIEWS HERE <--
    
    Item {
        anchors.fill: parent
        
        Text {
            anchors.centerIn: parent
            text: "Please paste your original StoreLens UI code here."
            font.pixelSize: 18
            color: "gray"
        }
    }

    // ---------------------------------------------------------
    // 3. GLOBAL TOAST NOTIFICATION (ERROR BANNER)
    // ---------------------------------------------------------
    // This stays at the bottom so it renders on top of your UI (z: 999)
    Rectangle {
        id: toast
        width: parent.width * 0.4
        height: 60
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        z: 999
        
        // Start hidden above the screen
        y: -height - 20 
        radius: 8
        color: "#f38ba8" 
        
        property string errorTitle: ""
        property string errorMessage: ""

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
