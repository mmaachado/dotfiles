import QtQuick
import qs.components
import qs.config

Rectangle {
    id: btn
    property string label
    property bool primary
    signal clicked

    implicitWidth: btnLabel.implicitWidth + 28
    implicitHeight: 34
    radius: height / 2
    color: primary ? Appearance.colors.primary : Appearance.colors.surfaceHigh

    StyledText {
        id: btnLabel
        anchors.centerIn: parent
        text: btn.label
        color: btn.primary ? Appearance.colors.onPrimary : Appearance.colors.text
    }
    StateLayer {
        tint: btn.primary ? Appearance.colors.onPrimary : Appearance.colors.text
        onClicked: btn.clicked()
    }
}
