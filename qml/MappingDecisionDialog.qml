import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    modal: true
    width: Math.min(680, parent ? parent.width * 0.80 : 680)
    title: "Confirm Smart Repair Mapping"
    standardButtons: Dialog.NoButton

    property string detectedValue: ""
    property string valueType: ""
    property var candidates: []
    property string selectedField: ""
    property bool rememberChoice: true

    signal mappingAccepted(string value, string field, bool remember)
    signal mappingUnresolved(string value)

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        Label {
            Layout.fillWidth: true
            text: 'Detected value: "' + root.detectedValue + '"'
            font.bold: true
            wrapMode: Text.Wrap
        }

        Label {
            Layout.fillWidth: true
            text: "The application found more than one plausible destination. Select the correct column or leave the value unresolved."
            wrapMode: Text.Wrap
        }

        Repeater {
            model: root.candidates
            delegate: RadioButton {
                required property var modelData
                Layout.fillWidth: true
                visible: Number(modelData.score || 0) > 0
                text: String(modelData.field) + " — " + String(modelData.score) + "% confidence"
                checked: root.selectedField === String(modelData.field)
                onClicked: root.selectedField = String(modelData.field)
            }
        }

        CheckBox {
            text: "Remember my choice locally"
            checked: root.rememberChoice
            onToggled: root.rememberChoice = checked
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight
            Button {
                text: "Keep Unresolved"
                onClicked: {
                    root.mappingUnresolved(root.detectedValue)
                    root.close()
                }
            }
            Button {
                text: "Apply Mapping"
                enabled: root.selectedField.length > 0
                highlighted: true
                onClicked: {
                    root.mappingAccepted(root.detectedValue, root.selectedField, root.rememberChoice)
                    root.close()
                }
            }
        }
    }

    function openForSuggestion(suggestion) {
        detectedValue = String(suggestion.value || "")
        valueType = String(suggestion.valueType || "")
        candidates = suggestion.candidates || []
        selectedField = String(suggestion.suggestedField || "")
        open()
    }
}
