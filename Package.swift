// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "VoiceHostBootstrap", platforms: [.macOS(.v12)], targets: [
 .target(name: "VoiceHostBootstrap", path: "Demo", exclude: ["DemoApp.swift", "HomeView.swift", "DemoConfig.swift", "Info.plist", "Demo.entitlements", "Config", "Images.xcassets", "CustomerVoiceDemo.xcodeproj", "CustomerVoiceDemo.xcworkspace", "Podfile", "Podfile.lock", "Pods"], sources: ["HostBackend.swift"]),
 .testTarget(name: "VoiceHostBootstrapTests", dependencies: ["VoiceHostBootstrap"], path: "Tests/HostSession")
])
