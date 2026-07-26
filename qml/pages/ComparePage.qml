import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"
Item {
 property string master:"";property string upload:"";property int selected:-1;property bool diff:true
 property int total:0;property int ok:0;property int rev:0;property int err:0;property bool missingMaster:false;property string selectedSid:""
 ListModel{id:rows} ListModel{id:details}
 FileDialog{id:md;nameFilters:["Data (*.csv *.xlsx *.xls *.xlsm *.txt *.tsv *.json *.xml)"];onAccepted:{master=selectedFile.toString();backend.loadMaster(master)}}
 FileDialog{id:ud;nameFilters:["Data (*.csv *.xlsx *.xls *.xlsm *.txt *.tsv *.json *.xml)"];onAccepted:{upload=selectedFile.toString();backend.loadUpload(upload)}}
 Connections{target:backend
  function onValidationReady(p){var d=JSON.parse(p);total=d.total;ok=d.correct;rev=d.review;err=d.errors;rows.clear();details.clear();selected=-1;for(var i=0;i<d.rows.length;i++){var r=d.rows[i];rows.append({row:String(r.row),sid:String(r.sid),store:String(r.storeName),status:String(r.status),problem:String(r.problem)})}}
  function onDetailReady(p){var d=JSON.parse(p);missingMaster=d.missingMaster;selectedSid=d.sid;details.clear();for(var i=0;i<d.rows.length;i++){var r=d.rows[i];details.append({f:String(r.field),m:String(r.master),u:String(r.uploaded),res:String(r.result),sev:String(r.severity)})}}
 }
 ColumnLayout{anchors.fill:parent;anchors.margins:22;spacing:10
  PageTitle{text:"Compare & Validate"}
  Card{Layout.fillWidth:true;implicitHeight:130;ColumnLayout{anchors.fill:parent;anchors.margins:12
   RowLayout{TextField{Layout.fillWidth:true;readOnly:true;text:master;placeholderText:"Master file"}AppButton{text:"Browse";onClicked:md.open()}}
   RowLayout{TextField{Layout.fillWidth:true;readOnly:true;text:upload;placeholderText:"Uploaded / country file"}AppButton{text:"Browse";onClicked:ud.open()}}
   RowLayout{AppButton{text:"Detect Columns";enabled:master!==""&&upload!=="";onClicked:backend.detect()}PrimaryButton{text:"Validate";Layout.fillWidth:true;enabled:master!==""&&upload!=="";onClicked:backend.validate()}}
  }}
  RowLayout{Layout.fillWidth:true;Repeater{model:[["TOTAL",total,"#3b82f6"],["CORRECT",ok,"#22c55e"],["REVIEW",rev,"#f59e0b"],["ERROR",err,"#ef4444"]];delegate:Card{required property var modelData;Layout.fillWidth:true;implicitHeight:68;Column{anchors.fill:parent;anchors.margins:9;Text{text:modelData[1];color:modelData[2];font.pixelSize:20;font.bold:true}Text{text:modelData[0];color:"#94a3b8";font.pixelSize:9;font.bold:true}}}}}
  SplitView{Layout.fillWidth:true;Layout.fillHeight:true;orientation:Qt.Vertical
   Card{SplitView.minimumHeight:170;SplitView.preferredHeight:parent.height*0.42;ColumnLayout{anchors.fill:parent;anchors.margins:10
    Text{text:"Validation Results — click a row";color:"#f8fafc";font.bold:true}
    ListView{Layout.fillWidth:true;Layout.fillHeight:true;model:rows;clip:true;delegate:Rectangle{required property int index;required property string row;required property string sid;required property string store;required property string status;required property string problem;width:ListView.view.width;height:36;color:selected===index?"#17375f":index%2?"#0d1b2e":"#0b1829";MouseArea{anchors.fill:parent;onClicked:{selected=index;backend.detail(index,diff)}}RowLayout{anchors.fill:parent;Text{text:row;color:"#94a3b8";Layout.preferredWidth:55;leftPadding:6}Text{text:sid;color:"#f8fafc";Layout.preferredWidth:130}Text{text:store;color:"#f8fafc";Layout.preferredWidth:230;elide:Text.ElideRight}Text{text:status;color:status==="ERROR"?"#ef4444":status==="REVIEW"?"#f59e0b":"#22c55e";font.bold:true;Layout.preferredWidth:90}Text{text:problem;color:"#f8fafc";Layout.fillWidth:true;elide:Text.ElideRight}}}}}}
   Card{SplitView.minimumHeight:190;SplitView.fillHeight:true;ColumnLayout{anchors.fill:parent;anchors.margins:10
    RowLayout{Text{text:"Field-by-Field Comparison";color:"#f8fafc";font.bold:true}Item{Layout.fillWidth:true}CheckBox{text:"Differences only";checked:diff;onToggled:{diff=checked;if(selected>=0)backend.detail(selected,diff)}}}
    Rectangle{visible:missingMaster;Layout.fillWidth:true;implicitHeight:48;radius:6;color:"#421820";Text{anchors.fill:parent;anchors.margins:9;text:"SID "+selectedSid+" does not exist in Master. Uploaded values are shown for reference; a true comparison is unavailable.";color:"#fca5a5";wrapMode:Text.WordWrap}}
    RowLayout{Layout.fillWidth:true;Text{text:"Field";color:"#94a3b8";font.bold:true;Layout.preferredWidth:190}Text{text:"Master Value";color:"#94a3b8";font.bold:true;Layout.fillWidth:true}Text{text:"Uploaded Value";color:"#94a3b8";font.bold:true;Layout.fillWidth:true}Text{text:"Result";color:"#94a3b8";font.bold:true;Layout.preferredWidth:130}}
    ListView{Layout.fillWidth:true;Layout.fillHeight:true;model:details;clip:true;delegate:Rectangle{required property string f;required property string m;required property string u;required property string res;required property string sev;width:ListView.view.width;height:36;color:sev==="ERROR"?"#421820":sev==="REVIEW"?"#433614":"#113426";RowLayout{anchors.fill:parent;Text{text:f;color:"#f8fafc";font.bold:true;Layout.preferredWidth:190;leftPadding:6}Text{text:m;color:"#f8fafc";Layout.fillWidth:true;elide:Text.ElideRight}Text{text:u;color:"#f8fafc";Layout.fillWidth:true;elide:Text.ElideRight}Text{text:res;color:sev==="ERROR"?"#ef4444":sev==="REVIEW"?"#f59e0b":"#22c55e";font.bold:true;Layout.preferredWidth:130}}}}}}
  }
 }
}
