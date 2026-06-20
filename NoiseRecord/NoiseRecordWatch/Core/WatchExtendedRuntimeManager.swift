import AVFoundation
import Foundation
import WatchKit

@MainActor
final class WatchExtendedRuntimeManager: NSObject, WKExtendedRuntimeSessionDelegate {
    private var session: WKExtendedRuntimeSession?
    var onInvalidated: ((String) -> Void)?

    var isActive: Bool { session != nil }

    func start() {
        guard session == nil else { return }
        let runtime = WKExtendedRuntimeSession()
        runtime.delegate = self
        runtime.start()
        session = runtime
    }

    func stop() {
        session?.invalidate()
        session = nil
    }

    nonisolated func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: Error?
    ) {
        let message: String
        switch reason {
        case .none:
            message = ""
        case .error:
            message = error?.localizedDescription ?? WatchL10n.runtimeError
        case .expired:
            message = WatchL10n.runtimeExpired
        case .resignedFrontmost:
            message = WatchL10n.runtimeResigned
        case .suppressedBySystem:
            message = WatchL10n.runtimeSuppressed
        @unknown default:
            message = WatchL10n.runtimeEnded
        }

        Task { @MainActor in
            self.session = nil
            if !message.isEmpty {
                self.onInvalidated?(message)
            }
        }
    }

    nonisolated func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}

    nonisolated func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        Task { @MainActor in
            self.onInvalidated?(WatchL10n.runtimeWillExpire)
        }
    }
}
