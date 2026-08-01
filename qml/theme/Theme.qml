pragma Singleton
import QtQuick 2.15
import QtQuick.Controls 2.15

QtObject {
    // Colors
    readonly property color primary: "#1E88E5"
    readonly property color primaryHover: "#1565C0"
    readonly property color background: "#F5F7FA"
    readonly property color surface: "#FFFFFF"
    readonly property color textPrimary: "#212121"
    readonly property color textSecondary: "#757575"
    readonly property color border: "#E0E0E0"
    
    // Semantic Colors
    readonly property color success: "#43A047"
    readonly property color warning: "#FDD835"
    readonly property color error: "#E53935"

    // Spacing & Radii
    readonly property int paddingSmall: 8
    readonly property int paddingMedium: 16
    readonly property int paddingLarge: 24
    readonly property int radius: 6

    // Typography
    readonly property font fontTitle: Qt.font({ family: "Segoe UI", pixelSize: 20, weight: Font.Bold })
    readonly property font fontSubtitle: Qt.font({ family: "Segoe UI", pixelSize: 16, weight: Font.DemiBold })
    readonly property font fontBody: Qt.font({ family: "Segoe UI", pixelSize: 14 })
    readonly property font fontCaption: Qt.font({ family: "Segoe UI", pixelSize: 12 })
}
