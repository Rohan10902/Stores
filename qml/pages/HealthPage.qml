import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"
Item{
 property string src:"";property var cols:[];property var h:({});property var types:({});property var operations:({});property string insight:""
 ListModel{id:quality}ListModel{id:statsRows}
 FileDialog{id:fd;nameFilters:["Data (*.csv *.xlsx *.xls *.xlsm *.txt *.tsv *.json *.xml)"];onAccepted:{src=selectedFile.toString();statsRows.clear();insight="";backend.loadData(src)}}
 function refreshOps(){if(!statCol.currentText||!types[statCol.currentText]){op.model=[];return}op.model=operations[types[statCol.currentText]]||[]}
 Connections{target:backend
  function onHealthReady(p){var d=JSON.parse(p);h=d;cols=d.columnNames;types=d.columnTypes;operations=d.operations;quality.clear();statsRows.clear();insight="";for(var i=0;i<d.columnStats.length;i++){var r=d.columnStats[i];quality.append({c:String(r.column),t:String(r.type),b:String(r.blank),u:String(r.unique),n:String(r.nonBlank)})}statCol.model=cols;groupCol.model=["No grouping"].concat(cols);groupCol.currentIndex=0;refreshOps()}
  function onStatsReady(p){var d=JSON.parse(p);insight=String(d.insight||"");statsRows.clear();for(var i=0;i<d.rows.length;i++){var r=d.rows[i];statsRows.append({label:String(r.label||""),result:String(r.result===undefined||r.result===null?"":r.result),count:String(r.count===undefined||r.count===null?"":r.count),percent:String(r.percent===undefined||r.percent===null?"":r.percent),interp:String(r.interpretation||"")})}}
 }
 ColumnLayout{anchors.fill:parent;anchors.margins:22;spacing:10
  PageTitle{text:"Data Intelligence"}
  RowLayout{Layout.fillWidth:true;Text{text:src||"No dataset loaded";color:"#94a3b8";Layout.fillWidth:true;elide:Text.ElideMiddle}PrimaryButton{text:"Choose Dataset";onClicked:fd.open()}}
  RowLayout{Layout.fillWidth:true;Repeater{model:[["ROWS",h.rows||0],["COLUMNS",h.columns||0],["COMPLETENESS",(h.completeness||0)+"%"],["DUPLICATES",h.duplicateRows||0],["HEALTH",(h.score||0)+"/100"]];delegate:Card{required property var modelData;Layout.fillWidth:true;implicitHeight:60;Column{anchors.fill:parent;anchors.margins:8;Text{text:modelData[1];color:"#22c55e";font.pixelSize:18;font.bold:true}Text{text:modelData[0];color:"#94a3b8";font.pixelSize:9;font.bold:true}}}}}
  SplitView{Layout.fillWidth:true;Layout.fillHeight:true;orientation:Qt.Vertical
   Card{SplitView.minimumHeight:170;SplitView.preferredHeight:parent.height*.38;ColumnLayout{anchors.fill:parent;anchors.margins:10
    Text{text:"Column Quality";color:"#f8fafc";font.bold:true}
    RowLayout{Layout.fillWidth:true;Text{text:"Column";color:"#94a3b8";font.bold:true;Layout.fillWidth:true}Text{text:"Type";color:"#94a3b8";font.bold:true;Layout.preferredWidth:110}Text{text:"Non-blank";color:"#94a3b8";font.bold:true;Layout.preferredWidth:100}Text{text:"Blank";color:"#94a3b8";font.bold:true;Layout.preferredWidth:90}Text{text:"Unique";color:"#94a3b8";font.bold:true;Layout.preferredWidth:90}}
    ListView{Layout.fillWidth:true;Layout.fillHeight:true;model:quality;clip:true;delegate:Rectangle{required property int index;required property string c;required property string t;required property string b;required property string u;required property string n;width:ListView.view.width;height:32;color:index%2?"#0d1b2e":"#0b1829";MouseArea{anchors.fill:parent;onClicked:{var ix=cols.indexOf(c);if(ix>=0)statCol.currentIndex=ix}}RowLayout{anchors.fill:parent;Text{text:c;color:"#f8fafc";Layout.fillWidth:true;leftPadding:6;elide:Text.ElideRight}Text{text:t;color:"#60a5fa";Layout.preferredWidth:110}Text{text:n;color:"#94a3b8";Layout.preferredWidth:100}Text{text:b;color:Number(b)>0?"#f59e0b":"#22c55e";Layout.preferredWidth:90}Text{text:u;color:"#94a3b8";Layout.preferredWidth:90}}}}}}
   Card{SplitView.minimumHeight:270;SplitView.fillHeight:true;ColumnLayout{anchors.fill:parent;anchors.margins:10
    RowLayout{Text{text:"Statistics Analysis";color:"#f8fafc";font.bold:true}Item{Layout.fillWidth:true}Text{text:statCol.currentText&&types[statCol.currentText]?"Detected type: "+types[statCol.currentText]:"";color:"#60a5fa"}}
    RowLayout{ComboBox{id:statCol;Layout.fillWidth:true;onCurrentTextChanged:refreshOps()}ComboBox{id:op;Layout.preferredWidth:220}ComboBox{id:groupCol;Layout.fillWidth:true}PrimaryButton{text:"Calculate";enabled:cols.length>0&&op.currentText!=="";onClicked:backend.stats(statCol.currentText,op.currentText,groupCol.currentIndex<=0?"":groupCol.currentText)}}
    Text{visible:groupCol.currentIndex>0;text:"Grouped analysis: "+op.currentText+" of "+statCol.currentText+" by "+groupCol.currentText;color:"#93c5fd";font.bold:true}
    Rectangle{visible:insight!=="";Layout.fillWidth:true;implicitHeight:52;radius:6;color:"#102a43";Text{anchors.fill:parent;anchors.margins:8;text:"Smart Insight: "+insight;color:"#bfdbfe";wrapMode:Text.WordWrap}}
    RowLayout{Layout.fillWidth:true;Text{text:groupCol.currentIndex>0?"Group":"Value / Metric";color:"#94a3b8";font.bold:true;Layout.preferredWidth:220}Text{text:"Result";color:"#94a3b8";font.bold:true;Layout.fillWidth:true}Text{text:"Records";color:"#94a3b8";font.bold:true;Layout.preferredWidth:100}Text{text:"% of Records";color:"#94a3b8";font.bold:true;Layout.preferredWidth:110}Text{text:"Interpretation";color:"#94a3b8";font.bold:true;Layout.preferredWidth:160}}
    ListView{Layout.fillWidth:true;Layout.fillHeight:true;model:statsRows;clip:true;delegate:Rectangle{required property int index;required property string label;required property string result;required property string count;required property string percent;required property string interp;width:ListView.view.width;height:34;color:index%2?"#0d1b2e":"#0b1829";RowLayout{anchors.fill:parent;Text{text:label;color:"#f8fafc";Layout.preferredWidth:220;leftPadding:6;elide:Text.ElideRight}Text{text:result;color:"#22c55e";Layout.fillWidth:true;elide:Text.ElideRight}Text{text:count;color:"#94a3b8";Layout.preferredWidth:100}Text{text:percent?percent+"%":"";color:"#94a3b8";Layout.preferredWidth:110}Text{text:interp;color:"#60a5fa";Layout.preferredWidth:160;elide:Text.ElideRight}}}}}}
  }
 }
}