import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
Item{
 signal navigate(int p)
 ScrollView{anchors.fill:parent;contentWidth:availableWidth;ColumnLayout{width:parent.width;spacing:14;Item{implicitHeight:18}PageTitle{text:"Data Workspace";Layout.leftMargin:25}Text{text:"7.1.4 — compare, single-file review, fixed-schema CSV creation, repair, statistics and tabular exploration.";color:"#94a3b8";Layout.leftMargin:25;Layout.rightMargin:25;wrapMode:Text.WordWrap}
 GridLayout{Layout.fillWidth:true;Layout.leftMargin:25;Layout.rightMargin:25;columns:2;columnSpacing:12;rowSpacing:12
  Repeater{model:[["Compare & Validate","Field-by-field Master vs Uploaded comparison.",1],["Review One File","Analyze a file without requiring a Master.",2],["Create Store File","Paste from Excel into the fixed Store schema and export CSV.",3],["Repair CSV / Text","Inspect broken physical lines and save a repaired copy.",4],["Data Health & Statistics","Quality score and on-demand statistics.",5],["Explore & Analyze","Search and read-only SQL with table output.",6]]
   delegate:Card{required property var modelData;Layout.fillWidth:true;implicitHeight:140;ColumnLayout{anchors.fill:parent;anchors.margins:15;Text{text:modelData[0];color:"#f8fafc";font.pixelSize:16;font.bold:true}Text{text:modelData[1];color:"#94a3b8";wrapMode:Text.WordWrap;Layout.fillWidth:true}Item{Layout.fillHeight:true}PrimaryButton{text:"Open";onClicked:navigate(modelData[2])}}}
  }
 }
 }}}
