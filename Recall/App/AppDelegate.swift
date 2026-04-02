import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate, Sendable {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        true
    }

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping @Sendable () -> Void
    ) {
        BackgroundURLSessionManager.shared.setCompletionHandler(completionHandler, for: identifier)
    }
}
