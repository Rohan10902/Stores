import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"
Item{
 property string src:"";property var audit:({});property int selected:-1
 ListModel{id:issues}ListModel{id:preview}
 FileDialog{id:openDlg;nameFilters:["CSV / Text (*.csv *.txt *.tsv)"];onAccepted:{src=selectedFile.toString();selected=-1;backend.inspectRepair(src)}}
 FileDialog{id:saveDlg;fileMode:FileDialog.SaveFile;nameFilters:["CSV (*.csv)"];onAccepted:backend.repair(src,selectedFile.toString())}
 function showIssue(i){selected=i;preview.clear();if(i<0||i>=issues.count)return;var c=JSON.parse(issues.get(i).columnsJson);for(var j=0;j<c.length;j++){var x=c[j];preview.append({sourceIndex:j,field:String(x.field),before:String(x.detected),after:String(x.proposed||""),state:String(x.state),reason:String(x.reason||""),suggested:String(x.suggestedField||""),confidence:String(x.confidence||0),decision:String(x.decision||""),candidatesJson:JSON.stringify(x.candidates||[])})}}
 Connections{target:backend;function onRepairReady(p){var d=JSON.parse(p);var old=selected;audit=d;issues.clear();for(var i=0;i<d.issues.length;i++){var r=d.issues[i];issues.append({line:String(r.line),status:String(r.status),decision:String(r.decision),problem:String(r.problem),diagnosis:String(r.diagnosis),expected:String(r.expectedColumns),actual:String(r.actualColumns),confidence:String(r.confidence),columnsJson:JSON.stringify(r.columns)})}if(issues.count)showIssue(Math.max(0,Math.min(old,issues.count-1)))}}
 ColumnLayout{anchors.fill:parent;anchors.margins:22;spacing:10
  PageTitle{text:"Repair CSV / Text — Smart Repair"}
  Text{text:"Suggestions are local and explainable. Nothing is silently reassigned or deleted.";color:"#94a3b8"}
  Card{Layout.fillWidth:true;implicitHeight:70;RowLayout{anchors.fill:parent;anchors.margins:10;TextField{Layout.fillWidth:true;readOnly:true;text:src;placeholderText:"CSV / TXT / TSV"}AppButton{text:"Choose File";onClicked:openDlg.open()}PrimaryButton{text:"Save Reviewed Copy";enabled:src!=="";onClicked:saveDlg.open()}}}
  RowLayout{Layout.fillWidth:true;Repeater{model:[["RECORDS",audit.records||0],["EXPECTED",audit.expected||0],["HEALTHY",audit.healthy||0],["AUTO FIXED",audit.autoFixed||0],["REVIEW",audit.reviewRequired||0]];delegate:Card{required property var modelData;Layout.fillWidth:true;implicitHeight:58;Column{anchors.fill:parent;anchors.margins:8;Text{text:modelData[1];color:"#22c55e";font.pixelSize:18;font.bold:true}Text{text:modelData[0];color:"#94a3b8";font.pixelSize:9;font.bold:true}}}}}
  SplitView{Layout.fillWidth:true;Layout.fillHeight:true;orientation:Qt.Vertical
   Card{SplitView.minimumHeight:145;SplitView.preferredHeight:parent.height*.30;ColumnLayout{anchors.fill:parent;anchors.margins:10
    RowLayout{Text{text:"Repair Audit";color:"#f8fafc";font.bold:true}Item{Layout.fillWidth:true}Text{visible:audit.unresolved>0;text:(audit.unresolved||0)+" record(s) need review";color:"#f59e0b";font.bold:true}}
    ListView{Layout.fillWidth:true;Layout.fillHeight:true;model:issues;clip:true;delegate:Rectangle{required property int index;required property string line;required property string status;required property string problem;required property string expected;required property string actual;width:ListView.view.width;height:36;color:selected===index?"#17375f":status==="AUTO FIXED"?"#113426":"#421820";MouseArea{anchors.fill:parent;onClicked:showIssue(index)}RowLayout{anchors.fill:parent;Text{text:line;color:"#f8fafc";Layout.preferredWidth:70;leftPadding:6}Text{text:status;color:status==="AUTO FIXED"?"#22c55e":"#f59e0b";font.bold:true;Layout.preferredWidth:135}Text{text:problem;color:"#f8fafc";Layout.fillWidth:true;elide:Text.ElideRight}Text{text:expected+" → "+actual;color:expected===actual?"#22c55e":"#ef4444";Layout.preferredWidth:90}}}}}}
   Card{SplitView.minimumHeight:300;SplitView.fillHeight:true;ColumnLayout{anchors.fill:parent;anchors.margins:10
    Text{text:"Record Reconstruction Inspector";color:"#f8fafc";font.bold:true}
    Rectangle{visible:selected>=0;Layout.fillWidth:true;implicitHeight:54;radius:6;color:"#342611";Text{anchors.fill:parent;anchors.margins:8;text:selected>=0?issues.get(selected).diagnosis:"";color:"#f8fafc";wrapMode:Text.WordWrap}}
    GridLayout{visible:selected>=0;Layout.fillWidth:true;columns:6;columnSpacing:8
     Text{text:"Field / Source";color:"#94a3b8";font.bold:true;Layout.preferredWidth:175}
     Text{text:"Detected";color:"#94a3b8";font.bold:true;Layout.preferredWidth:150}
     Text{text:"Smart Suggestion";color:"#94a3b8";font.bold:true;Layout.preferredWidth:165}
     Text{text:"Confidence";color:"#94a3b8";font.bold:true;Layout.preferredWidth:90}
     Text{text:"Reason";color:"#94a3b8";font.bold:true;Layout.fillWidth:true}
     Text{text:"Action";color:"#94a3b8";font.bold:true;Layout.preferredWidth:210}
    }
    ListView{Layout.fillWidth:true;Layout.fillHeight:true;model:preview;clip:true;delegate:Rectangle{
     required property int index;required property int sourceIndex;required property string field;required property string before;required property string after;required property string state;required property string reason;required property string suggested;required property string confidence;required property string decision;required property string candidatesJson
     width:ListView.view.width;height:48;color:state==="USER APPROVED"?"#113426":state==="REVIEW"||state==="UNRESOLVED"||state==="MISSING"?"#421820":index%2?"#0d1b2e":"#0b1829"
     RowLayout{anchors.fill:parent;spacing:8
      Text{text:field;color:"#f8fafc";font.bold:true;Layout.preferredWidth:175;leftPadding:6;elide:Text.ElideRight}
      Text{text:before;color:"#f8fafc";Layout.preferredWidth:150;elide:Text.ElideRight}
      Text{text:state==="USER APPROVED"?(after+" → "+suggested):(suggested||"—");color:suggested?"#60a5fa":"#94a3b8";Layout.preferredWidth:165;elide:Text.ElideRight}
      Text{text:Number(confidence)>0?confidence+"%":"—";color:Number(confidence)>=95?"#22c55e":Number(confidence)>=70?"#f59e0b":"#94a3b8";font.bold:true;Layout.preferredWidth:90}
      Text{text:reason;color:"#94a3b8";Layout.fillWidth:true;elide:Text.ElideRight}
      RowLayout{Layout.preferredWidth:210;visible:field.indexOf("PRESERVED EXTRA")===0
       ComboBox{id:dest;Layout.preferredWidth:120;model:audit.header||[];currentIndex:suggested?(audit.header||[]).indexOf(suggested):-1}
       Button{text:"Apply";enabled:dest.currentIndex>=0&&state!=="USER APPROVED";onClicked:backend.applyRepairMapping(selected,sourceIndex,dest.currentText,true)}
       Button{text:"Keep";enabled:state!=="USER APPROVED";onClicked:backend.keepRepairUnresolved(selected,sourceIndex)}
      }
      Text{visible:field.indexOf("PRESERVED EXTRA")!==0;text:state;color:state==="USER APPROVED"?"#22c55e":"#94a3b8";Layout.preferredWidth:210}
     }
    }}
   }}
  }
 }
}
