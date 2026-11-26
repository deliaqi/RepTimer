import SwiftUI
import UIKit

final class RepTimerAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Register HealthKit observer queries synchronously on launch so background wakes
        // from HealthKit Background Delivery immediately refresh the widget cache.
        CalorieHealthManager.shared.registerBackgroundObserversIfNeeded()
        return true
    }
}

@main
struct RepTimerApp: App {
    @UIApplicationDelegateAdaptor(RepTimerAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await CalorieHealthManager.shared.handleAppBecameActive()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task {
                            await CalorieHealthManager.shared.handleAppBecameActive()
                        }
                    }
                }
        }
    }
}
