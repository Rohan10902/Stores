import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"
Item{
 property string src:"";property var cols:[];property var resultCols:[];ListModel{id:table}
 FileDialog{id:fd;nameFilters:["Data (*.csv *.xlsx *.xls *.xlsm *.txt *.tsv *.json *.xml)"];onAccepted:{src=selectedFile.toString();backend.loadData(src)}}
 Connections{target:backend
  function onHealthReady(p){var d=JSON.parse(p);cols=d.columnNames;searchCol.model=["All columns"].concat(cols)}
  function onTableReady(p){var d=JSON.parse(p);resultCols=d.columns;table.clear();for(var i=0;i<d.rows.length;i++)table.append({vals:d.rows[i]});info.text=d.total+" row(s), first 1,000 displayed"}
 }
 ColumnLayout{anchors.fill:parent;anchors.margins:22;spacing:10;PageTitle{text:"Explore & Analyze"}RowLayout{Layout.fillWidth:true;Text{text:src||"No dataset loaded";color:"#94a3b8";Layout.fillWidth:true}PrimaryButton{text:"Load Dataset";onClicked:fd.open()}}
  Card{Layout.fillWidth:true;implicitHeight:150;ColumnLayout{anchors.fill:parent;anchors.margins:10;RowLayout{TextField{id:search;placeholderText:"Search records...";Layout.fillWidth:true}ComboBox{id:searchCol;Layout.preferredWidth:220}PrimaryButton{text:"Search";enabled:src!=="";onClicked:backend.search(search.text,searchCol.currentIndex<=0?"":searchCol.currentText)}}RowLayout{TextArea{id:sql;text:"SELECT * FROM data LIMIT 100";color:"#f8fafc";Layout.fillWidth:true;Layout.preferredHeight:65;background:Rectangle{color:"#071321";border.width:1;border.color:"#263850";radius:6}}PrimaryButton{text:"Run SQL";enabled:src!=="";onClicked:backend.sql(sql.text)}}}}
  Card{Layout.fillWidth:true;Layout.fillHeight:true;ColumnLayout{anchors.fill:parent;anchors.margins:9;RowLayout{Text{text:"Result Table";color:"#f8fafc";font.bold:true}Item{Layout.fillWidth:true}Text{id:info;text:"0 rows";color:"#94a3b8"}}Flickable{id:f;Layout.fillWidth:true;Layout.fillHeight:true;clip:true;contentWidth:Math.max(width,resultCols.length*180);contentHeight:col.height;Column{id:col;width:f.contentWidth;Row{height:34;Repeater{model:resultCols;delegate:Rectangle{required property var modelData;width:180;height:34;color:"#132238";Text{anchors.fill:parent;anchors.margins:6;text:String(modelData);color:"#94a3b8";font.bold:true;elide:Text.ElideRight}}}}Repeater{model:table;delegate:Rectangle{required property int index;required property var vals;width:col.width;height:32;color:index%2?"#0d1b2e":"#0b1829";Row{anchors.fill:parent;Repeater{model:vals;delegate:Rectangle{required property var modelData;width:180;height:32;color:"transparent";border.width:1;border.color:"#17283d";Text{anchors.fill:parent;anchors.margins:5;text:String(modelData===null?"":modelData);color:"#f8fafc";font.pixelSize:10;elide:Text.ElideRight}}}}}}}ScrollBar.vertical: ScrollBar {}
ScrollBar.horizontal: ScrollBar {}}}}
 }
}
