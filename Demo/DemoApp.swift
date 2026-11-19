import SwiftUI
import UIKit
import UserNotifications
import CustomerVoice
import CustomerVoiceUI

@MainActor final class DemoDelegate: NSObject, UIApplicationDelegate {
    var configurationError: String?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        do { try CustomerVoice.shared.initialize(config:DemoConfig.voice()) }
        catch {
            configurationError = "Không thể khởi tạo cuộc gọi. Kiểm tra cấu hình demo và quyền hệ thống."
            #if DEBUG
            print("Demo initialization code:", (error as? VoiceError)?.code ?? (error as NSError).domain)
            #endif
        }
        #if !targetEnvironment(simulator)
        application.registerForRemoteNotifications()
        UNUserNotificationCenter.current().requestAuthorization(options:[.alert,.sound,.badge]) { _,_ in }
        #endif
        return true
    }
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        CustomerVoice.shared.didRegisterForRemoteNotifications(deviceToken:deviceToken)
    }
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Task { let handled = await CustomerVoice.shared.handleRemoteNotification(userInfo); completionHandler(handled ? .newData:.noData) }
    }
}
@main struct CustomerVoiceDemoApp: App {
    @UIApplicationDelegateAdaptor(DemoDelegate.self) var delegate
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup { HomeView(configurationError:delegate.configurationError).onChange(of:phase) { if $0 == .active { CustomerVoice.shared.resume() } } }
    }
}
