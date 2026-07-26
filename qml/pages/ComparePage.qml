import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"
Item{
 property string master:"";property string upload:"";property int selected:-1;property bool diff:true
 property int total:0;property int ok:0;property int rev:0;property int err:0
 property string detailProblem:"";property string detailStatus:"";property var detailContext:({})
 property var suggestedKeys:[];property string key1:"SID";property string key2:"Nielsen Store Code"
 ListModel{id:rows}ListModel{id:details}ListModel{id:related}
 FileDialog{id:md;nameFilters:["Data (*.csv *.xlsx *.xls *.xlsm *.txt *.tsv *.json *.xml)"];onAccepted:{master=selectedFile.toString();backend.loadMaster(master)}}
 FileDialog{id:ud;nameFilters:["Data (*.csv *.xlsx *.xls *.xlsm *.txt *.tsv *.json *.xml)"];onAccepted:{upload=selectedFile.toString();backend.loadUpload(upload)}}
 Connections{target:backend
  function onMappingReady(p){var d=JSON.parse(p);suggestedKeys=d.suggestedKeys||["SID"];key1=suggestedKeys[0]||"SID";key2=suggestedKeys.length>1?suggestedKeys[1]:"(None)"}
  function onValidationReady(p){var d=JSON.parse(p);total=d.total;ok=d.correct;rev=d.review;err=d.errors;rows.clear();details.clear();related.clear();selected=-1;for(var i=0;i<d.rows.length;i++){var r=d.rows[i];rows.append({row:String(r.row),sid:String(r.sid),store:String(r.storeName),status:String(r.status),problem:String(r.problem)})}}
  function onDetailReady(p){var d=JSON.parse(p);detailProblem=d.problem;detailStatus=d.status;detailContext=d.context||({});details.clear();related.clear();for(var i=0;i<d.rows.length;i++){var r=d.rows[i];details.append({f:String(r.field),m:String(r.master),u:String(r.uploaded),res:String(r.result),sev:String(r.severity)})}var rr=(detailContext.relatedUploaded||[]);for(var j=0;j<rr.length;j++)related.append({row:String(rr[j].row),sid:String(rr[j].sid),nielsen:String(rr[j].nielsen),store:String(rr[j].storeName)})}
 }
 ColumnLayout{anchors.fill:parent;anchors.margins:22;spacing:10
  PageTitle{text:"Compare & Validate"}
  Card{Layout.fillWidth:true;implicitHeight:164;ColumnLayout{anchors.fill:parent;anchors.margins:12
   RowLayout{TextField{Layout.fillWidth:true;readOnly:true;text:master;placeholderText:"Master file"}AppButton{text:"Browse";onClicked:md.open()}}
   RowLayout{TextField{Layout.fillWidth:true;readOnly:true;text:upload;placeholderText:"Uploaded / country file"}AppButton{text:"Browse";onClicked:ud.open()}}
   RowLayout{
    Text{text:"Match by";color:"#94a3b8"}
    ComboBox{id:k1;Layout.preferredWidth:190;model:["SID","Nielsen Store Code"];currentIndex:model.indexOf(key1)}
    Text{text:"+";color:"#94a3b8"}
    ComboBox{id:k2;Layout.preferredWidth:220;model:["(None)","Nielsen Store Code","SID"];currentIndex:model.indexOf(key2)}
    Text{text:suggestedKeys.length?"Smart suggestion: "+suggestedKeys.join(" + "):"";color:"#60a5fa";Layout.fillWidth:true;elide:Text.ElideRight}
    AppButton{text:"Detect Columns";enabled:master!==""&&upload!=="";onClicked:backend.detect()}
    PrimaryButton{text:"Validate";enabled:master!==""&&upload!=="";onClicked:{var a=[k1.currentText];if(k2.currentText!=="(None)"&&k2.currentText!==k1.currentText)a.push(k2.currentText);backend.validate(JSON.stringify(a))}}
   }
  }}
  RowLayout{Layout.fillWidth:true;Repeater{model:[["TOTAL",total,"#3b82f6"],["CORRECT",ok,"#22c55e"],["REVIEW",rev,"#f59e0b"],["ERROR",err,"#ef4444"]];delegate:Card{required property var modelData;Layout.fillWidth:true;implicitHeight:64;Column{anchors.fill:parent;anchors.margins:8;Text{text:modelData[1];color:modelData[2];font.pixelSize:19;font.bold:true}Text{text:modelData[0];color:"#94a3b8";font.pixelSize:9;font.bold:true}}}}}
  SplitView{Layout.fillWidth:true;Layout.fillHeight:true;orientation:Qt.Vertical
   Card{SplitView.minimumHeight:150;SplitView.preferredHeight:parent.height*.38;ColumnLayout{anchors.fill:parent;anchors.margins:10
    Text{text:"Validation Results — row order does not affect matching";color:"#f8fafc";font.bold:true}
    ListView{Layout.fillWidth:true;Layout.fillHeight:true;model:rows;clip:true;delegate:Rectangle{required property int index;required property string row;required property string sid;required property string store;required property string status;required property string problem;width:ListView.view.width;height:36;color:selected===index?"#17375f":index%2?"#0d1b2e":"#0b1829";MouseArea{anchors.fill:parent;onClicked:{selected=index;backend.detail(index,diff)}}RowLayout{anchors.fill:parent;Text{text:row;color:"#94a3b8";Layout.preferredWidth:55;leftPadding:6}Text{text:sid;color:"#f8fafc";Layout.preferredWidth:130}Text{text:store;color:"#f8fafc";Layout.preferredWidth:230;elide:Text.ElideRight}Text{text:status;color:status==="ERROR"?"#ef4444":status==="REVIEW"?"#f59e0b":"#22c55e";font.bold:true;Layout.preferredWidth:90}Text{text:problem;color:"#f8fafc";Layout.fillWidth:true;elide:Text.ElideRight}}}}}}
   Card{SplitView.minimumHeight:240;SplitView.fillHeight:true;ColumnLayout{anchors.fill:parent;anchors.margins:10
    RowLayout{Text{text:"Error-aware Comparison Inspector";color:"#f8fafc";font.bold:true}Item{Layout.fillWidth:true}CheckBox{text:"Differences only";checked:diff;onToggled:{diff=checked;if(selected>=0)backend.detail(selected,diff)}}}
    Rectangle{visible:selected>=0;Layout.fillWidth:true;implicitHeight:52;radius:6;color:detailStatus==="ERROR"?"#421820":detailStatus==="REVIEW"?"#433614":"#113426";Text{anchors.fill:parent;anchors.margins:8;text:detailProblem;color:"#f8fafc";wrapMode:Text.WordWrap}}
    Text{visible:related.count>1;text:"Related uploaded records for this identity";color:"#f59e0b";font.bold:true}
    ListView{visible:related.count>1;Layout.fillWidth:true;Layout.preferredHeight:Math.min(78,related.count*28);model:related;delegate:RowLayout{required property string row;required property string sid;required property string nielsen;required property string store;width:ListView.view.width;height:26;Text{text:"Row "+row;color:"#94a3b8";Layout.preferredWidth:80}Text{text:sid;color:"#f8fafc";Layout.preferredWidth:130}Text{text:nielsen;color:"#60a5fa";Layout.preferredWidth:170}Text{text:store;color:"#f8fafc";Layout.fillWidth:true}}}
    RowLayout{Layout.fillWidth:true;Text{text:"Field";color:"#94a3b8";font.bold:true;Layout.preferredWidth:190}Text{text:"Master Value";color:"#94a3b8";font.bold:true;Layout.fillWidth:true}Text{text:"Uploaded Value";color:"#94a3b8";font.bold:true;Layout.fillWidth:true}Text{text:"Result";color:"#94a3b8";font.bold:true;Layout.preferredWidth:140}}
    ListView{Layout.fillWidth:true;Layout.fillHeight:true;model:details;clip:true;delegate:Rectangle{required property string f;required property string m;required property string u;required property string res;required property string sev;width:ListView.view.width;height:34;color:sev==="ERROR"?"#421820":sev==="REVIEW"?"#433614":"#113426";RowLayout{anchors.fill:parent;Text{text:f;color:"#f8fafc";font.bold:true;Layout.preferredWidth:190;leftPadding:6}Text{text:m;color:"#f8fafc";Layout.fillWidth:true;elide:Text.ElideRight}Text{text:u;color:"#f8fafc";Layout.fillWidth:true;elide:Text.ElideRight}Text{text:res;color:sev==="ERROR"?"#ef4444":sev==="REVIEW"?"#f59e0b":"#22c55e";font.bold:true;Layout.preferredWidth:140}}}}}}
  }
 }
}
