import Flutter
import UIKit
import FirebaseCore
import FirebaseFirestore

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let CHANNEL = "com.talkone.app/ai_filter"
  private var videoFrameProcessor: AgoraVideoFrameProcessor?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Firebase初期化
    FirebaseApp.configure()
    
    // Firebase Cache Index設定
    let db = Firestore.firestore()
    db.persistentCacheIndexManager?.enableIndexAutoCreation()
    
    GeneratedPluginRegistrant.register(with: self)
    
    // Set up Flutter method channel safely
    if let controller = window?.rootViewController as? FlutterViewController {
      let aiFilterChannel = FlutterMethodChannel(name: CHANNEL, binaryMessenger: controller.binaryMessenger)
      setupMethodChannel(aiFilterChannel)
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func setupMethodChannel(_ aiFilterChannel: FlutterMethodChannel) {
    
    aiFilterChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "initializeAIFilter":
        self?.initializeAIFilter()
        result(true)
        
      case "enableAIFilter":
        if let args = call.arguments as? [String: Any],
           let enabled = args["enabled"] as? Bool {
          self?.enableAIFilter(enabled)
          result(true)
        } else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing enabled parameter", details: nil))
        }
        
      case "setFilterParams":
        if let args = call.arguments as? [String: Any],
           let threshold1 = args["threshold1"] as? Int,
           let threshold2 = args["threshold2"] as? Int,
           let colorful = args["colorful"] as? Bool {
          self?.setFilterParams(threshold1: threshold1, threshold2: threshold2, colorful: colorful)
          result(true)
        } else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing filter parameters", details: nil))
        }
        
      case "releaseAIFilter":
        self?.releaseAIFilter()
        result(true)
        
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
  
  // MARK: - AI Filter Methods
  
  private func initializeAIFilter() {
    if videoFrameProcessor == nil {
      videoFrameProcessor = AgoraVideoFrameProcessor()
    }
    print("iOS AI Filter initialized")
  }
  
  private func enableAIFilter(_ enabled: Bool) {
    videoFrameProcessor?.setFilterEnabled(enabled)
    print("iOS AI Filter enabled: \(enabled)")
  }
  
  private func setFilterParams(threshold1: Int, threshold2: Int, colorful: Bool) {
    videoFrameProcessor?.setFilterParams(threshold1: threshold1, threshold2: threshold2, colorful: colorful)
    print("iOS AI Filter params set: \(threshold1), \(threshold2), \(colorful)")
  }
  
  private func releaseAIFilter() {
    videoFrameProcessor?.release()
    videoFrameProcessor = nil
    print("iOS AI Filter released")
  }
  
  override func applicationWillTerminate(_ application: UIApplication) {
    releaseAIFilter()
    super.applicationWillTerminate(application)
  }
}
