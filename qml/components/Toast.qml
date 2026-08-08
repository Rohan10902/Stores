import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Item {
    id: root
    width: 350
    height: 60
    visible: false
    opacity: 0

    property string message: ""
    property string type: "info" // accepts: success, warning, error, info

    // Expose show method to be called from Main.qml Connections
    function show(msg, msgType) {
        root.message = msg;
        if (msgType) root.type = msgType;
        
        root.visible = true;
        showAnim.start();
        hideTimer.restart();
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusMedium
        color: Theme.surface
        
        // Dynamic border color based on notification type
        border.color: {
            if (root.type === "success") return Theme.success;
            if (root.type === "error") return Theme.error;
            if (root.type === "warning") return Theme.warning;
            return Theme.primary; // default info
        }
        border.width: 2

        // Subtle drop shadow effect
        layer.enabled: true
        
        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingMedium
            spacing: Theme.spacingMedium

            Text {
                text: root.message
                color: Theme.textPrimary
                font.pixelSize: 14
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    // Animations (Step 10)
    SequentialAnimation {
        id: showAnim
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: Theme.durationMedium }
    }

    SequentialAnimation {
        id: hideAnim
        NumberAnimation { target: root; property: "opacity"; to: 0.0; duration: Theme.durationMedium }
        PropertyAction { target: root; property: "visible"; value: false }
    }

    Timer {
        id: hideTimer
        interval: 3500 // Visible for 3.5 seconds
        onTriggered: hideAnim.start()
    }
}
