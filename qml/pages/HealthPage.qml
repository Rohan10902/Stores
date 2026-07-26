import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"
Item{
 property string src:"";property var cols:[];property var h:({});ListModel{id:quality}ListModel{id:statsRows}
 FileDialog{id:fd;nameFilters:["Data (*.csv *.xlsx *.xls *.xlsm *.txt *.tsv *.json *.xml)"];onAccepted:{src=selectedFile.toString();backend.loadData(src)}}
 Connections{target:backend
  function onHealthReady(p){var d=JSON.parse(p);h=d;cols=d.columnNames;quality.clear();for(var i=0;i<d.columnStats.length;i++){var r=d.columnStats[i];quality.append({c:String(r.column),b:String(r.blank),u:String(r.unique),n:String(r.numericCount)})}statCol.model=cols;groupCol.model=["(No grouping)"].concat(cols)}
  function onStatsReady(p){var d=JSON.parse(p);statsRows.clear();for(var i=0;i<d.length;i++)statsRows.append({g:String(d[i].group),v:String(d[i].value)})}
 }
 ColumnLayout{anchors.fill:parent;anchors.margins:22;spacing:10;PageTitle{text:"Data Health & Statistics"}RowLayout{Layout.fillWidth:true;Text{text:src||"No dataset loaded";color:"#94a3b8";Layout.fillWidth:true;elide:Text.ElideMiddle}PrimaryButton{text:"Choose Dataset";onClicked:fd.open()}}
  RowLayout{Layout.fillWidth:true;Repeater{model:[["ROWS",h.rows||0],["COLUMNS",h.columns||0],["COMPLETENESS",(h.completeness||0)+"%"],["HEALTH SCORE",(h.score||0)+"/100"]];delegate:Card{required property var modelData;Layout.fillWidth:true;implicitHeight:72;Column{anchors.fill:parent;anchors.margins:10;Text{text:modelData[1];color:"#22c55e";font.pixelSize:20;font.bold:true}Text{text:modelData[0];color:"#94a3b8";font.pixelSize:9;font.bold:true}}}}}
  Card{Layout.fillWidth:true;Layout.preferredHeight:270;ColumnLayout{anchors.fill:parent;anchors.margins:10;Text{text:"Column Quality";color:"#f8fafc";font.bold:true}ListView{Layout.fillWidth:true;Layout.fillHeight:true;model:quality;clip:true;delegate:Rectangle{required property int index;required property string c;required property string b;required property string u;required property string n;width:ListView.view.width;height:31;color:index%2?"#0d1b2e":"#0b1829";RowLayout{anchors.fill:parent;Text{text:c;color:"#f8fafc";Layout.fillWidth:true;leftPadding:6}Text{text:"Blank "+b;color:"#f59e0b";Layout.preferredWidth:110}Text{text:"Unique "+u;color:"#94a3b8";Layout.preferredWidth:120}Text{text:"Numeric "+n;color:"#94a3b8";Layout.preferredWidth:120}}}}}}
  Card{Layout.fillWidth:true;Layout.fillHeight:true;ColumnLayout{anchors.fill:parent;anchors.margins:10;Text{text:"Statistics Builder";color:"#f8fafc";font.bold:true}RowLayout{ComboBox{id:statCol;Layout.fillWidth:true}ComboBox{id:op;model:["Count","Distinct Count","Blank Count","Sum","Average","Minimum","Maximum","Median"];Layout.preferredWidth:170}ComboBox{id:groupCol;Layout.fillWidth:true}PrimaryButton{text:"Calculate";enabled:cols.length>0;onClicked:backend.stats(statCol.currentText,op.currentText,groupCol.currentIndex<=0?"":groupCol.currentText)}}ListView{Layout.fillWidth:true;Layout.fillHeight:true;model:statsRows;delegate:Rectangle{required property int index;required property string g;required property string v;width:ListView.view.width;height:31;color:index%2?"#0d1b2e":"#0b1829";RowLayout{anchors.fill:parent;Text{text:g;color:"#f8fafc";Layout.fillWidth:true;leftPadding:6}Text{text:v;color:"#22c55e";Layout.fillWidth:true}}}}}}
 }
}
