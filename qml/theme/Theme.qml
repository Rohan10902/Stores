pragma Singleton
import QtQuick

QtObject {
    // Premium dark workspace palette: calm, high-contrast, and data-first.
    readonly property color background: "#070D18"
    readonly property color backgroundAlt: "#0A1220"
    readonly property color surface: "#0D1726"
    readonly property color surfaceElevated: "#111E30"
    readonly property color surfaceHover: "#16263B"
    readonly property color surfaceActive: "#19304B"
    readonly property color border: "#22354D"
    readonly property color borderStrong: "#2F4967"

    readonly property color primary: "#4F8CFF"
    readonly property color primaryHover: "#6A9DFF"
    readonly property color primarySoft: "#18345F"

    readonly property color success: "#43D17A"
    readonly property color successSoft: "#123823"
    readonly property color warning: "#F5B83D"
    readonly property color warningSoft: "#3A2C12"
    readonly property color error: "#F26D78"
    readonly property color errorSoft: "#3B1820"
    readonly property color info: "#5BA7FF"
    readonly property color infoSoft: "#132E4E"

    readonly property color textPrimary: "#F4F7FB"
    readonly property color textSecondary: "#9AAAC0"
    readonly property color textMuted: "#66788F"
    readonly property color textDisabled: "#46566A"

    readonly property int sidebarWidth: 244
    readonly property int headerHeight: 68
    readonly property int buttonHeight: 42

    readonly property int spacingTiny: 4
    readonly property int spacingSmall: 8
    readonly property int spacingMedium: 12
    readonly property int spacingLarge: 20
    readonly property int spacingXLarge: 28
    readonly property int spacingXXLarge: 36

    readonly property int radiusSmall: 6
    readonly property int radiusMedium: 9
    readonly property int radiusLarge: 13
    readonly property int radiusXLarge: 17

    readonly property int durationFast: 120
    readonly property int durationMedium: 200
    readonly property int durationSlow: 300
}
