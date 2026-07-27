import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"

Item {
    id: page
    property var headers: ["Store Name","SID","Banner","Nielsen Store Code","Trip Received","Last Trip","Address 1","Address 2","Address 3","ZIP","Active / Inactive","Is Census","Is Exceptions","Updated By"]
    property int selectedRow: 0
    property int selectedCol: 0
    property int validationCount: 0
    property bool dirty: false
    ListModel { id: grid }
    ListModel { id: validation }
    Component.onCompleted: { for (var i = 0; i < 10; ++i) addBlank(false) }
    function blank(){var o={included:true};for(var i=0;i<headers.length;++i)o["c"+i]="";return o}
    function addBlank(mark){grid.append(blank());if(mark!==false)dirty=true}
    function rowHasData(r){for(var c=0;c<headers.length;++c)if(String(grid.get(r)["c"+c]||"").trim()!=="")return true;return false}
    function includedCount(){var n=0;for(var r=0;r<grid.count;++r)if(grid.get(r).included&&rowHasData(r))++n;return n}
    function populatedCount(){var n=0;for(var r=0;r<grid.count;++r)if(rowHasData(r))++n;return n}
    function selectedCount(){var n=0;for(var r=0;r<grid.count;++r)if(grid.get(r).included)++n;return n}
    function setAllIncluded(v){for(var r=0;r<grid.count;++r)grid.setProperty(r,"included",v);dirty=true}
    function deleteCheckedRows(){for(var r=grid.count-1;r>=0;--r)if(grid.get(r).included)grid.remove(r);if(grid.count===0)for(var i=0;i<10;++i)addBlank(false);selectedRow=Math.max(0,Math.min(selectedRow,grid.count-1));validation.clear();validationCount=0;dirty=true}
    function rowsJson(){var rows=[];for(var r=0;r<grid.count;++r){if(!grid.get(r).included||!rowHasData(r))continue;var row={};for(var c=0;c<headers.length;++c)row[headers[c]]=grid.get(r)["c"+c]||"";rows.push(row)}return JSON.stringify(rows)}
    function pasteText(t){if(!t)return;var lines=t.replace(/\r\n/g,"\n").replace(/\r/g,"\n").split("\n");if(lines.length&&lines[lines.length-1]==="")lines.pop();for(var r=0;r<lines.length;++r){var vals=lines[r].indexOf("\t")>=0?lines[r].split("\t"):lines[r].split(",");while(grid.count<=selectedRow+r)addBlank(false);grid.setProperty(selectedRow+r,"included",true);for(var c=0;c<vals.length&&selectedCol+c<headers.length;++c)grid.setProperty(selectedRow+r,"c"+(selectedCol+c),vals[c])}dirty=true;backend.say("Pasted "+lines.length+" row(s). Extra rows were created automatically.")}
    function clearAll(){grid.clear();for(var i=0;i<10;++i)addBlank(false);validation.clear();validationCount=0;dirty=false}
    function rowHasFinding(rr){for(var i=0;i<validation.count;i++)if(Number(validation.get(i).row)===rr+1)return true;return false}
    FileDialog{id:saveDlg;fileMode:FileDialog.SaveFile;nameFilters:["CSV (*.csv)"];onAccepted:{backend.exportCreator(rowsJson(),selectedFile.toString());dirty=false}}
    Connections{target:backend;function onCreatorReady(payload){var d=JSON.parse(payload);validationCount=d.count;validation.clear();for(var i=0;i<d.findings.length;++i){var x=d.findings[i];validation.append({row:String(x.row),field:String(x.field),message:String(x.message)})}}}

    ColumnLayout {
        anchors.fill:parent;anchors.margins:18;spacing:8
        RowLayout{Layout.fillWidth:true
            ColumnLayout{Layout.fillWidth:true;spacing:2;PageTitle{text:"Store Builder"}Text{text:"Build, paste, validate and export store records in one spreadsheet workspace.";color:"#94a3b8"}}
            Rectangle{radius:12;color:dirty?"#3b2b12":"#113426";implicitWidth:150;implicitHeight:38;Text{anchors.centerIn:parent;text:dirty?"● UNSAVED CHANGES":"✓ READY";color:dirty?"#fbbf24":"#4ade80";font.bold:true}}
        }
        Card{Layout.fillWidth:true;implicitHeight:68
            RowLayout{anchors.fill:parent;anchors.margins:10;spacing:8
                PrimaryButton{text:"Paste Stores";onClicked:pasteText(backend.clipboardText());ToolTip.visible:hovered;ToolTip.text:"Paste rows from Excel, Google Sheets, CSV or TSV"}
                AppButton{text:"+ Add Row";onClicked:addBlank(true)}
                AppButton{text:"Select All";onClicked:setAllIncluded(true)}
                AppButton{text:"Deselect All";onClicked:setAllIncluded(false)}
                AppButton{text:"Delete Selected";enabled:selectedCount()>0;onClicked:deleteCheckedRows()}
                AppButton{text:"Clear";onClicked:clearAll()}
                Item{Layout.fillWidth:true}
                Column{Text{text:populatedCount()+" entered  •  "+includedCount()+" included";color:"#f8fafc";font.bold:true}Text{text:grid.count+" rows available — expands automatically";color:"#94a3b8";font.pixelSize:9}}
                AppButton{text:"Validate";enabled:includedCount()>0;onClicked:backend.validateCreator(rowsJson())}
                PrimaryButton{text:"Export CSV";enabled:includedCount()>0;onClicked:saveDlg.open()}
            }
        }
        Rectangle{visible:validationCount>0;Layout.fillWidth:true;implicitHeight:42;radius:6;color:"#433614";Text{anchors.fill:parent;anchors.margins:8;text:"⚠ "+validationCount+" value(s) need review. Problem rows are highlighted in the grid.";color:"#fde68a";verticalAlignment:Text.AlignVCenter}}
        Card {
            Layout.fillWidth:true;Layout.fillHeight:true;clip:true
            Flickable {
                id:flick;anchors.fill:parent;anchors.margins:8;contentWidth:84+headers.length*155;contentHeight:headerRow.height+grid.count*38;clip:true
                Row{id:headerRow;height:40
                    Rectangle{width:84;height:40;color:"#10233d";border.color:"#3b5575";Text{anchors.centerIn:parent;text:"USE / ROW";color:"#bfdbfe";font.bold:true}}
                    Repeater{model:headers;delegate:Rectangle{required property string modelData;width:155;height:40;color:"#10233d";border.color:"#3b5575";Text{anchors.fill:parent;anchors.margins:6;text:modelData;color:"#bfdbfe";font.bold:true;verticalAlignment:Text.AlignVCenter;elide:Text.ElideRight}}}
                }
                Column{y:headerRow.height
                    Repeater{model:grid;delegate:Row{id:dataRow;required property int index;property int rr:index;height:38
                        Rectangle{width:84;height:38;color:page.rowHasFinding(dataRow.rr)?"#3a211b":dataRow.rr%2?"#0d1b2e":"#0b1829";border.color:selectedRow===dataRow.rr?"#60a5fa":"#29415f"
                            RowLayout{anchors.fill:parent;spacing:0
                                CheckBox{checked:grid.get(dataRow.rr).included;onToggled:{grid.setProperty(dataRow.rr,"included",checked);dirty=true};ToolTip.visible:hovered;ToolTip.text:checked?"Included in validation and export":"Excluded from validation and export"}
                                Text{text:String(dataRow.rr+1);color:"#94a3b8";Layout.fillWidth:true}
                            }
                        }
                        Repeater{model:headers.length;delegate:TextField{required property int index;property int cc:index;width:155;height:38;padding:6;text:grid.get(dataRow.rr)["c"+cc]||"";selectByMouse:true
                            background:Rectangle{color:!grid.get(dataRow.rr).included?"#151b25":page.rowHasFinding(dataRow.rr)?"#301b1d":((selectedRow===dataRow.rr&&selectedCol===cc)?"#17375f":(dataRow.rr%2?"#0d1b2e":"#0b1829"));border.width:selectedRow===dataRow.rr&&selectedCol===cc?2:1;border.color:selectedRow===dataRow.rr&&selectedCol===cc?"#60a5fa":"#29415f"}
                            color:grid.get(dataRow.rr).included?"#f8fafc":"#64748b";onActiveFocusChanged:if(activeFocus){selectedRow=dataRow.rr;selectedCol=cc};onEditingFinished:{grid.setProperty(dataRow.rr,"c"+cc,text);dirty=true}
                        }}
                    }}
                }
                ScrollBar.horizontal:ScrollBar{}
                ScrollBar.vertical:ScrollBar{}
            }
        }
        Card{visible:validation.count>0;Layout.fillWidth:true;implicitHeight:Math.min(150,42+validation.count*28);ColumnLayout{anchors.fill:parent;anchors.margins:8
            RowLayout{Layout.fillWidth:true;Text{text:"Validation Review";color:"#f8fafc";font.bold:true}Item{Layout.fillWidth:true}Text{text:validation.count+" finding(s)";color:"#f59e0b"}}
            ListView{Layout.fillWidth:true;Layout.fillHeight:true;model:validation;delegate:Text{required property string row;required property string field;required property string message;width:ListView.view.width;height:26;text:"Row "+row+"  •  "+field+"  —  "+message;color:"#f59e0b";elide:Text.ElideRight}}
        }}
    }
}