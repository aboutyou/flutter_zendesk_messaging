import Flutter
import UIKit
import ZendeskSDKMessaging

public class SwiftZendeskMessagingPlugin: NSObject, FlutterPlugin, UNUserNotificationCenterDelegate {
    let TAG = "[SwiftZendeskMessagingPlugin]"
    private var channel: FlutterMethodChannel
    private var zendeskMessaging: ZendeskMessaging?
    var isInitialized = false
    var isLoggedIn = false
    var pushNotificationsDisabled = false
    private var pendingNotificationTap: [AnyHashable: Any]? = nil


    init(channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()
        self.zendeskMessaging = ZendeskMessaging(flutterPlugin: self, channel: channel)
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "zendesk_messaging", binaryMessenger: registrar.messenger())
        let instance = SwiftZendeskMessagingPlugin(channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
    }

    // Captures cold-start notification taps. launchOptions is the only
    // reliable source on iOS because it is populated before the Flutter
    // engine (and therefore the UNUserNotificationCenterDelegate) is ready.
    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [AnyHashable: Any] = [:]
    ) -> Bool {
        // Store unconditionally — shouldBeDisplayed cannot be called here because
        // the Zendesk SDK is not yet initialized. Validation happens in
        // consumePendingNotificationTap after the SDK is ready.
        if let userInfo = launchOptions[UIApplication.LaunchOptionsKey.remoteNotification] as? [AnyHashable: Any] {
            pendingNotificationTap = userInfo
        }
        return true
    }

    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       willPresent notification: UNNotification,
                                       withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        let shouldBeDisplayed = PushNotifications.shouldBeDisplayed(userInfo)

        let displayNotification = {
            if #available(iOS 14.0, *) {
                completionHandler([.banner, .sound, .badge])
            } else {
                completionHandler([.alert, .sound, .badge])
            }
        }

        switch shouldBeDisplayed {
        case .messagingShouldDisplay:
            if !pushNotificationsDisabled {
                displayNotification()
            } else {
                completionHandler([])
            }
        case .messagingShouldNotDisplay:
            completionHandler([])
        case .notFromMessaging:
            return
        @unknown default:
            break
        }
    }

    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       didReceive response: UNNotificationResponse,
                                       withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        let shouldBeDisplayed = PushNotifications.shouldBeDisplayed(userInfo)

        switch shouldBeDisplayed {
        case .messagingShouldDisplay:
            // Always route through Flutter navigation. Using PushNotifications.handleTap
            // presents Zendesk's native VC outside Flutter's hierarchy, causing a black
            // screen when the SDK connection is in a transitional state.
            pendingNotificationTap = userInfo
            if isInitialized {
                channel.invokeMethod("onZendeskNotificationTapped", arguments: nil)
            }
        case .messagingShouldNotDisplay:
            break
        case .notFromMessaging:
            return
        @unknown default: break
        }

        completionHandler()
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            self.processMethodCall(call, result: result)
        }
    }

    private func processMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let method = call.method
        let arguments = call.arguments as? Dictionary<String, Any>

        switch method {
        case "initialize":
            let channelKey: String = (arguments?["channelKey"] ?? "") as! String
            zendeskMessaging?.initialize(channelKey: channelKey, flutterResult: result)

        case "show":
            if !isInitialized {
                print("\(TAG) - Messaging needs to be initialized first.\n")
                reportNotInitializedFlutterError(result: result)
                return
            }
            zendeskMessaging?.show(rootViewController: getRootViewController(), flutterResult: result)

        case "showConversation":
            if !isInitialized {
                print("\(TAG) - Messaging needs to be initialized first.\n")
                reportNotInitializedFlutterError(result: result)
                return
            }
            guard let conversationId = arguments?["conversationId"] as? String, !conversationId.isEmpty else {
                result(FlutterError(code: "invalid_argument", message: "conversationId is required", details: nil))
                return
            }
            zendeskMessaging?.showConversation(conversationId: conversationId, rootViewController: getRootViewController(), flutterResult: result)

        case "showConversationList":
            if !isInitialized {
                print("\(TAG) - Messaging needs to be initialized first.\n")
                reportNotInitializedFlutterError(result: result)
                return
            }
            zendeskMessaging?.showConversationList(rootViewController: getRootViewController(), flutterResult: result)

        case "startNewConversation":
            if !isInitialized {
                print("\(TAG) - Messaging needs to be initialized first.\n")
                reportNotInitializedFlutterError(result: result)
                return
            }
            zendeskMessaging?.startNewConversation(rootViewController: getRootViewController(), flutterResult: result)

        case "loginUser":
            if !isInitialized {
                print("\(TAG) - Messaging needs to be initialized first.\n")
                reportNotInitializedFlutterError(result: result)
                return
            }
            let jwt: String = arguments?["jwt"] as? String ?? ""
            zendeskMessaging?.loginUser(jwt: jwt, flutterResult: result)

        case "logoutUser":
            if !isInitialized {
                print("\(TAG) - Messaging needs to be initialized first.\n")
                reportNotInitializedFlutterError(result: result)
                return
            }
            zendeskMessaging?.logoutUser(flutterResult: result)

        case "getCurrentUser":
            if !isInitialized {
                print("\(TAG) - Messaging needs to be initialized first.\n")
                reportNotInitializedFlutterError(result: result)
                return
            }
            zendeskMessaging?.getCurrentUser(flutterResult: result)

        case "getUnreadMessageCount":
            if !isInitialized {
                print("\(TAG) - Messaging needs to be initialized first.\n")
                reportNotInitializedFlutterError(result: result)
                return
            }
            result(handleMessageCount())

        case "getUnreadMessageCountForConversation":
            if !isInitialized {
                print("\(TAG) - Messaging needs to be initialized first.\n")
                reportNotInitializedFlutterError(result: result)
                return
            }
            guard let conversationId = arguments?["conversationId"] as? String, !conversationId.isEmpty else {
                result(FlutterError(code: "invalid_argument", message: "conversationId is required", details: nil))
                return
            }
            result(zendeskMessaging?.getUnreadMessageCountForConversation(conversationId: conversationId) ?? 0)

        case "listenUnreadMessages":
            if !isInitialized {
                print("\(TAG) - Messaging needs to be initialized first.\n")
                reportNotInitializedFlutterError(result: result)
                return
            }
            zendeskMessaging?.listenMessageCountChanged()
            result(nil)

        case "getConnectionStatus":
            if !isInitialized {
                print("\(TAG) - Messaging needs to be initialized first.\n")
                reportNotInitializedFlutterError(result: result)
                return
            }
            result(zendeskMessaging?.getConnectionStatus() ?? "unknown")

        case "isInitialized":
            result(handleInitializedStatus())

        case "isLoggedIn":
            result(handleLoggedInStatus())

        case "setConversationTags":
            if !isInitialized {
                print("\(TAG) - Messaging needs to be initialized first.\n")
                reportNotInitializedFlutterError(result: result)
                return
            }
            let tags: [String] = arguments?["tags"] as? [String] ?? []
            zendeskMessaging?.setConversationTags(tags: tags)
            result(nil)

        case "clearConversationTags":
            if !isInitialized {
                print("\(TAG) - Messaging needs to be initialized first.\n")
                reportNotInitializedFlutterError(result: result)
                return
            }
            zendeskMessaging?.clearConversationTags()
            result(nil)

        case "setConversationFields":
            if !isInitialized {
                print("\(TAG) - Messaging needs to be initialized first.\n")
                reportNotInitializedFlutterError(result: result)
                return
            }
            let fields: [String: String] = arguments?["fields"] as? [String: String] ?? [:]
            zendeskMessaging?.setConversationFields(fields: fields)
            result(nil)

        case "clearConversationFields":
            if !isInitialized {
                print("\(TAG) - Messaging needs to be initialized first.\n")
                reportNotInitializedFlutterError(result: result)
                return
            }
            zendeskMessaging?.clearConversationFields()
            result(nil)
        case "checkAndDisplayFirebaseNotification":
            // iOS uses APNs directly via UNUserNotificationCenterDelegate, not Firebase
            result(false)

        case "setLoggable":
            let isLoggable: Bool = arguments?["isLoggable"] as? Bool ?? false
            zendeskMessaging?.setLoggable(isLoggable: isLoggable)
            result(nil)

        case "disablePushNotifications":
            pushNotificationsDisabled = arguments?["pushNotificationsDisabled"] as? Bool ?? false
            result(nil)

        case "invalidate":
            if !isInitialized {
                print("\(TAG) - Messaging is already on an invalid state\n")
                reportNotInitializedFlutterError(result: result)
                return
            }
            zendeskMessaging?.invalidate()
            result(nil)

        // ================================================================
        // Push Notifications
        // ================================================================

        case "updatePushNotificationToken":
            if !isInitialized {
                print("\(TAG) - Messaging needs to be initialized first.\n")
                reportNotInitializedFlutterError(result: result)
                return
            }
            guard let token = arguments?["token"] as? String, !token.isEmpty else {
                result(FlutterError(code: "invalid_argument", message: "token is required", details: nil))
                return
            }
            zendeskMessaging?.updatePushNotificationToken(token: token)
            result(nil)

        case "shouldBeDisplayed":
            guard let messageData = arguments?["messageData"] as? [String: Any] else {
                result(FlutterError(code: "invalid_argument", message: "messageData is required", details: nil))
                return
            }
            let responsibility = zendeskMessaging?.shouldBeDisplayed(messageData) ?? "unknown"
            result(responsibility)

        case "handleNotification":
            guard let messageData = arguments?["messageData"] as? [String: Any] else {
                result(FlutterError(code: "invalid_argument", message: "messageData is required", details: nil))
                return
            }
            let handled = zendeskMessaging?.handleNotification(messageData) ?? false
            result(handled)

        case "handleNotificationTap":
            if !isInitialized {
                print("\(TAG) - Messaging needs to be initialized first.\n")
                reportNotInitializedFlutterError(result: result)
                return
            }
            guard let messageData = arguments?["messageData"] as? [String: Any] else {
                result(FlutterError(code: "invalid_argument", message: "messageData is required", details: nil))
                return
            }
            zendeskMessaging?.handleNotificationTap(
                messageData,
                rootViewController: getRootViewController()
            ) { success in
                result(nil)
            }

        case "consumePendingNotificationTap":
            guard let userInfo = pendingNotificationTap else {
                result(false)
                return
            }
            pendingNotificationTap = nil
            // Validate now — Zendesk is initialized at this call site
            result(PushNotifications.shouldBeDisplayed(userInfo) == .messagingShouldDisplay)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleMessageCount() -> Int {
        return zendeskMessaging?.getUnreadMessageCount() ?? 0
    }

    private func handleInitializedStatus() -> Bool {
        return isInitialized
    }

    private func handleLoggedInStatus() -> Bool {
        return isLoggedIn
    }

    private func getRootViewController() -> UIViewController? {
        // Scene-based window resolution (supports UISceneDelegate)
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first(where: { $0.activationState == .foregroundInactive })

        if let windowScene = windowScene {
            let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow })
                ?? windowScene.windows.first
            return keyWindow?.rootViewController
        }

        // Fallback for non-scene setups
        return UIApplication.shared.delegate?.window??.rootViewController
    }

    private func reportNotInitializedFlutterError(result: FlutterResult) {
        result(FlutterError(
            code: "not_initialized",
            message: "Zendesk SDK needs to be initialized first",
            details: nil)
        )
    }
}
