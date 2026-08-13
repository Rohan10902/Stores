import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"
import "../theme"

Item {
    id: root
    readonly property var headers: ["Store Name","SID","Banner","Nielsen Store Code","Trip Received","Last Trip","Address 1","Address 2","City","State","Pincode","Phone"]
    readonly property var widths: [155,155,155,180,155,155,210,180,140,150,110,160]
    readonly property int tableWidth: 2025
    readonly property int minimumRows: 10
    property var rows: []
    property var selected: []
    property var findings: []
    property bool validated: false
    property bool validationPending: false
    property bool exporting: false
    property string destinationPath: ""
    property bool importPending: false
    property bool importPreviewVisible: false
    property string importSourcePath: ""
    property var importedHeaders: []
    property var importedRows: []
    property int importedTotal: 0
    property string importError: ""

    function blankRow() { var r=[]; for(var i=0;i<headers.length;i++) r.push(""); return r }
    function hasData(r) { if(!r)return false; for(var i=0;i<r.length;i++) if(String(r[i]||"").trim()!=="") return true; return false }
    function resetRows() { var r=[],s=[]; for(var i=0;i<minimumRows;i++){r.push(blankRow());s.push(true)}; rows=r;selected=s;findings=[];validated=false;validationPending=false }
    function invalidate(){validated=false;findings=[]}
    function setCell(r,c,v){var n=rows.slice(),x=n[r].slice();x[c]=v;n[r]=x;rows=n;invalidate()}
    function setSelected(i,v){var n=selected.slice();n[i]=v;selected=n;invalidate()}
    function addRow(){var r=rows.slice(),s=selected.slice();r.push(blankRow());s.push(true);rows=r;selected=s;invalidate()}
    function selectAll(v){var s=[];for(var i=0;i<rows.length;i++)s.push(v);selected=s;invalidate()}
    function deleteSelected(){var r=[],s=[];for(var i=0;i<rows.length;i++)if(!selected[i]){r.push(rows[i]);s.push(false)}while(r.length<minimumRows){r.push(blankRow());s.push(true)}rows=r;selected=s;invalidate()}
    function enteredCount(){var n=0;for(var i=0;i<rows.length;i++)if(hasData(rows[i]))n++;return n}
    function includedCount(){var n=0;for(var i=0;i<rows.length;i++)if(selected[i]&&hasData(rows[i]))n++;return n}
    function validationJson(){var out=[];for(var r=0;r<rows.length;r++){if(!selected[r]||!hasData(rows[r]))continue;var o={};for(var c=0;c<headers.length;c++)o[headers[c]]=String(rows[r][c]||"").trim();out.push(o)}return JSON.stringify(out)}
    function validateRows(){if(!includedCount()||validationPending)return;validationPending=true;validated=false;findings=[];if(typeof backend!=="undefined"&&backend.creator!==undefined)backend.creator.validate_creator(validationJson())}
    function urlToPath(v){try{if(v&&v.toLocalFile)return v.toLocalFile()}catch(e){}var t=String(v||"");if(t.indexOf("file:///")===0)t=t.substring(8);if(Qt.platform.os==="windows")t=t.replace(/^\/+/,"");try{return decodeURIComponent(t)}catch(e2){return t}}
    function norm(v){return String(v||"").trim().toLowerCase().replace(/[_-]+/g," ").replace(/\s+/g," ")}
    function mapIndex(v){var h=norm(v),a=[["store name","store","name"],["sid","store id","storeid","store code","id"],["banner","brand"],["nielsen store code","nielsen code","nielsen store","nielsen"],["trip received"],["last trip"],["address 1","address1","address","addr","street"],["address 2","address2"],["city","town"],["state","province"],["pincode","pin code","postal code","zip","zipcode"],["phone","mobile","contact","telephone"]];for(var i=0;i<a.length;i++)for(var j=0;j<a[i].length;j++)if(h===norm(a[i][j]))return i;return -1}
    function loadImported(){var out=[],sel=[];for(var r=0;r<importedRows.length;r++){var src=importedRows[r]||[],dst=blankRow();for(var c=0;c<importedHeaders.length;c++){var k=mapIndex(importedHeaders[c]);if(k>=0)dst[k]=String(src[c]===undefined?"":src[c]).trim()}if(hasData(dst)){out.push(dst);sel.push(true)}}while(out.length<minimumRows){out.push(blankRow());sel.push(true)}rows=out;selected=sel;invalidate();importPreviewVisible=false}
    function parsePaste(t){var x=String(t||"").replace(/\r\n/g,"\n").replace(/\r/g,"\n");if(!x.trim())return[];var d=x.indexOf("\t")>=0?"\t":",",out=[],r=[],cell="",q=false;for(var i=0;i<x.length;i++){var ch=x.charAt(i);if(ch==='"'){if(q&&x.charAt(i+1)==='"'){cell+='"';i++}else q=!q}else if(ch===d&&!q){r.push(cell);cell=""}else if(ch==='\n'&&!q){r.push(cell);out.push(r);r=[];cell=""}else cell+=ch}if(cell!==""||r.length){r.push(cell);out.push(r)}return q?[]:out}
    function importPaste(t){var p=parsePaste(t);if(!p.length)return;var first=p[0].map(function(v){return String(v).toLowerCase()}).join("|");if(first.indexOf("store name")>=0||first.indexOf("nielsen store code")>=0)p.shift();var r=rows.slice(),s=selected.slice(),cursor=0;for(var i=0;i<p.length;i++){while(cursor<r.length&&hasData(r[cursor]))cursor++;if(cursor>=r.length){r.push(blankRow());s.push(true)}for(var c=0;c<headers.length&&c<p[i].length;c++)r[cursor][c]=String(p[i][c]).trim();s[cursor]=true;cursor++}rows=r;selected=s;invalidate();pasteDialog.close()}
    function exportRows(){if(!validated||findings.length||!includedCount()||exporting)return;var out=[];for(var i=0;i<rows.length;i++)if(selected[i]&&hasData(rows[i]))out.push(rows[i]);exporting=true;if(typeof backend!=="undefined"&&backend.creator!==undefined)backend.creator.export_builder_file(JSON.stringify(out),destinationPath,JSON.stringify(headers))}

    Component.onCompleted: resetRows()

    FileDialog{id:importDialog;title:"Import Store Dataset";fileMode:FileDialog.OpenFile;nameFilters:["Store Data (*.csv *.tsv *.txt *.xlsx *.xls *.xlsm *.json *.xml)","All Files (*)"];onAccepted:{importSourcePath=urlToPath(selectedFile);importPending=true;importPreviewVisible=true;importError="Loading file...";importedHeaders=[];importedRows=[];importedTotal=0;if(typeof backend!=="undefined"&&backend.creator!==undefined)backend.creator.load_creator_file(importSourcePath)}}
    FileDialog{id:exportDialog;title:"Export Store Builder CSV";fileMode:FileDialog.SaveFile;currentFile:"store_builder.csv";nameFilters:["CSV Files (*.csv)","All Files (*)"];onAccepted:{destinationPath=urlToPath(selectedFile);exportRows()}}
    Dialog{id:pasteDialog;title:"Paste Stores";modal:true;width:Math.min(root.width-80,900);height:Math.min(root.height-100,600);standardButtons:Dialog.Cancel;ColumnLayout{anchors.fill:parent;anchors.margins:Theme.spacingMedium;Text{text:"Paste tab-separated or comma-separated rows. Quoted CSV values are preserved.";color:Theme.textSecondary;Layout.fillWidth:true;wrapMode:Text.WordWrap};TextArea{id:pasteArea;Layout.fillWidth:true;Layout.fillHeight:true;placeholderText:"Store Name\tSID\tBanner\tNielsen Store Code";color:Theme.textPrimary;background:Rectangle{color:Theme.background;border.color:Theme.border}};PrimaryButton{text:"Import Stores";onClicked:root.importPaste(pasteArea.text)}}}

    Connections{target:typeof backend!=="undefined"&&backend.creator!==undefined?backend.creator:null;ignoreUnknownSignals:true
        function onCreatorLoaded(p){importPending=false;try{var d=JSON.parse(p||"{}");importedHeaders=d.headers||[];importedRows=d.rows||[];importedTotal=Number(d.total||importedRows.length||0);importError=String(d.error||"");if(!importedHeaders.length&&!importError)importError="No header row was detected."}catch(e){importedHeaders=[];importedRows=[];importedTotal=0;importError=String(e)}}
        function onCreatorReady(p){try{var d=JSON.parse(p||"{}");findings=d.findings||[];validated=true}catch(e){findings=[{row:0,field:"SYSTEM",message:String(e),severity:"ERROR"}];validated=true}validationPending=false}
        function onBuilderExported(){exporting=false;destinationPath=""}
    }

    ScrollView{anchors.fill:parent;clip:true;contentWidth:availableWidth;ScrollBar.vertical.policy:ScrollBar.AsNeeded
        ColumnLayout{width:parent.width;spacing:Theme.spacingLarge
            PageTitle{Layout.fillWidth:true;Layout.leftMargin:Theme.spacingXLarge;Layout.rightMargin:Theme.spacingXLarge;Layout.topMargin:Theme.spacingLarge;title:"Store Builder";subtitle:"Build, import, validate and export store records in one canonical spreadsheet workspace."}
            Card{Layout.fillWidth:true;Layout.leftMargin:Theme.spacingXLarge;Layout.rightMargin:Theme.spacingXLarge;Layout.preferredHeight:82;RowLayout{anchors.fill:parent;anchors.margins:Theme.spacingSmall;spacing:7
                PrimaryButton{text:importPending?"Importing...":"Import Store File";enabled:!importPending;onClicked:importDialog.open()}
                AppButton{text:"Paste Stores";onClicked:{pasteArea.clear();pasteDialog.open()}}
                AppButton{text:"+ Add Row";onClicked:addRow()};AppButton{text:"Select All";onClicked:selectAll(true)};AppButton{text:"Deselect All";onClicked:selectAll(false)};AppButton{text:"Delete Selected";onClicked:deleteSelected()};AppButton{text:"Clear";onClicked:resetRows()};Item{Layout.fillWidth:true};Text{text:enteredCount()+" entered • "+includedCount()+" included";color:Theme.textPrimary;font.bold:true};AppButton{text:validationPending?"Validating...":"Validate";enabled:enteredCount()>0&&!validationPending;onClicked:validateRows()};PrimaryButton{text:exporting?"Exporting...":"Export CSV";enabled:includedCount()>0&&validated&&!findings.length&&!validationPending&&!exporting;onClicked:exportDialog.open()}
            }}
            Card{visible:importPreviewVisible;Layout.fillWidth:true;Layout.leftMargin:Theme.spacingXLarge;Layout.rightMargin:Theme.spacingXLarge;Layout.preferredHeight:330;ColumnLayout{anchors.fill:parent;anchors.margins:Theme.spacingMedium;RowLayout{Layout.fillWidth:true;Text{text:"Imported File Preview";color:Theme.textPrimary;font.pixelSize:15;font.bold:true;Layout.fillWidth:true};Text{text:importedTotal+" records • "+importedHeaders.length+" columns";color:Theme.textSecondary};AppButton{text:"Choose Another";onClicked:importDialog.open()};PrimaryButton{text:"Load into Builder";enabled:importedHeaders.length>0&&!importPending;onClicked:loadImported()};AppButton{text:"Hide";onClicked:importPreviewVisible=false}};Text{visible:importError!=="";text:importError;color:Theme.error;Layout.fillWidth:true;wrapMode:Text.WordWrap};Rectangle{visible:importError===""&&importedHeaders.length>0;Layout.fillWidth:true;Layout.fillHeight:true;color:Theme.background;border.color:Theme.border;clip:true;Flickable{anchors.fill:parent;clip:true;contentWidth:Math.max(width,importedHeaders.length*165);contentHeight:importTable.height;ScrollBar.vertical:ScrollBar{};ScrollBar.horizontal:ScrollBar{};Column{id:importTable;width:Math.max(parent.width,importedHeaders.length*165);Rectangle{width:importTable.width;height:40;color:Theme.surfaceHover;Row{anchors.fill:parent;Repeater{model:importedHeaders;delegate:Rectangle{required property string modelData;width:165;height:40;border.color:Theme.border;Text{anchors.fill:parent;anchors.margins:7;text:modelData;color:Theme.textPrimary;font.bold:true;font.pixelSize:10;elide:Text.ElideRight;verticalAlignment:Text.AlignVCenter}}}}};Repeater{model:Math.min(10,importedRows.length);delegate:Rectangle{required property int index;width:importTable.width;height:30;color:index%2===0?Theme.background:Theme.surface;border.color:Theme.border;Row{anchors.fill:parent;Repeater{model:importedHeaders.length;delegate:Rectangle{required property int index;width:165;height:30;border.color:Theme.border;Text{anchors.fill:parent;anchors.margins:7;text:importedRows[parent.parent.parent.index][index]===undefined?"":String(importedRows[parent.parent.parent.index][index]);color:Theme.textPrimary;font.pixelSize:10;elide:Text.ElideRight;verticalAlignment:Text.AlignVCenter}}}}}}}}}}
            }}
            Card{Layout.fillWidth:true;Layout.fillHeight:true;Layout.minimumHeight:600;Layout.leftMargin:Theme.spacingXLarge;Layout.rightMargin:Theme.spacingXLarge;Layout.bottomMargin:Theme.spacingXLarge;ScrollView{anchors.fill:parent;anchors.margins:8;clip:true;ScrollBar.horizontal.policy:ScrollBar.AsNeeded;ScrollBar.vertical.policy:ScrollBar.AsNeeded;Column{width:root.tableWidth
                Rectangle{width:root.tableWidth;height:42;color:Theme.surfaceElevated;border.color:Theme.border;Row{anchors.fill:parent;Rectangle{width:120;height:42;border.color:Theme.border;Text{anchors.fill:parent;anchors.margins:8;text:"USE / ROW";color:Theme.textPrimary;font.bold:true;verticalAlignment:Text.AlignVCenter}};Repeater{model:headers;delegate:Rectangle{required property string modelData;width:widths[index];height:42;border.color:Theme.border;Text{anchors.fill:parent;anchors.margins:8;text:modelData;color:Theme.textPrimary;font.bold:true;font.pixelSize:11;elide:Text.ElideRight;verticalAlignment:Text.AlignVCenter}}}}}
                Repeater{model:rows.length;delegate:Rectangle{required property int index;width:root.tableWidth;height:38;color:index%2===0?Theme.background:Theme.surface;border.color:Theme.border;Row{anchors.fill:parent;Rectangle{width:120;height:38;border.color:Theme.border;RowLayout{anchors.fill:parent;anchors.leftMargin:7;Rectangle{width:27;height:27;border.color:Theme.border;Text{anchors.centerIn:parent;text:selected[index]?"✓":"";color:Theme.textPrimary;font.pixelSize:20};MouseArea{anchors.fill:parent;onClicked:setSelected(index,!selected[index])}};Text{text:index+1;color:Theme.textSecondary}}};Repeater{model:headers.length;delegate:Rectangle{required property int index;width:widths[index];height:38;border.color:Theme.border;TextField{anchors.fill:parent;anchors.margins:1;text:rows[parent.parent.parent.index][index];color:Theme.textPrimary;font.pixelSize:11;selectByMouse:true;background:Rectangle{color:"transparent";border.color:parent.activeFocus?Theme.primary:"transparent"};onEditingFinished:setCell(parent.parent.parent.index,index,text)}}}}}}
            }}}
            Card{visible:findings.length>0;Layout.fillWidth:true;Layout.leftMargin:Theme.spacingXLarge;Layout.rightMargin:Theme.spacingXLarge;Layout.bottomMargin:Theme.spacingXLarge;Layout.preferredHeight:Math.min(240,70+findings.length*34);ColumnLayout{anchors.fill:parent;anchors.margins:Theme.spacingMedium;Text{text:"Validation Findings";color:Theme.textPrimary;font.bold:true};ListView{Layout.fillWidth:true;Layout.fillHeight:true;model:findings;delegate:Text{required property var modelData;width:ListView.view.width;text:"Row "+modelData.row+" • "+modelData.field+": "+modelData.message;color:Theme.error;elide:Text.ElideRight}}}}
        }
    }
}
