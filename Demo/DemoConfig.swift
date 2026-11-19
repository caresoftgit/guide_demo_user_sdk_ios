import Foundation
import CustomerVoice

enum DemoConfig {
    static func value(_ key: String) throws -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey:key) as? String,
              !value.isEmpty, !value.contains("$("), !value.contains("REPLACE") else { throw VoiceError("DEMO_CONFIGURATION_REQUIRED") }
        return value
    }
    static func voice() throws -> VoiceConfig {
        guard let url = URL(string:try value("VoiceBackendURL")) else { throw VoiceError("DEMO_CONFIGURATION_REQUIRED") }
        return try VoiceConfig(backendURL:url,accountID:value("VoiceAccountID"),appID:value("VoiceAppID"),pushEnvironment:.production)
    }
    static var hotline: String { (try? value("VoiceHotline")) ?? "" }
}
