import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"
import "../theme"

Item {
    id: root
    readonly property var headers: ["Store Name", "SID", "Banner", "Nielsen Store Code", "Trip Received", "Last Trip", "Address 1", "Address 2", "City", "State", "Pincode", "Phone"]
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

    function blankRow() { var r=[]; for(var i=0;i<headers.length;++i) r.push(""); return r }
    function hasData(r) { if(!r)return false; for(var i=0;i<r.length;++i) if(String(r[i]||"").trim()!=="") return true; return false }
    function resetRows() { var r=[],s=[]; for(var i=0;i<minimumRows;++i){r.push(blankRow());s.push(true)} rows=r;selected=s;findings=[];validated=false;validationPending=false }
    function invalidate(){validated=false;findings=[]}
    function setCell(r,c,v){var n=rows.slice(),x=n[r].slice();x[c]=v;n[r]=x;rows=n;invalidate()}
    function setSelected(i,v){var n=selected.slice();n[i]=v;selected=n;invalidate()}
    function addRow(){var r=rows.slice(),s=selected.slice();r.push(blankRow());s.push(true);rows=r;selected=s;invalidate()}
    function selectAll(v){var s=[];for(var i=0;i<rows.length;++i)s.push(v);selected=s;invalidate()}
    function deleteSelected(){var r=[],s=[];for(var i=0;i<rows.length;++i)if(!selected[i]){r.push(rows[i]);s.push(false)}while(r.length<minimumRows){r.push(blankRow());s.push(true)}rows=r;selected=s;invalidate()}
    function enteredCount(){var n=0;for(var i=0;i<rows.length;++i)if(hasData(rows[i]))++n;return n}
    function includedCount(){var n=0;for(var i=0;i<rows.length;++i)if(selected[i]&&hasData(rows[i]))++n;return n}
    function validationJson(){var out=[];for(var r=0;r<rows.length;++r){if(!selected[r]||!hasData(rows[r]))continue;var o={};for(var c=0;c<headers.length;++c)o[headers[c]]=String(rows[r][c]||"").trim();out.push(o)}return JSON.stringify(out)}
    function validateRows(){if(!includedCount()||validationPending)return;validationPending=true;validated=false;findings=[];if(typeof backend!=="undefined"&&backend.creator!==undefined)backend.creator.validate_creator(validationJson())}
    function urlToPath(v){try{if(v&&v.toLocalFile)return v.toLocalFile()}catch(e){}var t=String(v||"");if(t.indexOf("file:///")===0)t=t.substring(8);else if(t.indexOf("file://")===0)t=t.substring(7);if(Qt.platform.os==="windows")t=t.replace(/^\/+/,"");try{return decodeURIComponent(t)}catch(e2){return t}}
    function exportRows(){if(!validated||findings.length||!includedCount()||exporting)return;var out=[];for(var i=0;i<rows.length;++i)if(selected[i]&&hasData(rows[i]))out.push(rows[i]);exporting=true;if(typeof backend!=="undefined"&&backend.creator!==undefined)backend.creator.export_builder_file(JSON.stringify(out),destinationPath,JSON.stringify(headers))}
    Component.onCompleted: resetRows()
    FileDialog { id: importDialog; title: "Import Store Dataset"; fileMode: FileDialog.OpenFile; nameFilters: ["Store Data (*.csv *.tsv *.txt *.xlsx *.xls *.xlsm *.json *.xml)", "All Files (*)"]; onAccepted: { var path=root.urlToPath(selectedFile); if(typeof backend!=="undefined"&&backend.creator!==undefined) backend.creator.load_creator_file(path) } }
    FileDialog { id: exportDialog; title: "Export Store Builder CSV"; fileMode: FileDialog.SaveFile; currentFile: "store_builder.csv"; nameFilters: ["CSV Files (*.csv)", "All Files (*)"]; onAccepted: { destinationPath=root.urlToPath(selectedFile); root.exportRows() } }
    Connections { target: typeof backend!=="undefined"&&backend.creator!==undefined?backend.creator:null; ignoreUnknownSignals:true; function onCreatorReady(p){try{var d=JSON.parse(p||"{}");findings=d.findings||[]}catch(e){findings=[{row:0,field:"SYSTEM",message:String(e),severity:"ERROR"}]}validated=true;validationPending=false} function onBuilderExported(){exporting=false;destinationPath=""} }
    ScrollView { anchors.fill:parent; clip:true; contentWidth:availableWidth; ScrollBar.vertical.policy:ScrollBar.AsNeeded
        ColumnLayout { width:parent.width; spacing:Theme.spacingLarge
            PageTitle { Layout.fillWidth:true; Layout.leftMargin:Theme.spacingXLarge; Layout.rightMargin:Theme.spacingXLarge; Layout.topMargin:Theme.spacingLarge; title:"Store Builder"; subtitle:"Build, validate and export store records in one canonical spreadsheet workspace." }
            Card { Layout.fillWidth:true; Layout.leftMargin:Theme.spacingXLarge; Layout.rightMargin:Theme.spacingXLarge; Layout.preferredHeight:82; RowLayout { anchors.fill:parent; anchors.margins:Theme.spacingSmall; spacing:7
                PrimaryButton { text:"Import Store File"; onClicked:importDialog.open() }
                AppButton { text:"+ Add Row"; onClicked:root.addRow() }
                AppButton { text:"Select All"; onClicked:root.selectAll(true) }
                AppButton { text:"Deselect All"; onClicked:root.selectAll(false) }
                AppButton { text:"Delete Selected"; onClicked:root.deleteSelected() }
                AppButton { text:"Clear"; onClicked:root.resetRows() }
                Item { Layout.fillWidth:true }
                Text { text:root.enteredCount()+" entered • "+root.includedCount()+" included"; color:Theme.textPrimary; font.bold:true }
                AppButton { text:root.validationPending?"Validating...":"Validate"; enabled:root.enteredCount()>0&&!root.validationPending; onClicked:root.validateRows() }
                PrimaryButton { text:root.exporting?"Exporting...":"Export CSV"; enabled:root.includedCount()>0&&root.validated&&root.findings.length===0&&!root.validationPending&&!root.exporting; onClicked:exportDialog.open() }
            } }
            Card { Layout.fillWidth:true; Layout.fillHeight:true; Layout.minimumHeight:600; Layout.leftMargin:Theme.spacingXLarge; Layout.rightMargin:Theme.spacingXLarge; Layout.bottomMargin:Theme.spacingXLarge
                ScrollView { anchors.fill:parent; anchors.margins:8; clip:true; ScrollBar.horizontal.policy:ScrollBar.AsNeeded; ScrollBar.vertical.policy:ScrollBar.AsNeeded
                    Column { width:root.tableWidth
                        Rectangle { width:root.tableWidth; height:42; color:Theme.surfaceHover; border.color:Theme.border; Row { anchors.fill:parent; Rectangle { width:120;height:42;border.color:Theme.border;Text{anchors.fill:parent;anchors.margins:8;text:"USE / ROW";color:Theme.textPrimary;font.bold:true;verticalAlignment:Text.AlignVCenter} } Repeater { model:root.headers; delegate:Rectangle { required property string modelData; width:root.widths[index];height:42;border.color:Theme.border;Text{anchors.fill:parent;anchors.margins:8;text:modelData;color:Theme.textPrimary;font.bold:true;elide:Text.ElideRight;verticalAlignment:Text.AlignVCenter} } } } }
                        Repeater { model:root.rows.length; delegate:Rectangle { required property int index; width:root.tableWidth;height:38;color:index%2===0?Theme.background:Theme.surface;border.color:Theme.border; Row { anchors.fill:parent; Rectangle { width:120;height:38;border.color:Theme.border;RowLayout{anchors.fill:parent;anchors.leftMargin:7;Rectangle{width:27;height:27;border.color:Theme.border;Text{anchors.centerIn:parent;text:root.selected[index]?"✓":"";color:Theme.textPrimary;font.pixelSize:20};MouseArea{anchors.fill:parent;onClicked:root.setSelected(index,!root.selected[index])}}Text{text:index+1;color:Theme.textSecondary}}} Repeater{model:root.headers.length;delegate:Rectangle{required property int index;width:root.widths[index];height:38;border.color:Theme.border;TextField{anchors.fill:parent;anchors.margins:1;text:root.rows[parent.parent.parent.index][index];color:Theme.textPrimary;font.pixelSize:11;selectByMouse:true;background:Rectangle{color:"transparent";border.color:parent.activeFocus?Theme.primary:"transparent"};onEditingFinished:root.setCell(parent.parent.parent.index,index,text)}}} } } }
                    }
                }
            }
            Card { visible:root.findings.length>0; Layout.fillWidth:true; Layout.leftMargin:Theme.spacingXLarge; Layout.rightMargin:Theme.spacingXLarge; Layout.bottomMargin:Theme.spacingXLarge; Layout.preferredHeight:Math.min(240,70+root.findings.length*34); ColumnLayout{anchors.fill:parent;anchors.margins:Theme.spacingMedium;Text{text:"Validation Findings";color:Theme.textPrimary;font.bold:true};ListView{Layout.fillWidth:true;Layout.fillHeight:true;model:root.findings;delegate:Text{required property var modelData;width:ListView.view.width;text:"Row "+modelData.row+" • "+modelData.field+": "+modelData.message;color:Theme.error;elide:Text.ElideRight}}} }
        }
    }
}
