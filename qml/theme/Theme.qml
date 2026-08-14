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

    readonly property int sidebarWidth: 252
    readonly property int headerHeight: 64
    readonly property int buttonHeight: 40
    readonly property int fieldHeight: 38

    readonly property int spacingTiny: 4
    readonly property int spacingSmall: 8
    readonly property int spacingMedium: 12
    readonly property int spacingLarge: 18
    readonly property int spacingXLarge: 26
    readonly property int spacingXXLarge: 34

    readonly property int radiusSmall: 6
    readonly property int radiusMedium: 9
    readonly property int radiusLarge: 12
    readonly property int radiusXLarge: 16

    readonly property int durationFast: 120
    readonly property int durationMedium: 180
    readonly property int durationSlow: 280
}
