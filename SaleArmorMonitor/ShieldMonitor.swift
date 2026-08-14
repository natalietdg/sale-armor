import DeviceActivity
import ManagedSettings
import Foundation

/// **The part that works while the app is closed.**
///
/// iOS wakes this at the edges of every scheduled interval. A pattern can own several intervals —
/// three chosen weekdays is three activities — so both callbacks match on the shared prefix rather
/// than on one name.
///
/// It reads the armed window from the app group rather than being handed one, because the process
/// that scheduled the interval is long gone by the time it fires.
class ShieldMonitor: DeviceActivityMonitor {

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard activity.rawValue.hasPrefix(ArmorSchedule.prefix),
              let window = ArmorStore.load() else { return }
        Shield.raise(for: window)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity.rawValue.hasPrefix(ArmorSchedule.prefix) else { return }

        // **Drop first.** Apps left shut after a window is the failure with no easy escape.
        Shield.drop()

        // A one-off window is spent once it ends. Repeating patterns stay armed for next time,
        // so the saved window must survive — clearing it here would disarm every daily guard
        // the first morning it finished.
        if let window = ArmorStore.load(), case .dateRange = window.pattern {
            ArmorStore.save(nil)
        }
    }
}
