import WatchKit

final class WatchAppDelegate: NSObject, WKApplicationDelegate, Sendable {
    func applicationDidFinishLaunching() {
        // App launch setup
    }

    func applicationDidBecomeActive() {
        // Resume tasks
    }

    func applicationWillResignActive() {
        // Pause tasks
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
