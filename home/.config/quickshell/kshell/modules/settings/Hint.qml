import QtQuick
import qs.components
import qs.config

StyledText {
    width: parent?.width ?? 0
    color: Appearance.colors.textDim
    font.pointSize: Appearance.font.small
    wrapMode: Text.WordWrap
    elide: Text.ElideNone
}
