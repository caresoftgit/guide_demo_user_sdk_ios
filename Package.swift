// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "EnterpriseDemoAuth", platforms: [.macOS(.v12)], targets: [
 .target(name: "EnterpriseDemoAuth", path: "Demo", exclude: ["DemoApp.swift", "HomeView.swift", "DemoConfig.swift", "Info.plist", "Demo.entitlements", "Config", "Images.xcassets", "CustomerVoiceDemo.xcodeproj", "CustomerVoiceDemo.xcworkspace", "Podfile", "Podfile.lock", "Pods"], sources: ["EnterpriseSession.swift"]),
 .testTarget(name: "EnterpriseDemoAuthTests", dependencies: ["EnterpriseDemoAuth"], path: "Tests/HostSession")
])
