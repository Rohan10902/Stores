import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "pages"

ApplicationWindow {
    id: root
    visible: true
    width: 1440; height: 900
    minimumWidth: 1050; minimumHeight: 680
    title: "Store Data Assistant 7.1.4 SAFE BOOT"
    color: "#07111f"
    property int page: 0
    property bool wide: width >= 1500
    property real uiScale: Math.max(0.9, Math.min(1.18, width / 1440))

    header: Rectangle {
        height: 58 * root.uiScale; color:"#081321"; border.width:1; border.color:"#263850"
        RowLayout {
            anchors.fill:parent; anchors.margins:12
            Rectangle { width:34; height:34; radius:8; color:"#3b82f6"; Text{anchors.centerIn:parent;text:"DA";color:"white";font.bold:true} }
            Column {
                Text{text:"Store Data Assistant 7.1.4 SAFE BOOT";color:"#f8fafc";font.pixelSize:15*root.uiScale;font.bold:true}
                Text{text:"Local data quality, repair, comparison and analysis";color:"#94a3b8";font.pixelSize:9*root.uiScale}
            }
            Item{Layout.fillWidth:true}
            Text{text:"● LOCAL ONLY";color:"#86efac";font.bold:true}
        }
    }
    footer: Rectangle {
        height:30; color:"#081321"; border.width:1; border.color:"#263850"
        RowLayout { anchors.fill:parent;anchors.leftMargin:12;anchors.rightMargin:12
            Text{text:backend.message;color:"#94a3b8";font.pixelSize:10;Layout.fillWidth:true;elide:Text.ElideRight}
            Text{text:"7.1.4 SAFE BOOT";color:"#94a3b8";font.pixelSize:9}
        }
    }
    RowLayout {
        anchors.fill:parent; spacing:0
        Rectangle {
            Layout.preferredWidth: Math.max(210, 220*root.uiScale); Layout.fillHeight:true
            color:"#0b1728";border.width:1;border.color:"#263850"
            ColumnLayout {
                anchors.fill:parent;anchors.margins:10
                Text{text:"WORKSPACE";color:"#94a3b8";font.pixelSize:9;font.bold:true;Layout.leftMargin:8}
                Repeater {
                    model:["Home","Compare & Validate","Repair CSV / Text","Data Health & Statistics","Explore & Analyze"]
                    delegate:Button {
                        required property string modelData;required property int index
                        Layout.fillWidth:true;implicitHeight:42*root.uiScale;text:modelData
                        palette.button:root.page===index?"#1d4777":"#0b1728";palette.buttonText:"#f8fafc"
                        onClicked:root.page=index
                    }
                }
                Item{Layout.fillHeight:true}
                Text{text:"Source files remain unchanged.";color:"#94a3b8";font.pixelSize:9}
            }
        }
        StackLayout {
            currentIndex:root.page;Layout.fillWidth:true;Layout.fillHeight:true
            HomePage{onNavigate:(p)=>root.page=p}
            ComparePage{}
            RepairPage{}
            HealthPage{}
            ExplorePage{}
        }
    }
}
