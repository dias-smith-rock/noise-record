import FirebaseCore
import Foundation

/// Cold-start milestone timestamps for profiling.
nonisolated enum LaunchPerformance {
    enum Step: String {
        case launchAppInit
        case launchFirebaseConfigure
        case launchDelegateEntry
        case launchWindowAppear
        case launchProgressViewAppear
        case launchSwiftDataInit
        case launchAdMobStartRequested
        case launchAdMobStartCompleted
        case launchContentViewAppear
        case launchFirstInteractive
    }

    private static let processStart = CFAbsoluteTimeGetCurrent()
    private static var markedSteps = Set<Step>()
    private static var firstInteractiveReached = false
    private static var firstInteractiveWaiters: [CheckedContinuation<Void, Never>] = []
    private static let lock = NSLock()

    static var hasReachedFirstInteractive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return firstInteractiveReached
    }

    static func mark(_ step: Step) {
        lock.lock()
        let isFirstMark = !markedSteps.contains(step)
        if isFirstMark {
            markedSteps.insert(step)
        }

        if step == .launchFirstInteractive, !firstInteractiveReached {
            firstInteractiveReached = true
        }

        let waiters = step == .launchFirstInteractive && isFirstMark
            ? firstInteractiveWaiters
            : []
        if step == .launchFirstInteractive, isFirstMark {
            firstInteractiveWaiters.removeAll()
        }
        lock.unlock()

        guard isFirstMark else { return }

        let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - processStart) * 1000)

        #if DEBUG
        print("[Launch] \(step.rawValue) @ \(elapsedMs)ms")
        #endif

        if FirebaseApp.app() != nil {
            AppTelemetry.logEvent(
                "launch_milestone",
                parameters: [
                    "step": step.rawValue,
                    "elapsed_ms": elapsedMs,
                ]
            )
        }

        PerformanceSignpost.launchEvent(step.rawValue)

        for waiter in waiters {
            waiter.resume()
        }
    }

    static func whenFirstInteractive() async {
        if hasReachedFirstInteractive { return }
        await withCheckedContinuation { continuation in
            lock.lock()
            if firstInteractiveReached {
                lock.unlock()
                continuation.resume()
            } else {
                firstInteractiveWaiters.append(continuation)
                lock.unlock()
            }
        }
    }
}
