import QtQuick
import QtQuick.Layouts
import "../theme"

ColumnLayout {
    property string title: ""
    property string subtitle: ""
    spacing: Theme.spacingSmall

    Text {
        text: parent.title
        color: Theme.textPrimary
        font.pixelSize: 28
        font.bold: true
    }
    Text {
        text: parent.subtitle
        color: Theme.textSecondary
        font.pixelSize: 16
        visible: text !== ""
    }
}
