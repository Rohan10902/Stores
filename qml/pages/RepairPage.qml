import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"

Item {
    property string src:""
    property var audit: ({})
    property int selected: -1
    ListModel { id: issues }
    ListModel { id: preview }

    FileDialog {
        id: openDlg
        nameFilters:["CSV / Text (*.csv *.txt *.tsv)"]
        onAccepted:{ src=selectedFile.toString(); selected=-1; preview.clear(); backend.inspectRepair(src) }
    }
    FileDialog {
        id: saveDlg; fileMode:FileDialog.SaveFile; nameFilters:["CSV (*.csv)"]
        onAccepted:backend.repair(src,selectedFile.toString())
    }

    function showIssue(i) {
        selected=i; preview.clear()
        if (i<0 || i>=issues.count) return
        var cols=JSON.parse(issues.get(i).columnsJson)
        for(var j=0;j<cols.length;j++) preview.append({
            field:String(cols[j].field), before:String(cols[j].before), after:String(cols[j].after), state:String(cols[j].status)
        })
    }

    Connections {
        target:backend
        function onRepairReady(p) {
            var d=JSON.parse(p); audit=d; issues.clear(); preview.clear(); selected=-1
            for(var i=0;i<d.issues.length;i++) {
                var r=d.issues[i]
                issues.append({
                    line:String(r.line), status:String(r.status), problem:String(r.problem),
                    repair:String(r.repair), expected:String(r.expectedColumns), actual:String(r.actualColumns),
                    original:String(r.original), proposed:String(r.proposed), confidence:String(r.confidence),
                    columnsJson:JSON.stringify(r.columns)
                })
            }
            if(issues.count>0) showIssue(0)
        }
    }

    ColumnLayout {
        anchors.fill:parent; anchors.margins:22; spacing:10
        PageTitle { text:"Repair CSV / Text" }
        Text { text:"Auditable reconstruction. The original file is never overwritten and ambiguous data is never silently deleted."; color:"#94a3b8" }

        Card {
            Layout.fillWidth:true; implicitHeight:80
            RowLayout {
                anchors.fill:parent; anchors.margins:12
                TextField { Layout.fillWidth:true; readOnly:true; text:src; placeholderText:"CSV / TXT / TSV" }
                AppButton { text:"Choose File"; onClicked:openDlg.open() }
                PrimaryButton { text:audit.unresolved>0?"Save Reviewed Copy":"Save Repaired Copy"; enabled:src!==""; onClicked:saveDlg.open() }
            }
        }

        RowLayout {
            Layout.fillWidth:true
            Repeater {
                model:[
                    ["RECORDS",audit.records||0,"#3b82f6"],
                    ["EXPECTED COLUMNS",audit.expected||0,"#3b82f6"],
                    ["HEALTHY",audit.healthy||0,"#22c55e"],
                    ["AUTO FIXED",audit.autoFixed||0,"#22c55e"],
                    ["UNRESOLVED",audit.unresolved||0,audit.unresolved>0?"#ef4444":"#22c55e"]
                ]
                delegate:Card {
                    required property var modelData
                    Layout.fillWidth:true; implicitHeight:65
                    Column {
                        anchors.fill:parent; anchors.margins:9
                        Text { text:modelData[1]; color:modelData[2]; font.pixelSize:19; font.bold:true }
                        Text { text:modelData[0]; color:"#94a3b8"; font.pixelSize:9; font.bold:true }
                    }
                }
            }
        }

        Card {
            Layout.fillWidth:true; Layout.preferredHeight:220
            ColumnLayout {
                anchors.fill:parent; anchors.margins:10
                RowLayout {
                    Text { text:"Repair Audit — "+issues.count+" issue(s)"; color:"#f8fafc"; font.bold:true; Layout.fillWidth:true }
                    Text { visible:audit.unresolved>0; text:"⚠ "+(audit.unresolved||0)+" unresolved — manual review required"; color:"#ef4444"; font.bold:true }
                }
                RowLayout {
                    Layout.fillWidth:true
                    Text { text:"Line"; color:"#94a3b8"; font.bold:true; Layout.preferredWidth:80 }
                    Text { text:"Status"; color:"#94a3b8"; font.bold:true; Layout.preferredWidth:120 }
                    Text { text:"Problem"; color:"#94a3b8"; font.bold:true; Layout.fillWidth:true }
                    Text { text:"Expected"; color:"#94a3b8"; font.bold:true; Layout.preferredWidth:80 }
                    Text { text:"Found"; color:"#94a3b8"; font.bold:true; Layout.preferredWidth:70 }
                    Text { text:"Confidence"; color:"#94a3b8"; font.bold:true; Layout.preferredWidth:100 }
                }
                ListView {
                    Layout.fillWidth:true; Layout.fillHeight:true; model:issues; clip:true
                    delegate:Rectangle {
                        required property int index; required property string line; required property string status
                        required property string problem; required property string expected; required property string actual
                        required property string confidence
                        width:ListView.view.width; height:36
                        color:selected===index?"#17375f":status==="UNRESOLVED"?"#421820":"#113426"
                        MouseArea { anchors.fill:parent; onClicked:showIssue(index) }
                        RowLayout {
                            anchors.fill:parent
                            Text { text:line; color:"#f8fafc"; Layout.preferredWidth:80; leftPadding:6 }
                            Text { text:status; color:status==="UNRESOLVED"?"#ef4444":"#22c55e"; font.bold:true; Layout.preferredWidth:120 }
                            Text { text:problem; color:"#f8fafc"; Layout.fillWidth:true; elide:Text.ElideRight }
                            Text { text:expected; color:"#94a3b8"; Layout.preferredWidth:80 }
                            Text { text:actual; color:expected===actual?"#22c55e":"#ef4444"; Layout.preferredWidth:70 }
                            Text { text:confidence; color:confidence==="HIGH"?"#22c55e":"#f59e0b"; Layout.preferredWidth:100 }
                        }
                    }
                }
            }
        }

        Card {
            Layout.fillWidth:true; Layout.fillHeight:true
            ColumnLayout {
                anchors.fill:parent; anchors.margins:10
                Text { text:"Repair Preview"; color:"#f8fafc"; font.bold:true }
                Text {
                    visible:selected>=0
                    text:selected>=0 ? issues.get(selected).repair : "Select an issue to inspect it."
                    color:selected>=0 && issues.get(selected).status==="UNRESOLVED"?"#f59e0b":"#94a3b8"
                    wrapMode:Text.WordWrap; Layout.fillWidth:true
                }
                RowLayout {
                    visible:selected>=0; Layout.fillWidth:true
                    Text { text:"Field"; color:"#94a3b8"; font.bold:true; Layout.preferredWidth:210 }
                    Text { text:"Detected / Before"; color:"#94a3b8"; font.bold:true; Layout.fillWidth:true }
                    Text { text:"Proposed / After"; color:"#94a3b8"; font.bold:true; Layout.fillWidth:true }
                    Text { text:"Result"; color:"#94a3b8"; font.bold:true; Layout.preferredWidth:130 }
                }
                ListView {
                    Layout.fillWidth:true; Layout.fillHeight:true; model:preview; clip:true
                    delegate:Rectangle {
                        required property int index; required property string field; required property string before
                        required property string after; required property string state
                        width:ListView.view.width; height:34
                        color:state==="EXTRA"||state==="MISSING"?"#421820":state==="RECONSTRUCTED"?"#113426":index%2?"#0d1b2e":"#0b1829"
                        RowLayout {
                            anchors.fill:parent
                            Text { text:field; color:"#f8fafc"; font.bold:true; Layout.preferredWidth:210; leftPadding:6; elide:Text.ElideRight }
                            Text { text:before; color:"#f8fafc"; Layout.fillWidth:true; elide:Text.ElideRight }
                            Text { text:after; color:"#f8fafc"; Layout.fillWidth:true; elide:Text.ElideRight }
                            Text { text:state; color:state==="EXTRA"||state==="MISSING"?"#ef4444":state==="RECONSTRUCTED"?"#22c55e":"#94a3b8"; font.bold:true; Layout.preferredWidth:130 }
                        }
                    }
                }
            }
        }
    }
}
