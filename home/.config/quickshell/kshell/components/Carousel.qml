import QtQuick
import qs.config

// Cover-flow row used by the wallpaper and theme pickers: the centred card is
// full size, the others shrink and fade towards the edges. Use CarouselCard
// as the delegate. Scroll or ←/→ (call increment/decrementCurrentIndex) to move.
PathView {
    id: view

    property int cardWidth: 320
    property int cardHeight: 200
    property int visibleCards: 7

    pathItemCount: Math.min(visibleCards, count)
    preferredHighlightBegin: 0.5
    preferredHighlightEnd: 0.5
    highlightRangeMode: PathView.StrictlyEnforceRange
    highlightMoveDuration: Appearance.anim.normal
    snapMode: PathView.SnapToItem

    path: Path {
        startX: 0
        startY: view.height / 2
        PathAttribute { name: "itemScale"; value: 0.68 }
        PathAttribute { name: "itemZ"; value: 0 }
        PathAttribute { name: "itemOpacity"; value: 0.45 }
        PathLine { x: view.width / 2; y: view.height / 2 }
        PathAttribute { name: "itemScale"; value: 1 }
        PathAttribute { name: "itemZ"; value: 10 }
        PathAttribute { name: "itemOpacity"; value: 1 }
        PathLine { x: view.width; y: view.height / 2 }
        PathAttribute { name: "itemScale"; value: 0.68 }
        PathAttribute { name: "itemZ"; value: 0 }
        PathAttribute { name: "itemOpacity"; value: 0.45 }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => (event.angleDelta.y || event.angleDelta.x) > 0
            ? view.decrementCurrentIndex() : view.incrementCurrentIndex()
    }
}
