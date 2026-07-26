import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"
Item{
 property string src:"";ListModel{id:issues}
 FileDialog{id:openDlg;nameFilters:["CSV / Text (*.csv *.txt *.tsv)"];onAccepted:{src=selectedFile.toString();backend.inspectRepair(src)}}
 FileDialog{id:saveDlg;fileMode:FileDialog.SaveFile;nameFilters:["CSV (*.csv)"];onAccepted:backend.repair(src,selectedFile.toString())}
 Connections{target:backend;function onRepairReady(p){var d=JSON.parse(p);issues.clear();for(var i=0;i<d.length;i++){var r=d[i];issues.append({line:String(r.line),status:String(r.status),repair:String(r.repair),content:String(r.content)})}}}
 ColumnLayout{anchors.fill:parent;anchors.margins:22;spacing:10;PageTitle{text:"Repair CSV / Text"}Text{text:"Audit broken-line reconstruction before saving. Original files are never overwritten.";color:"#94a3b8"}
  Card{Layout.fillWidth:true;implicitHeight:85;RowLayout{anchors.fill:parent;anchors.margins:12;TextField{Layout.fillWidth:true;readOnly:true;text:src;placeholderText:"CSV / TXT / TSV"}AppButton{text:"Choose File";onClicked:openDlg.open()}PrimaryButton{text:"Save Repaired Copy";enabled:src!=="";onClicked:saveDlg.open()}}}
  Card{Layout.fillWidth:true;Layout.fillHeight:true;ColumnLayout{anchors.fill:parent;anchors.margins:10;Text{text:"Repair Audit — "+issues.count+" issue(s)";color:"#f8fafc";font.bold:true}ListView{Layout.fillWidth:true;Layout.fillHeight:true;model:issues;clip:true;delegate:Rectangle{required property string line;required property string status;required property string repair;required property string content;width:ListView.view.width;height:44;color:status==="UNRESOLVED"?"#421820":"#433614";RowLayout{anchors.fill:parent;Text{text:line;color:"#f8fafc";Layout.preferredWidth:100;leftPadding:6}Text{text:status;color:status==="UNRESOLVED"?"#ef4444":"#f59e0b";font.bold:true;Layout.preferredWidth:110}Text{text:repair;color:"#f8fafc";Layout.preferredWidth:360;elide:Text.ElideRight}Text{text:content;color:"#f8fafc";Layout.fillWidth:true;elide:Text.ElideRight}}}}}}
 }
}
