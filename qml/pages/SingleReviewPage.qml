import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"

Item {
 id: page
 property string src:""
 property int total:0
 property int issueCount:0
 property int suggestedWidth:0
 property int previewChanged:0
 property int previewUnchanged:0
 property bool previewAvailable:false
 ListModel{id:findings}
 ListModel{id:nielsenPreview}
 FileDialog{id:openDlg;nameFilters:["Data (*.csv *.xlsx *.xls *.xlsm *.txt *.tsv *.json *.xml)"];onAccepted:{src=selectedFile.toString();backend.reviewSingleFile(src)}}
 FileDialog{id:saveDlg;fileMode:FileDialog.SaveFile;nameFilters:["CSV (*.csv)"];onAccepted:backend.exportSingleReview(src,selectedFile.toString())}
 Connections {
  target:backend
  function onSingleReviewReady(p){var d=JSON.parse(p);total=d.total||0;issueCount=d.issueCount||0;suggestedWidth=d.suggestedNielsenWidth||0;findings.clear();for(var i=0;i<d.rows.length;i++){var r=d.rows[i];if(r.issues.length)findings.append({row:String(r.row),severity:String(r.severity),problem:r.issues.join("; ")})}}
  function onNielsenPreviewReady(p){var d=JSON.parse(p);nielsenPreview.clear();previewChanged=d.changed||0;previewUnchanged=d.unchanged||0;previewAvailable=(d.rows&&d.rows.length>0);if(d.rows){for(var i=0;i<d.rows.length;i++){var r=d.rows[i];nielsenPreview.append({row:String(r.row),current:String(r.current),proposed:String(r.proposed),status:String(r.status)})}}}
 }
 ColumnLayout {anchors.fill:parent;anchors.margins:22;spacing:10
  PageTitle{text:"Review One File"}
  Text{text:"Review a dataset without a Master file. Source data remains unchanged until you export a reviewed copy.";color:"#94a3b8"}
  Card {Layout.fillWidth:true;implicitHeight:72;RowLayout{anchors.fill:parent;anchors.margins:10
   TextField{Layout.fillWidth:true;readOnly:true;text:src;placeholderText:"Choose CSV / Excel / text file"}
   AppButton{text:"Choose File";onClicked:openDlg.open()}
   PrimaryButton{text:"Analyze";enabled:src!=="";onClicked:backend.reviewSingleFile(src)}
   AppButton{text:"Export Reviewed Copy";enabled:src!=="";onClicked:saveDlg.open()}
  }}
  RowLayout {Layout.fillWidth:true
   Card{Layout.fillWidth:true;implicitHeight:62;Column{anchors.fill:parent;anchors.margins:8;Text{text:total;color:"#22c55e";font.pixelSize:18;font.bold:true}Text{text:"RECORDS";color:"#94a3b8";font.pixelSize:9}}}
   Card{Layout.fillWidth:true;implicitHeight:62;Column{anchors.fill:parent;anchors.margins:8;Text{text:issueCount;color:issueCount?"#f59e0b":"#22c55e";font.pixelSize:18;font.bold:true}Text{text:"NEEDS ATTENTION";color:"#94a3b8";font.pixelSize:9}}}
   Card{Layout.fillWidth:true;implicitHeight:62;Column{anchors.fill:parent;anchors.margins:8;Text{text:suggestedWidth||"—";color:"#60a5fa";font.pixelSize:18;font.bold:true}Text{text:"NIELSEN WIDTH SUGGESTION";color:"#94a3b8";font.pixelSize:9}}}
  }
  Card {Layout.fillWidth:true;implicitHeight:82;RowLayout{anchors.fill:parent;anchors.margins:10
   ColumnLayout{Layout.fillWidth:true;Text{text:"Nielsen Store Code leading zeros";color:"#f8fafc";font.bold:true}Text{text:"Preview first. Only all-digit codes are padded; the original source file is never changed.";color:"#94a3b8"}}
   SpinBox{id:widthBox;from:1;to:30;value:suggestedWidth||6;editable:true;onValueModified:previewAvailable=false}
   PrimaryButton{text:"Preview Padding";enabled:src!=="";onClicked:backend.previewSingleNielsen(widthBox.value)}
   AppButton{text:"Apply Preview";enabled:previewAvailable&&previewChanged>0;onClicked:{backend.applySingleNielsen();previewAvailable=false}}
  }}
  Card {visible:previewAvailable;Layout.fillWidth:true;implicitHeight:Math.min(245,72+nielsenPreview.count*34);ColumnLayout{anchors.fill:parent;anchors.margins:10;spacing:6
   RowLayout{Layout.fillWidth:true;Text{text:"Padding Preview";color:"#f8fafc";font.bold:true}Item{Layout.fillWidth:true}Text{text:previewChanged+" change • "+previewUnchanged+" unchanged";color:previewChanged?"#f59e0b":"#22c55e";font.bold:true}}
   RowLayout{Layout.fillWidth:true;Text{text:"Row";color:"#94a3b8";font.bold:true;Layout.preferredWidth:70}Text{text:"Current";color:"#94a3b8";font.bold:true;Layout.fillWidth:true}Text{text:"Proposed";color:"#94a3b8";font.bold:true;Layout.fillWidth:true}Text{text:"Status";color:"#94a3b8";font.bold:true;Layout.preferredWidth:100}}
   ListView{Layout.fillWidth:true;Layout.fillHeight:true;model:nielsenPreview;clip:true;delegate:Rectangle{width:ListView.view.width;height:32;color:index%2?"#0d1b2e":"#0b1829";RowLayout{anchors.fill:parent;Text{text:row;color:"#f8fafc";Layout.preferredWidth:70;leftPadding:6}Text{text:current;color:"#f8fafc";Layout.fillWidth:true}Text{text:proposed;color:status==="CHANGE"?"#60a5fa":"#f8fafc";font.bold:status==="CHANGE";Layout.fillWidth:true}Text{text:status;color:status==="CHANGE"?"#f59e0b":"#22c55e";font.bold:true;Layout.preferredWidth:100}}}}
  }}
  Card {Layout.fillWidth:true;Layout.fillHeight:true;ColumnLayout{anchors.fill:parent;anchors.margins:10
   Text{text:"Records Needing Attention";color:"#f8fafc";font.bold:true}
   RowLayout{Layout.fillWidth:true;Text{text:"Row";color:"#94a3b8";font.bold:true;Layout.preferredWidth:80}Text{text:"State";color:"#94a3b8";font.bold:true;Layout.preferredWidth:110}Text{text:"Finding";color:"#94a3b8";font.bold:true;Layout.fillWidth:true}}
   ListView{Layout.fillWidth:true;Layout.fillHeight:true;model:findings;clip:true;delegate:Rectangle{width:ListView.view.width;height:40;color:index%2?"#0d1b2e":"#0b1829";RowLayout{anchors.fill:parent;Text{text:row;color:"#f8fafc";Layout.preferredWidth:80;leftPadding:6}Text{text:severity;color:"#f59e0b";font.bold:true;Layout.preferredWidth:110}Text{text:problem;color:"#f8fafc";Layout.fillWidth:true;elide:Text.ElideRight}}}}
  }}
 }
}
