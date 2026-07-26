import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"

Item {
    id: page
    property var headers: ["Store Name", "SID", "Banner", "Nielsen Store Code", "Trip Received", "Last Trip", "Address 1", "Address 2", "Address 3", "ZIP", "Active / Inactive", "Is Census", "Is Exceptions", "Updated By"]
    property int selectedRow: 0
    property int selectedCol: 0
    property int validationCount: 0
    property string undoJson: ""
    property string notice: ""
    ListModel { id: grid }
    ListModel { id: validation }

    Component.onCompleted: { for (var i=0;i<10;i++) addBlank() }
    function blank(){var o={};for(var i=0;i<headers.length;i++)o["c"+i]="";return o}
    function addBlank(){grid.append(blank())}
    function rowsArray(){var a=[];for(var r=0;r<grid.count;r++){var o={};for(var c=0;c<headers.length;c++)o[headers[c]]=grid.get(r)["c"+c]||"";a.push(o)}return a}
    function rowsJson(){return JSON.stringify(rowsArray())}
    function saveUndo(){undoJson=rowsJson()}
    function restoreUndo(){if(!undoJson)return;var a=JSON.parse(undoJson);grid.clear();for(var r=0;r<a.length;r++){var o=blank();for(var c=0;c<headers.length;c++)o["c"+c]=String(a[r][headers[c]]||"");grid.append(o)}undoJson="";notice="Undo applied";backend.validateCreator(rowsJson())}
    function pasteText(t){if(!t){notice="Nothing pasted: clipboard is empty";return}saveUndo();var lines=t.replace(/\r\n/g,"\n").replace(/\r/g,"\n").split("\n");if(lines.length&&lines[lines.length-1]==="")lines.pop();var changed=0;for(var r=0;r<lines.length;r++){var vals=lines[r].indexOf("\t")>=0?lines[r].split("\t"):lines[r].split(",");while(grid.count<=selectedRow+r)addBlank();for(var c=0;c<vals.length&&selectedCol+c<headers.length;c++){grid.setProperty(selectedRow+r,"c"+(selectedCol+c),vals[c]);changed++}}notice="Pasted "+changed+" cell(s)";backend.validateCreator(rowsJson())}
    function clearAll(){saveUndo();grid.clear();for(var i=0;i<10;i++)addBlank();validation.clear();validationCount=0;notice="Table cleared"}
    function padColumn(){var col=bulkCol.currentIndex;var width=Number(padWidth.value);if(col<0||width<1)return;saveUndo();var changed=0;for(var r=0;r<grid.count;r++){var key="c"+col;var v=String(grid.get(r)[key]||"").trim();if(/^\d+$/.test(v)&&v.length<width){grid.setProperty(r,key,("00000000000000000000"+v).slice(-width));changed++}}notice="Padded "+changed+" value(s) in "+headers[col];backend.validateCreator(rowsJson())}
    function replaceAll(){var find=findText.text;if(!find){notice="Enter a value to find";return}saveUndo();var repl=replaceText.text;var only=replaceCol.currentIndex-1;var changed=0;for(var r=0;r<grid.count;r++){for(var c=0;c<headers.length;c++){if(only>=0&&c!==only)continue;var key="c"+c;var v=String(grid.get(r)[key]||"");if(v.indexOf(find)>=0){grid.setProperty(r,key,v.split(find).join(repl));changed++}}}notice="Replaced "+changed+" cell(s)";backend.validateCreator(rowsJson())}
    function cellColor(row, col) {
        if (selectedRow === row && selectedCol === col) return "#17375f"
        if ((row % 2) === 1) return "#0d1b2e"
        return "#0b1829"
    }

    FileDialog{id:saveDlg;fileMode:FileDialog.SaveFile;nameFilters:["CSV (*.csv)"];onAccepted:backend.exportCreator(rowsJson(),selectedFile.toString())}
    Connections{target:backend;function onCreatorReady(p){var d=JSON.parse(p);validationCount=d.count;validation.clear();for(var i=0;i<d.findings.length;i++){var x=d.findings[i];validation.append({row:String(x.row),field:String(x.field),message:String(x.message)})}}}

    ColumnLayout {
        anchors.fill:parent;anchors.margins:18;spacing:8
        PageTitle{text:"Create Store File"}
        Text{text:"Fixed output schema. Click a cell and paste directly from Excel / Google Sheets with Ctrl+V.";color:"#94a3b8"}
        RowLayout{Layout.fillWidth:true
            PrimaryButton{text:"Paste from Clipboard";onClicked:pasteText(backend.clipboardText())}
            AppButton{text:"Add Row";onClicked:{saveUndo();addBlank()}}
            AppButton{text:"Delete Selected Row";enabled:grid.count>1;onClicked:{saveUndo();grid.remove(selectedRow);selectedRow=Math.max(0,Math.min(selectedRow,grid.count-1));backend.validateCreator(rowsJson())}}
            AppButton{text:"Clear Table";onClicked:clearAll()}
            AppButton{text:"Undo";enabled:undoJson!=="";onClicked:restoreUndo()}
            Item{Layout.fillWidth:true} AppButton{text:"Validate";onClicked:backend.validateCreator(rowsJson())} PrimaryButton{text:"Export CSV";enabled:grid.count>0;onClicked:saveDlg.open()}
        }
        Card{Layout.fillWidth:true;implicitHeight:92
            ColumnLayout{anchors.fill:parent;anchors.margins:8
                RowLayout{Layout.fillWidth:true
                    Text{text:"Bulk leading zeros";color:"#f8fafc";font.bold:true}
                    ComboBox{id:bulkCol;model:headers;Layout.preferredWidth:220;currentIndex:3}
                    SpinBox{id:padWidth;from:1;to:20;value:11;editable:true}
                    PrimaryButton{text:"Apply Padding";onClicked:padColumn()}
                    Item{Layout.fillWidth:true}
                    Text{text:"Only all-digit values are padded";color:"#60a5fa"}
                }
                RowLayout{Layout.fillWidth:true
                    Text{text:"Find / Replace";color:"#f8fafc";font.bold:true}
                    TextField{id:findText;placeholderText:"Find";Layout.preferredWidth:180}
                    TextField{id:replaceText;placeholderText:"Replace with";Layout.preferredWidth:180}
                    ComboBox{id:replaceCol;model:["All columns"].concat(headers);Layout.preferredWidth:220}
                    PrimaryButton{text:"Replace All";onClicked:replaceAll()}
                    Item{Layout.fillWidth:true}
                }
            }
        }
        Rectangle{visible:validationCount>0||notice!=="";Layout.fillWidth:true;implicitHeight:42;radius:6;color:validationCount>0?"#433614":"#113426";Text{anchors.fill:parent;anchors.margins:8;text:validationCount>0?validationCount+" value(s) need review before export. "+notice:notice;color:validationCount>0?"#fde68a":"#86efac";verticalAlignment:Text.AlignVCenter}}
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            Flickable {
                id: flick
                anchors.fill: parent
                anchors.margins: 8
                contentWidth: headers.length * 155
                contentHeight: headerRow.height + grid.count * 38
                clip: true
                Row {
                    id: headerRow
                    height: 38
                    Repeater {
                        model: headers
                        delegate: Rectangle {
                            required property string modelData
                            width: 155
                            height: 38
                            color: "#10233d"
                            border.color: "#29415f"
                            Text {
                                anchors.fill: parent
                                anchors.margins: 6
                                text: modelData
                                color: "#bfdbfe"
                                font.bold: true
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
                Column {
                    y: headerRow.height
                    Repeater {
                        model: grid
                        delegate: Row {
                            id: dataRow
                            required property int index
                            property int rr: index
                            height: 38
                            Repeater {
                                model: headers.length
                                delegate: TextField {
                                    required property int index
                                    property int cc: index
                                    width: 155
                                    height: 38
                                    padding: 6
                                    text: grid.get(dataRow.rr)["c" + cc] || ""
                                    selectByMouse: true
                                    background: Rectangle {
                                        color: page.cellColor(dataRow.rr, cc)
                                        border.color: "#29415f"
                                    }
                                    color: "#f8fafc"
                                    onActiveFocusChanged: {
                                        if (activeFocus) {
                                            selectedRow = dataRow.rr
                                            selectedCol = cc
                                        }
                                    }
                                    onEditingFinished: {
                                        saveUndo()
                                        grid.setProperty(dataRow.rr, "c" + cc, text)
                                    }
                                }
                            }
                        }
                    }
                }
                ScrollBar.horizontal: ScrollBar {}
                ScrollBar.vertical: ScrollBar {}
            }
        }
        Card{visible:validation.count>0;Layout.fillWidth:true;implicitHeight:Math.min(130,40+validation.count*28);ColumnLayout{anchors.fill:parent;anchors.margins:8;Text{text:"Validation Findings";color:"#f8fafc";font.bold:true}ListView{Layout.fillWidth:true;Layout.fillHeight:true;model:validation;delegate:Text{required property string row;required property string field;required property string message;width:ListView.view.width;height:26;text:"Row "+row+" • "+field+" — "+message;color:"#f59e0b";elide:Text.ElideRight}}}}
    }
}
