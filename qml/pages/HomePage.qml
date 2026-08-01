import QtQuick 2.15
import QtQuick.Controls 2.15
import "../theme"

ListView {
    id: dataList
    anchors.fill: parent
    anchors.margins: Theme.paddingMedium
    model: storeTableModel // Bound from Python controller
    
    // Performance Optimizations for 60 FPS scrolling
    clip: true
    reuseItems: true // Recycles delegates instead of destroying/recreating them
    cacheBuffer: 1000 // Keeps items just outside the viewport ready
    
    delegate: Rectangle {
        width: ListView.view.width
        height: 48
        color: index % 2 === 0 ? Theme.surface : Theme.background
        border.color: Theme.border
        border.width: 1
        
        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Theme.paddingMedium
            text: model.display // Accessed safely via StoreTableModel
            font: Theme.fontBody
            color: Theme.textPrimary
        }
    }
}
