import QtQuick 2.15
import QtQuick.Controls 2.15
import "theme" // Import the local theme module

ApplicationWindow {
    id: root
    visible: true
    width: 1280
    height: 720
    title: "StoreLens"
    color: Theme.background // Replaces hard-coded "#F5F7FA"

    // Example of using Theme in child pages
    // header: Rectangle { color: Theme.surface; height: 60 ... }
}
