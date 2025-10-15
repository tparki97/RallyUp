import SwiftUI
import UIKit
import FirebaseCore
import FirebaseAuth

// Real UIApplicationDelegate so Firebase’s swizzler is happy.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()

        // Anonymous Auth (Simulator-friendly)
        if Auth.auth().currentUser == nil {
            Auth.auth().signInAnonymously { result, error in
                if let error = error {
                    print("Anonymous sign-in failed: \(error.localizedDescription)")
                } else if let user = result?.user {
                    print("Anonymous sign-in OK. uid=\(user.uid)")
                }
            }
        } else if let user = Auth.auth().currentUser {
            print("Already signed in. uid=\(user.uid)")
        }
        return true
    }
}

@main
struct RallyUpApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authService = AuthService()
    @StateObject private var userStore = UserStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(userStore)
        }
    }
}
