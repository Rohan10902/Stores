pragma Singleton
import QtQuick

QtObject {
    readonly property color background: "#07111F"
    readonly property color surface: "#0D1B2E"
    readonly property color surfaceHover: "#12243B"
    readonly property color border: "#263B55"

    readonly property color primary: "#3B82F6"
    readonly property color primaryHover: "#4F8FF7"

    readonly property color success: "#4ADE80"
    readonly property color warning: "#FBBF24"
    readonly property color error: "#F87171"
    readonly property color info: "#60A5FA"

    readonly property color textPrimary: "#F8FAFC"
    readonly property color textSecondary: "#94A3B8"
    readonly property color textMuted: "#64748B"

    readonly property int sidebarWidth: 200
    readonly property int headerHeight: 56
    readonly property int buttonHeight: 40

    readonly property int spacingSmall: 8
    readonly property int spacingMedium: 12
    readonly property int spacingLarge: 20
    readonly property int spacingXLarge: 28

    readonly property int radiusMedium: 8
    readonly property int radiusLarge: 10

    readonly property int durationFast: 120
    readonly property int durationMedium: 220
}
