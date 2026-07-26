import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"

Item {
    property string src: ""
    property int total: 0
    property int issueCount: 0
    property int suggestedWidth: 0
    property int suggestedSidWidth: 0
    ListModel { id: findings }

    FileDialog { id: openDlg; nameFilters: ["Data (*.csv *.xlsx *.xls *.xlsm *.txt *.tsv *.json *.xml)"]; onAccepted: { src=selectedFile.toString(); backend.reviewSingleFile(src) } }
    FileDialog { id: saveDlg; fileMode: FileDialog.SaveFile; nameFilters: ["CSV (*.csv)"]; onAccepted: backend.exportSingleReview(src,selectedFile.toString()) }

    Connections {
        target: backend
        function onSingleReviewReady(p) {
            var d=JSON.parse(p); total=d.total||0; issueCount=d.issueCount||0
            suggestedWidth=d.suggestedNielsenWidth||0; suggestedSidWidth=d.suggestedSidWidth||0
            findings.clear()
            for(var i=0;i<(d.rows||[]).length;i++) {
                var r=d.rows[i]
                for(var j=0;j<(r.issues||[]).length;j++) findings.append({row:String(r.row),severity:String(r.severity),problem:String(r.issues[j])})
            }
            for(var k=0;k<(d.structuralFindings||[]).length;k++) {
                var s=d.structuralFindings[k]
                findings.append({row:String(s.row),severity:String(s.severity||"REVIEW"),problem:String(s.problem)})
            }
        }
    }

    ColumnLayout { anchors.fill:parent; anchors.margins:22; spacing:10
        PageTitle { text:"Review One File" }
        Text { text:"Review a dataset without a Master file. Source data remains unchanged until you export a reviewed copy."; color:"#94a3b8" }
        Card { Layout.fillWidth:true; implicitHeight:72
            RowLayout { anchors.fill:parent; anchors.margins:10
                TextField { Layout.fillWidth:true; readOnly:true; text:src; placeholderText:"Choose CSV / Excel / text file" }
                AppButton { text:"Choose File"; onClicked:openDlg.open() }
                PrimaryButton { text:"Analyze"; enabled:src!==""; onClicked:backend.reviewSingleFile(src) }
                AppButton { text:"Export Reviewed Copy"; enabled:src!==""; onClicked:saveDlg.open() }
            }
        }
        RowLayout { Layout.fillWidth:true
            Card { Layout.fillWidth:true; implicitHeight:62; Column { anchors.fill:parent; anchors.margins:8; Text{text:total;color:"#22c55e";font.pixelSize:18;font.bold:true} Text{text:"RECORDS";color:"#94a3b8";font.pixelSize:9} } }
            Card { Layout.fillWidth:true; implicitHeight:62; Column { anchors.fill:parent; anchors.margins:8; Text{text:issueCount;color:issueCount?"#f59e0b":"#22c55e";font.pixelSize:18;font.bold:true} Text{text:"NEEDS ATTENTION";color:"#94a3b8";font.pixelSize:9} } }
            Card { Layout.fillWidth:true; implicitHeight:62; Column { anchors.fill:parent; anchors.margins:8; Text{text:suggestedWidth||"—";color:"#60a5fa";font.pixelSize:18;font.bold:true} Text{text:"NIELSEN WIDTH SUGGESTION";color:"#94a3b8";font.pixelSize:9} } }
        }
        Card { Layout.fillWidth:true; implicitHeight:96
            ColumnLayout { anchors.fill:parent; anchors.margins:10
                RowLayout { Layout.fillWidth:true
                    Text { text:"Leading-zero preview / apply"; color:"#f8fafc"; font.bold:true }
                    ComboBox { id:padTarget; model:["Nielsen Store Code","SID"]; Layout.preferredWidth:210; onCurrentIndexChanged: widthBox.value=currentIndex===0?(suggestedWidth||6):(suggestedSidWidth||6) }
                    SpinBox { id:widthBox; from:1; to:30; value:suggestedWidth||6; editable:true }
                    PrimaryButton { text:"Preview / Apply Padding"; enabled:src!==""; onClicked:backend.normalizeSingleIdentifier(padTarget.currentText,widthBox.value) }
                    Item { Layout.fillWidth:true }
                }
                Text { text:"Only all-digit identifiers are padded. Review the findings below after applying; text identifiers remain unchanged."; color:"#94a3b8" }
            }
        }
        Card { Layout.fillWidth:true; Layout.fillHeight:true
            ColumnLayout { anchors.fill:parent; anchors.margins:10
                Text { text:"Records Needing Attention / Preview"; color:"#f8fafc"; font.bold:true }
                Text { visible:findings.count===0; text:"No findings to display. If this is a deliberately broken CSV/TXT file, structural parsing checks should still report malformed records."; color:"#94a3b8"; wrapMode:Text.WordWrap; Layout.fillWidth:true }
                RowLayout { Layout.fillWidth:true; Text{text:"Row";color:"#94a3b8";font.bold:true;Layout.preferredWidth:80} Text{text:"State";color:"#94a3b8";font.bold:true;Layout.preferredWidth:110} Text{text:"Finding / Preview";color:"#94a3b8";font.bold:true;Layout.fillWidth:true} }
                ListView { Layout.fillWidth:true; Layout.fillHeight:true; model:findings; clip:true
                    delegate: Rectangle { required property int index; required property string row; required property string severity; required property string problem; width:ListView.view.width; height:Math.max(44,detail.implicitHeight+14); color:index%2?"#0d1b2e":"#0b1829"
                        RowLayout { anchors.fill:parent; anchors.margins:6
                            Text{text:row;color:"#f8fafc";Layout.preferredWidth:80}
                            Text{text:severity;color:"#f59e0b";font.bold:true;Layout.preferredWidth:110}
                            Text{id:detail;text:problem;color:"#f8fafc";Layout.fillWidth:true;wrapMode:Text.WordWrap}
                        }
                    }
                }
            }
        }
    }
}
