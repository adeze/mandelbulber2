import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Pane {
    id: root

    property bool renderEnabled: true
    property bool historyEnabled: true
    property bool navigationActionsVisible: true

    signal renderRequested()
    signal stopRequested()
    signal undoRequested()
    signal redoRequested()
    signal navigatorRequested()

    padding: 12
    LayoutMirroring.enabled: Qt.locale().textDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        Label {
            text: qsTr("Render")
            font.bold: true
        }

        RowLayout {
            spacing: 8
            Layout.fillWidth: true

            Button {
                id: renderControl
                objectName: "renderButton"
                icon.source: "qrc:/system/icons/applications-graphics.svg"
                text: qsTr("Render")
                enabled: root.renderEnabled
                highlighted: true
                Layout.fillWidth: true
                Accessible.description: qsTr("Render the image using the current settings")
                ToolTip.visible: renderControl.hovered || renderControl.activeFocus
                ToolTip.text: renderControl.Accessible.description
                onClicked: root.renderRequested()
            }

            Button {
                id: stopControl
                objectName: "stopButton"
                icon.source: "qrc:/system/icons/process-stop.svg"
                text: qsTr("Stop")
                Layout.fillWidth: true
                Accessible.description: qsTr("Stop rendering")
                ToolTip.visible: stopControl.hovered || stopControl.activeFocus
                ToolTip.text: stopControl.Accessible.description
                onClicked: root.stopRequested()
            }
        }

        RowLayout {
            visible: root.navigationActionsVisible
            spacing: 8
            Layout.fillWidth: true

            Button {
                id: undoControl
                objectName: "undoButton"
                icon.source: "qrc:/system/icons/edit-undo.png"
                text: qsTr("Undo")
                enabled: root.historyEnabled
                Layout.fillWidth: true
                Accessible.description: qsTr("Undo the last settings change and render")
                ToolTip.visible: undoControl.hovered || undoControl.activeFocus
                ToolTip.text: undoControl.Accessible.description
                onClicked: root.undoRequested()
            }

            Button {
                id: redoControl
                objectName: "redoButton"
                icon.source: "qrc:/system/icons/edit-redo.png"
                text: qsTr("Redo")
                enabled: root.historyEnabled
                Layout.fillWidth: true
                Accessible.description: qsTr("Redo the last settings change and render")
                ToolTip.visible: redoControl.hovered || redoControl.activeFocus
                ToolTip.text: redoControl.Accessible.description
                onClicked: root.redoRequested()
            }
        }

        Button {
            id: navigatorControl
            objectName: "navigatorButton"
            text: qsTr("Open navigator")
            visible: root.navigationActionsVisible
            Layout.fillWidth: true
            Accessible.description: qsTr("Open an interactive navigator for the current scene")
            ToolTip.visible: navigatorControl.hovered || navigatorControl.activeFocus
            ToolTip.text: navigatorControl.Accessible.description
            onClicked: root.navigatorRequested()
        }
    }
}
