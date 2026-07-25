import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Window

ApplicationWindow {
 id: root; visible: true; width: 1500; height: 900; minimumWidth: 1100; minimumHeight: 700
 title: "Store Data Assistant 6.0"; color:"#07111d"
 property color panel:"#0d1a28"; property color border:"#203347"; property color fg:"#f3f7fb"
 property color muted:"#8fa2b7"; property color blue:"#2b9cff"
 property string masterPath:""; property string mappingPath:""; property string repairPath:""; property string analysisPath:""

 FileDialog { id: masterDialog; title:"Choose Master"; nameFilters:["Data files (*.csv *.xlsx *.xls)"]; onAccepted:{root.masterPath=selectedFile.toString(); masterLabel.text=selectedFile.toString().replace("file:///","")} }
 FileDialog { id: mappingDialog; title:"Choose Store File"; nameFilters:["Data files (*.csv *.xlsx *.xls)"]; onAccepted:{root.mappingPath=selectedFile.toString(); mappingLabel.text=selectedFile.toString().replace("file:///","")} }
 FileDialog { id: repairDialog; title:"Choose broken CSV"; nameFilters:["Delimited files (*.csv *.tsv *.txt)"]; onAccepted:{root.repairPath=selectedFile.toString(); repairLabel.text=selectedFile.toString().replace("file:///","")} }
 FileDialog { id: analysisDialog; title:"Choose data file"; nameFilters:["Supported files (*.csv *.tsv *.txt *.xlsx *.xls *.json *.xml)"]; onAccepted:{root.analysisPath=selectedFile.toString(); analysisLabel.text=selectedFile.toString().replace("file:///","")} }

 component Nav: Button {
   property int target:0; implicitHeight:46
   background: Rectangle { radius:7; color: stack.currentIndex===parent.target ? "#12314a":"transparent" }
   contentItem: Text { text:parent.text; color:root.fg; verticalAlignment:Text.AlignVCenter; leftPadding:12; font.pixelSize:13 }
   onClicked: stack.currentIndex=target
 }
 component Card: Rectangle { radius:10; color:root.panel; border.color:root.border; border.width:1 }
 component Stat: Card {
   property string label:""; property string value:"—"; property string detail:""
   implicitHeight:105
   Column { anchors.fill:parent; anchors.margins:14; spacing:7
     Text{text:parent.parent.label;color:root.muted;font.pixelSize:11}
     Text{text:parent.parent.value;color:root.fg;font.pixelSize:24;font.bold:true}
     Text{text:parent.parent.detail;color:root.muted;font.pixelSize:10}
   }
 }
 header: Rectangle { height:52;color:"#06101b";border.color:"#142638"
   RowLayout{anchors.fill:parent;anchors.margins:14
    Text{text:"◆  Store Data Assistant 6.0";color:root.fg;font.pixelSize:16;font.bold:true}
    Item{Layout.fillWidth:true}
    Text{text:"🔒 LOCAL PROCESSING";color:"#8ee6a6";font.pixelSize:11;font.bold:true}
   }
 }
 RowLayout { anchors.fill:parent; spacing:0
  Rectangle { Layout.preferredWidth:225;Layout.fillHeight:true;color:"#091522";border.color:"#15283a"
   ColumnLayout{anchors.fill:parent;anchors.margins:12;spacing:5
    Nav{text:"Home";target:0;Layout.fillWidth:true}
    Text{text:"STORE TOOLS";color:root.muted;font.pixelSize:10;Layout.topMargin:12}
    Nav{text:"Compare with Master";target:1;Layout.fillWidth:true}
    Nav{text:"Fix Broken File";target:2;Layout.fillWidth:true}
    Text{text:"GENERAL DATA TOOLS";color:root.muted;font.pixelSize:10;Layout.topMargin:12}
    Nav{text:"Data Health Check";target:3;Layout.fillWidth:true}
    Nav{text:"Explore & Analyze Data";target:4;Layout.fillWidth:true}
    Item{Layout.fillHeight:true}
    Text{text:backend.message;color:root.muted;font.pixelSize:10;wrapMode:Text.WordWrap;Layout.fillWidth:true}
   }
  }
  StackLayout{id:stack;Layout.fillWidth:true;Layout.fillHeight:true;currentIndex:0

   // HOME
   Rectangle{color:root.color
    ColumnLayout{anchors.fill:parent;anchors.margins:28;spacing:18
     Text{text:"Good evening";color:root.fg;font.pixelSize:28;font.bold:true}
     Text{text:"Choose a workspace. Store validation stays separate from general file analysis.";color:root.muted;font.pixelSize:14}
     GridLayout{columns:2;columnSpacing:14;rowSpacing:14;Layout.fillWidth:true
      Card{Layout.fillWidth:true;Layout.preferredHeight:150;MouseArea{anchors.fill:parent;onClicked:stack.currentIndex=1}
       Column{anchors.fill:parent;anchors.margins:18;spacing:10;Text{text:"Compare with Master";color:root.fg;font.pixelSize:18;font.bold:true};Text{text:"Validate the strict 14-field store schema against a trusted Master.";color:root.muted};Text{text:"Open →";color:root.blue}}
      }
      Card{Layout.fillWidth:true;Layout.preferredHeight:150;MouseArea{anchors.fill:parent;onClicked:stack.currentIndex=2}
       Column{anchors.fill:parent;anchors.margins:18;spacing:10;Text{text:"Fix Broken File";color:root.fg;font.pixelSize:18;font.bold:true};Text{text:"Diagnose malformed CSV rows, line breaks and extra separators.";color:root.muted};Text{text:"Open →";color:root.blue}}
      }
      Card{Layout.fillWidth:true;Layout.preferredHeight:150;MouseArea{anchors.fill:parent;onClicked:stack.currentIndex=3}
       Column{anchors.fill:parent;anchors.margins:18;spacing:10;Text{text:"Data Health Check";color:root.fg;font.pixelSize:18;font.bold:true};Text{text:"General quality checks for supported confidential data files.";color:root.muted};Text{text:"Open →";color:root.blue}}
      }
      Card{Layout.fillWidth:true;Layout.preferredHeight:150;MouseArea{anchors.fill:parent;onClicked:stack.currentIndex=4}
       Column{anchors.fill:parent;anchors.margins:18;spacing:10;Text{text:"Explore & Analyze Data";color:root.fg;font.pixelSize:18;font.bold:true};Text{text:"Calculations, filtering and optional read-only SQL — only here.";color:root.muted};Text{text:"Open →";color:root.blue}}
      }
     }
     Card{Layout.fillWidth:true;Layout.preferredHeight:95
      RowLayout{anchors.fill:parent;anchors.margins:18;Text{text:"🔒";font.pixelSize:25};Column{Text{text:"Confidential-data friendly";color:root.fg;font.bold:true};Text{text:"Core analysis runs on this computer; the app does not require a cloud data service.";color:root.muted}}}
     }
     Item{Layout.fillHeight:true}
    }
   }

   // STORE VALIDATION
   Rectangle{color:root.color
    ColumnLayout{anchors.fill:parent;anchors.margins:24;spacing:12
     Text{text:"Compare with Master";color:root.fg;font.pixelSize:25;font.bold:true}
     Text{text:"Strict store workflow • 14 standard fields • smart header mapping • no SQL";color:root.muted}
     RowLayout{Layout.fillWidth:true;Button{text:"Choose Master";onClicked:masterDialog.open()};Text{id:masterLabel;text:"No Master selected";color:root.muted;Layout.fillWidth:true}}
     RowLayout{Layout.fillWidth:true;Button{text:"Choose Store File";onClicked:mappingDialog.open()};Text{id:mappingLabel;text:"No store file selected";color:root.muted;Layout.fillWidth:true}}
     Button{text:"Validate Stores";enabled:root.masterPath!==""&&root.mappingPath!=="";onClicked:{
       var r=backend.validateStores(root.masterPath,root.mappingPath)
       if(r.error){validationSummary.text=r.error;return}
       totalS.value=r.total;correctS.value=r.correct;reviewS.value=r.review;errorS.value=r.error;brokenS.value=r.broken
       validationSummary.text="Validation complete. Scroll through issue records below."
       resultModel.clear(); for(var i=0;i<r.rows.length;i++) resultModel.append(r.rows[i])
     }}
     RowLayout{Layout.fillWidth:true
      Stat{id:totalS;label:"TOTAL";Layout.fillWidth:true} Stat{id:correctS;label:"CORRECT";Layout.fillWidth:true}
      Stat{id:reviewS;label:"REVIEW";Layout.fillWidth:true} Stat{id:errorS;label:"ERROR";Layout.fillWidth:true}
      Stat{id:brokenS;label:"BROKEN";Layout.fillWidth:true}
     }
     Text{id:validationSummary;text:"Select both files to begin.";color:root.muted}
     Card{Layout.fillWidth:true;Layout.fillHeight:true
      ListView{anchors.fill:parent;anchors.margins:8;clip:true;model:ListModel{id:resultModel}
       delegate:Rectangle{width:ListView.view.width;height:58;color:index%2?"#0a1623":"#0d1b29"
        RowLayout{anchors.fill:parent;anchors.margins:8
         Text{text:row;width:55;color:root.muted} Text{text:sid;width:110;color:root.fg}
         Text{text:store;width:210;color:root.fg;elide:Text.ElideRight}
         Text{text:status;width:80;color:status==="ERROR"?"#ff8585":status==="REVIEW"?"#ffc86a":"#83e89a";font.bold:true}
         Text{text:problem;color:"#c4d0dc";Layout.fillWidth:true;elide:Text.ElideRight}
        }
       }
      }
     }
    }
   }

   // REPAIR
   Rectangle{color:root.color
    ColumnLayout{anchors.fill:parent;anchors.margins:24;spacing:14
     Text{text:"Fix Broken File";color:root.fg;font.pixelSize:25;font.bold:true}
     Text{text:"The original file is not overwritten. Review exact physical lines and unplaced values.";color:root.muted}
     RowLayout{Button{text:"Choose CSV / TSV / TXT";onClicked:repairDialog.open()};Text{id:repairLabel;text:"No file selected";color:root.muted;Layout.fillWidth:true}
      Button{text:"Inspect";enabled:root.repairPath!=="";onClicked:{var r=backend.inspectBroken(root.repairPath);repairSummary.text=r.error?r.error:(r.rows+" records • "+r.issueCount+" structural issue(s)");repairModel.clear();if(r.issues)for(var i=0;i<r.issues.length;i++)repairModel.append(r.issues[i])}}
     }
     Text{id:repairSummary;text:"";color:root.muted}
     Card{Layout.fillWidth:true;Layout.fillHeight:true
      ListView{anchors.fill:parent;anchors.margins:8;clip:true;model:ListModel{id:repairModel}
       delegate:Rectangle{width:ListView.view.width;height:82;color:index%2?"#0a1623":"#0d1b29"
        Column{anchors.fill:parent;anchors.margins:8;spacing:4
         Text{text:"Line "+line+"  •  "+problem;color:"#ffc86a";font.bold:true}
         Text{text:"Unplaced: "+unplaced;color:root.fg;elide:Text.ElideRight;width:parent.width}
         Text{text:"Raw: "+raw;color:root.muted;elide:Text.ElideRight;width:parent.width}
        }
       }
      }
     }
    }
   }

   // HEALTH
   Rectangle{color:root.color
    ColumnLayout{anchors.fill:parent;anchors.margins:24;spacing:14
     Text{text:"Data Health Check";color:root.fg;font.pixelSize:25;font.bold:true}
     Text{text:"General-purpose local profiling. Detects structure, missing data, duplicates, mixed types and outliers.";color:root.muted}
     RowLayout{Button{text:"Choose File";onClicked:analysisDialog.open()};Text{id:analysisLabel;text:"No file selected";color:root.muted;Layout.fillWidth:true}
      Button{text:"Check Health";enabled:root.analysisPath!=="";onClicked:{
       var r=backend.analyzeFile(root.analysisPath);if(r.error){healthText.text=r.error;return}
       healthScore.value=r.score+"%";healthRows.value=r.rows;healthMissing.value=r.missing;healthDup.value=r.duplicates;healthOut.value=r.outliers
       healthText.text="Detected structure: "+r.structure+" ("+r.structureConfidence+"% confidence) • "+r.columns+" columns • "+r.mixed+" mixed-type column(s)"
      }}
     }
     RowLayout{Layout.fillWidth:true
      Stat{id:healthScore;label:"HEALTH";Layout.fillWidth:true} Stat{id:healthRows;label:"ROWS";Layout.fillWidth:true}
      Stat{id:healthMissing;label:"MISSING VALUES";Layout.fillWidth:true} Stat{id:healthDup;label:"DUPLICATES";Layout.fillWidth:true}
      Stat{id:healthOut;label:"OUTLIERS";Layout.fillWidth:true}
     }
     Text{id:healthText;text:"Choose a supported file to begin.";color:root.muted;wrapMode:Text.WordWrap}
     Card{Layout.fillWidth:true;Layout.fillHeight:true
      Text{anchors.centerIn:parent;text:"Health statistics are computed without applying store-specific rules.";color:root.muted}
     }
    }
   }

   // EXPLORE + SQL ONLY HERE
   Rectangle{color:root.color
    ColumnLayout{anchors.fill:parent;anchors.margins:24;spacing:12
     Text{text:"Explore & Analyze Data";color:root.fg;font.pixelSize:25;font.bold:true}
     Text{text:"Load the file through Data Health Check first. SQL is read-only and intentionally available only in this workspace.";color:root.muted}
     TabBar{id:tabs;Layout.fillWidth:true;TabButton{text:"Quick Analysis"};TabButton{text:"Advanced SQL"}}
     StackLayout{currentIndex:tabs.currentIndex;Layout.fillWidth:true;Layout.fillHeight:true
      Card{ColumnLayout{anchors.fill:parent;anchors.margins:16;spacing:10
       Text{text:"Column calculation";color:root.fg;font.pixelSize:16;font.bold:true}
       RowLayout{TextField{id:columnName;placeholderText:"Exact column name";Layout.fillWidth:true};Button{text:"Calculate";onClicked:{var r=backend.quickAnalysis(columnName.text);quickResult.text=JSON.stringify(r,null,2)}}}
       TextArea{id:quickResult;Layout.fillWidth:true;Layout.fillHeight:true;readOnly:true;color:root.fg;background:Rectangle{color:"#07131f";border.color:root.border;radius:6}}
      }}
      Card{ColumnLayout{anchors.fill:parent;anchors.margins:16;spacing:10
       Text{text:"Read-only SQL";color:root.fg;font.pixelSize:16;font.bold:true}
       Text{text:'Query the currently analyzed file as table "data". SELECT and WITH queries only.';color:root.muted}
       TextArea{id:sql;Layout.fillWidth:true;Layout.preferredHeight:180;color:root.fg;font.family:"Consolas";text:'SELECT * FROM data LIMIT 100';background:Rectangle{color:"#07131f";border.color:root.border;radius:6}}
       Button{text:"Run Query";onClicked:{var r=backend.runSql(sql.text);sqlResult.text=JSON.stringify(r,null,2)}}
       TextArea{id:sqlResult;Layout.fillWidth:true;Layout.fillHeight:true;readOnly:true;color:root.fg;font.family:"Consolas";background:Rectangle{color:"#07131f";border.color:root.border;radius:6}}
      }}
     }
    }
   }
  }
 }
}