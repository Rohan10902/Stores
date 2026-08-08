pragma Singleton
import QtQuick

QtObject {
    id: theme

    // Colors - Deep Navy / Charcoal professional theme
    readonly property color background: "#0F172A"
    readonly property color surface: "#1E293B"
    readonly property color surfaceHover: "#334155"
    readonly property color border: "#334155"
    
    readonly property color primary: "#3B82F6"
    readonly property color primaryHover: "#2563EB"
    
    readonly property color textPrimary: "#F8FAFC"
    readonly property color textSecondary: "#94A3B8"
    
    // Status Colors
    readonly property color success: "#10B981"
    readonly property color warning: "#F59E0B"
    readonly property color error: "#EF4444"
    readonly property color info: "#3B82F6"

    // Spacing
    readonly property int spacingSmall: 8
    readonly property int spacingMedium: 16
    readonly property int spacingLarge: 24
    readonly property int spacingXLarge: 32

    // Radius
    readonly property int radiusMedium: 8
    readonly property int radiusLarge: 12

    // Dimensions
    readonly property int sidebarWidth: 260
    readonly property int buttonHeight: 40
    readonly property int headerHeight: 64

    // Animation Durations
    readonly property int durationFast: 150
    readonly property int durationMedium: 250
}
