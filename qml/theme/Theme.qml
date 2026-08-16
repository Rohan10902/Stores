pragma Singleton
import QtQuick

QtObject {
    // StoreLens 3.0: restrained dark workspace with stronger hierarchy and consistent interaction states.
    readonly property color background: "#06101C"
    readonly property color backgroundAlt: "#091522"
    readonly property color surface: "#0B1828"
    readonly property color surfaceElevated: "#102238"
    readonly property color surfaceHover: "#162B44"
    readonly property color surfaceActive: "#1A3655"
    readonly property color border: "#203B58"
    readonly property color borderStrong: "#315473"

    readonly property color primary: "#4F8CFF"
    readonly property color primaryHover: "#72A7FF"
    readonly property color primaryPressed: "#3478EE"
    readonly property color primarySoft: "#173B6C"
    readonly property color focusRing: "#72A7FF"

    readonly property color success: "#43D17A"
    readonly property color successSoft: "#123823"
    readonly property color warning: "#F5B83D"
    readonly property color warningSoft: "#3A2C12"
    readonly property color error: "#F26D78"
    readonly property color errorSoft: "#3B1820"
    readonly property color info: "#5BA7FF"
    readonly property color infoSoft: "#132E4E"

    readonly property color textPrimary: "#F5F8FC"
    readonly property color textSecondary: "#A7B8CC"
    readonly property color textMuted: "#6E839B"
    readonly property color textDisabled: "#4B5E73"

    // Scale from both dimensions so short Windows windows do not become vertically cramped.
    // The 0.82 floor keeps controls usable at the application's 1150x700 minimum size.
    readonly property real viewportWidthScale: Qt.application.activeWindow
        ? Qt.application.activeWindow.width / 1500.0
        : 1.0
    readonly property real viewportHeightScale: Qt.application.activeWindow
        ? Qt.application.activeWindow.height / 920.0
        : 1.0
    readonly property real viewportScale: Math.max(0.82, Math.min(1.0, viewportWidthScale, viewportHeightScale))

    readonly property int sidebarWidth: Math.round(252 * viewportScale)
    readonly property int headerHeight: Math.round(64 * viewportScale)
    readonly property int buttonHeight: Math.max(34, Math.round(40 * viewportScale))
    readonly property int fieldHeight: Math.max(34, Math.round(38 * viewportScale))

    readonly property int spacingTiny: Math.max(3, Math.round(4 * viewportScale))
    readonly property int spacingSmall: Math.max(6, Math.round(8 * viewportScale))
    readonly property int spacingMedium: Math.max(10, Math.round(12 * viewportScale))
    readonly property int spacingLarge: Math.max(14, Math.round(18 * viewportScale))
    readonly property int spacingXLarge: Math.max(20, Math.round(26 * viewportScale))
    readonly property int spacingXXLarge: Math.max(26, Math.round(34 * viewportScale))

    readonly property int radiusSmall: 6
    readonly property int radiusMedium: 9
    readonly property int radiusLarge: 12
    readonly property int radiusXLarge: 16

    readonly property int durationFast: 120
    readonly property int durationMedium: 180
    readonly property int durationSlow: 280
}
