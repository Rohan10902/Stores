import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"

Item {
 id: page
 property var headers:["Store Name","SID","Banner","Nielsen Store Code","Trip Received","Last Trip","Address 1","Address 2","Address 3","ZIP","Active / Inactive","Is Census","Is Exceptions","Updated By"]
 property int selectedRow:0
 property int selectedCol:0
 property int validationCount:0
 property string pasteMessage:""
 property string pasteState:""
 ListModel{id:gridModel}
 ListModel{id:validationModel}

 function blankRow(){return {c0:"",c1:"",c2:"",c3:"",c4:"",c5:"",c6:"",c7:"",c8:"",c9:"",c10:"",c11:"",c12:"",c13:""}}
 function addBlank(){gridModel.append(blankRow())}
 function resetRows(){gridModel.clear();for(var i=0;i<10;i++)addBlank()}
 function rowsJson(){var rows=[];for(var r=0;r<gridModel.count;r++){var out={};var item=gridModel.get(r);for(var c=0;c<headers.length;c++)out[headers[c]]=item["c"+c]||"";rows.push(out)}return JSON.stringify(rows)}
 function pasteText(text){
  pasteMessage=""
  pasteState=""
  if(!text||!String(text).trim()){
   pasteState="error"
   pasteMessage="Nothing was pasted. The clipboard is empty or contains no text. Copy cells from Excel/Google Sheets and try again."
   backend.say("Paste failed — clipboard contains no text")
   return
  }
  try {
   var lines=String(text).replace(/\r\n/g,"\n").replace(/\r/g,"\n").split("\n")
   while(lines.length&&lines[lines.length-1]==="")lines.pop()
   if(!lines.length)throw new Error("No rows were found in the clipboard.")
   var startRow=selectedRow
   var startCol=selectedCol
   var pastedRows=0
   var pastedCells=0
   var clippedCells=0
   for(var r=0;r<lines.length;r++){
    if(lines[r]==="")continue
    var values=lines[r].indexOf("\t")>=0?lines[r].split("\t"):lines[r].split(",")
    while(gridModel.count<=startRow+pastedRows)addBlank()
    for(var c=0;c<values.length;c++){
     if(startCol+c<headers.length){
      gridModel.setProperty(startRow+pastedRows,"c"+(startCol+c),values[c])
      pastedCells++
     } else clippedCells++
    }
    pastedRows++
   }
   if(!pastedCells)throw new Error("Clipboard data could not fit into the 14-column table from the selected cell.")
   pasteState=clippedCells>0?"warning":"success"
   pasteMessage="Paste successful: "+pastedRows+" row(s), "+pastedCells+" cell(s) inserted starting at row "+(startRow+1)+", "+headers[startCol]+"."
   if(clippedCells>0)pasteMessage+=" "+clippedCells+" value(s) beyond the fixed 14-column schema were ignored."
   backend.say(pasteMessage)
  } catch(e) {
   pasteState="error"
   pasteMessage="Paste failed: "+e
   backend.say(pasteMessage)
  }
 }
 Component.onCompleted:resetRows()
 FileDialog{id:saveDlg;fileMode:FileDialog.SaveFile;nameFilters:["CSV (*.csv)"];onAccepted:backend.exportCreator(rowsJson(),selectedFile.toString())}
 Connections{target:backend;function onCreatorReady(payload){var d=JSON.parse(payload);validationCount=d.count||0;validationModel.clear();for(var i=0;i<d.findings.length;i++){var f=d.findings[i];validationModel.append({rowText:String(f.row),fieldText:String(f.field),messageText:String(f.message)})}}}

 ColumnLayout {anchors.fill:parent;anchors.margins:18;spacing:8
  PageTitle{text:"Create Store File"}
  Text{text:"Fixed 14-column output schema. Select a starting cell, then paste rows from Excel or Google Sheets.";color:"#94a3b8"}
  RowLayout {Layout.fillWidth:true
   PrimaryButton{text:"Paste from Clipboard";onClicked:pasteText(backend.clipboardText())}
   AppButton{text:"Add Row";onClicked:addBlank()}
   AppButton{text:"Delete Selected Row";enabled:gridModel.count>1;onClicked:{gridModel.remove(selectedRow);selectedRow=Math.max(0,Math.min(selectedRow,gridModel.count-1))}}
   AppButton{text:"Clear Table";onClicked:{resetRows();validationModel.clear();validationCount=0;pasteMessage="";pasteState=""}}
   Item{Layout.fillWidth:true}
   AppButton{text:"Validate";onClicked:backend.validateCreator(rowsJson())}
   PrimaryButton{text:"Export CSV";enabled:gridModel.count>0;onClicked:saveDlg.open()}
  }
  Rectangle {
   visible:pasteMessage!==""
   Layout.fillWidth:true
   implicitHeight:46
   radius:6
   color:pasteState==="success"?"#0d3b2a":pasteState==="warning"?"#433614":"#4a1720"
   border.width:1
   border.color:pasteState==="success"?"#22c55e":pasteState==="warning"?"#f59e0b":"#ef4444"
   Text{anchors.fill:parent;anchors.margins:9;text:(pasteState==="success"?"✓ ":pasteState==="warning"?"⚠ ":"✕ ")+pasteMessage;color:pasteState==="success"?"#86efac":pasteState==="warning"?"#fde68a":"#fca5a5";verticalAlignment:Text.AlignVCenter;wrapMode:Text.WordWrap}
  }
  Rectangle {visible:validationCount>0;Layout.fillWidth:true;implicitHeight:42;radius:6;color:"#433614";Text{anchors.fill:parent;anchors.margins:8;text:validationCount+" value(s) need review before export.";color:"#fde68a";verticalAlignment:Text.AlignVCenter}}
  Card {Layout.fillWidth:true;Layout.fillHeight:true;clip:true
   Flickable {id:tableFlick;anchors.fill:parent;anchors.margins:8;contentWidth:headers.length*155;contentHeight:38+gridModel.count*38;clip:true
    Row {id:headerRow;height:38
     Repeater {model:headers
      Rectangle {width:155;height:38;color:"#10233d";border.width:1;border.color:"#29415f"
       Text{anchors.fill:parent;anchors.margins:6;text:modelData;color:"#bfdbfe";font.bold:true;verticalAlignment:Text.AlignVCenter;elide:Text.ElideRight}
      }
     }
    }
    Column {y:38
     Repeater {model:gridModel
      Row {id:storeRow;property int rowNumber:index;height:38
       Repeater {model:page.headers.length
        TextField {property int columnNumber:index;width:155;height:38;padding:6;text:gridModel.get(storeRow.rowNumber)["c"+columnNumber]||"";selectByMouse:true;color:"#f8fafc"
         background:Rectangle{color:(page.selectedRow===storeRow.rowNumber&&page.selectedCol===columnNumber)?"#17375f":storeRow.rowNumber%2?"#0d1b2e":"#0b1829";border.width:1;border.color:"#29415f"}
         onActiveFocusChanged:if(activeFocus){page.selectedRow=storeRow.rowNumber;page.selectedCol=columnNumber}
         onEditingFinished:gridModel.setProperty(storeRow.rowNumber,"c"+columnNumber,text)
        }
       }
      }
     }
    }
    ScrollBar.horizontal:ScrollBar{}
    ScrollBar.vertical:ScrollBar{}
   }
  }
  Card {visible:validationModel.count>0;Layout.fillWidth:true;implicitHeight:Math.min(140,42+validationModel.count*28)
   ColumnLayout{anchors.fill:parent;anchors.margins:8
    Text{text:"Validation Findings";color:"#f8fafc";font.bold:true}
    ListView{Layout.fillWidth:true;Layout.fillHeight:true;model:validationModel;clip:true;delegate:Text{width:ListView.view.width;height:26;text:"Row "+rowText+" • "+fieldText+" — "+messageText;color:"#f59e0b";elide:Text.ElideRight}}
   }
  }
 }
}