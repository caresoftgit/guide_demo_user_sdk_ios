// Separate simulator-only test app. Never included in the shipping demo or SDK.
import SwiftUI
@testable import CustomerVoice

@main struct UITestApp: App {
    var body: some Scene { WindowGroup { HomeView(configurationError:nil,voice:Harness.voice) } }
}
@MainActor enum Harness {
    static let voice: CustomerVoice = {
        let api = VoiceAPI(config:try! VoiceConfig(backendURL:URL(string:"https://ui-test.invalid")!,accountID:"20",appID:"fixture-app"),store:HarnessStore(),transport:HarnessHTTP())
        return CustomerVoice(api:api,system:HarnessSystem(),makeMedia:{HarnessMedia()})
    }()
}
@MainActor final class HarnessStore: VoiceSessionStore {
    let installationID = UUID().uuidString
    var value: Credentials?
    func load() throws -> Credentials? { value }
    func save(_ value: Credentials) throws { self.value = value }
    func clear() throws { value = nil }
}
@MainActor final class HarnessHTTP: VoiceHTTPTransport {
    let session = UUID().uuidString.lowercased(), id = UUID().uuidString.lowercased()
    var callState: String?, version = 0
    func snapshot() -> [String:Any] { ["call_id":id,"direction":"OUTBOUND","state":callState ?? "ENDED","version":version,"is_owner":true,"business_number":"18001234"] }
    func send(_ request: URLRequest) async throws -> VoiceHTTPResponse {
        let path = request.url!.path, date = ISO8601DateFormatter(), now = Date()
        var data: [String:Any] = [:]
        if path.hasSuffix("/sessions") || path.hasSuffix("/refresh") {
            data = ["user_id":"123","session_id":session,"access_token":String(repeating:"a",count:43),"refresh_token":String(repeating:"r",count:43),"expires_at":date.string(from:now.addingTimeInterval(900)),"refresh_expires_at":date.string(from:now.addingTimeInterval(86400))]
        } else if path.hasSuffix("/configuration") { data = ["session_id":session,"user_id":"123","voice_ready":true,"push_registered":true] }
        else if path.hasSuffix("/media-token") { data = ["url":"wss://media.ui-test.invalid","token":"fixture-grant","expires_at":date.string(from:now.addingTimeInterval(60))] }
        else if path.hasSuffix("/hangup") { callState = "ENDED"; version += 1; data = snapshot() }
        else if request.httpMethod == "POST", path.hasSuffix("/calls") { callState = "ACTIVE"; version += 1; data = snapshot() }
        else if path.hasSuffix("/calls") { data = ["calls":callState == "ACTIVE" ? [snapshot()]:[]] }
        else if path.hasSuffix("/"+id) { data = snapshot() }
        if request.httpMethod == "DELETE" { return VoiceHTTPResponse(data:Data(),status:204) }
        return VoiceHTTPResponse(data:try JSONSerialization.data(withJSONObject:["data":data,"server_time":date.string(from:now)]),status:200)
    }
}
@MainActor final class HarnessSystem: VoiceCallSystem {
    var onAnswer: ((String) async throws -> Void)?; var onEnd: ((String) async -> Void)?
    var onMute: ((String,Bool) async throws -> Void)?; var onDTMF: ((String,String) async throws -> Void)?
    var onAudioChanged: ((Bool) -> Void)?; var onRoutesChanged: (() -> Void)?
    var microphoneGranted: Bool { true }; var ready: Bool { true }; var audioActive: Bool { true }
    func prepare(name: String) throws {}
    func reportIncoming(id: String,name: String,completion: @escaping () -> Void) { completion() }
    func start(id: String,handle: String) async throws {}
    func reportConnected(id: String) {}
    func requestAnswer(id: String) async throws { try await onAnswer?(id) }
    func requestMute(id: String,muted: Bool) async throws { try await onMute?(id,muted) }
    func end(id: String,reason: String) {}
    func routes() -> [AudioRoute] { [AudioRoute(id:"receiver",name:"Loa thoại",selected:true)] }
    func selectRoute(id: String) throws {}
}
@MainActor final class HarnessMedia: VoiceMedia {
    var onDisconnected: (() -> Void)?
    var onConnectionStateChanged: ((CallConnectionState) -> Void)?
    func connect(url: String,token: String) async throws {}
    func publishMicrophone(muted: Bool) async throws { onConnectionStateChanged?(.connected) }
    func setMuted(_ muted: Bool) async throws {}
    func sendDTMF(code: UInt32,digit: String) async throws {}
    func stop() {}
    func disconnect() async {}
}
