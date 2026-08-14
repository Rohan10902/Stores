import QtQuick
import QtQuick.Layouts
import "../theme"

ColumnLayout {
    property string title: ""
    property string subtitle: ""
    property string eyebrow: "StoreLens 3.0"
    spacing: Theme.spacingSmall

    Text {
        text: parent.eyebrow
        color: Theme.primary
        font.pixelSize: 10
        font.bold: true
        font.letterSpacing: 1.2
        visible: text !== ""
    }

    Text {
        text: parent.title
        color: Theme.textPrimary
        font.pixelSize: 30
        font.bold: true
    }

    Text {
        text: parent.subtitle
        color: Theme.textSecondary
        font.pixelSize: 14
        visible: text !== ""
        wrapMode: Text.WordWrap
    }
}
