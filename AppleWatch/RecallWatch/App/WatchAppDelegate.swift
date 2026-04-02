import OSLog
import WatchKit

private let logger = Logger(subsystem: "com.recall.watch", category: "AppDelegate")

final class WatchAppDelegate: NSObject, WKApplicationDelegate, Sendable {
    func applicationDidFinishLaunching() {
        logger.info("App did finish launching")
    }

    func applicationDidBecomeActive() {
        logger.info("App became active")
        Task { @MainActor in
            if let manager = LaunchSequence.extendedRuntimeManager {
                manager.restoreStateAfterResume()
                manager.start()
            }
        }
    }

    func applicationWillResignActive() {
        logger.info("App will resign active")
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            switch task {
            case let urlTask as WKURLSessionRefreshBackgroundTask:
                BackgroundURLSessionManager.shared.setCompletionHandler({}, for: urlTask.sessionIdentifier)
                urlTask.setTaskCompletedWithSnapshot(false)
            default:
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
}
