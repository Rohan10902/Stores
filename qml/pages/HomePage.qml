import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
Item{
 signal navigate(int p)
 ScrollView{anchors.fill:parent;contentWidth:availableWidth;ColumnLayout{width:parent.width;spacing:14;Item{implicitHeight:18}PageTitle{text:"StoreLens Workspace";Layout.leftMargin:25}Text{text:"7.2.1 testing workspace with comparison, standalone review, CSV repair, fixed-schema file creation, statistics and local analysis.";color:"#94a3b8";Layout.leftMargin:25;Layout.rightMargin:25;wrapMode:Text.WordWrap}
 GridLayout{Layout.fillWidth:true;Layout.leftMargin:25;Layout.rightMargin:25;columns:2;columnSpacing:12;rowSpacing:12
  Repeater{model:[["Compare & Validate","Master vs Uploaded key-based comparison.",1],["Review One File","Analyze one dataset without a Master and review identifier formatting.",2],["Repair CSV / Text","Inspect broken records and save a reviewed copy.",3],["Create Store File","Paste tabular values into the fixed Store schema and export CSV.",4],["Data Health & Statistics","Quality score and on-demand statistics.",5],["Explore & Analyze","Search and read-only SQL with table output.",6]]
   delegate:Card{required property var modelData;Layout.fillWidth:true;implicitHeight:140;ColumnLayout{anchors.fill:parent;anchors.margins:15;Text{text:modelData[0];color:"#f8fafc";font.pixelSize:16;font.bold:true}Text{text:modelData[1];color:"#94a3b8";wrapMode:Text.WordWrap;Layout.fillWidth:true}Item{Layout.fillHeight:true}PrimaryButton{text:"Open";onClicked:navigate(modelData[2])}}}
  }
 }
 }}}
