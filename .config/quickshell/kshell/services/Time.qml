pragma Singleton

import QtQuick
import Quickshell

Singleton {
    readonly property date now: clock.date
    // Matches the old Plasma digital clock setting (12-hour). Set to true for 24-hour.
    property bool use24h: false

    function format(fmt: string): string {
        return Qt.formatDateTime(clock.date, fmt);
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
