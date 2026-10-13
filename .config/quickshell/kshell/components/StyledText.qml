import QtQuick
import qs.config

Text {
    color: Appearance.colors.text
    font.family: Appearance.font.family
    font.pointSize: Appearance.font.normal
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering

    Behavior on color {
        ColorAnimation { duration: Appearance.anim.fast }
    }
}
