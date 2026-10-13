pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Replaces Plasma's notification applet (which lived in the removed system tray).
Singleton {
    id: root

    readonly property list<Notification> list: server.trackedNotifications.values
    property list<Notification> popups: []

    function dismissPopup(n: Notification): void {
        root.popups = root.popups.filter(p => p !== n);
    }

    function clearAll(): void {
        for (const n of root.list.slice())
            n.dismiss();
        root.popups = [];
    }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            n.closed.connect(() => root.dismissPopup(n));
            if (!Visibilities.dnd || n.urgency === NotificationUrgency.Critical)
                root.popups = [n, ...root.popups];
        }
    }
}
