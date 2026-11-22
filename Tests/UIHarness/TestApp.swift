// Separate simulator-only test app. Never included in the shipping demo or SDK.
import SwiftUI
@testable import CustomerVoice

@main struct UITestApp: App {
    var body: some Scene { WindowGroup { HarnessRoot() } }
}
@MainActor struct HarnessRoot: View {
 @State private var generation=0
 @ObservedObject private var host=HarnessHost.shared
 var body: some View {
  VStack {
   HomeView(configurationError:nil,voice:Harness.voice,enterpriseSession:host.makeSession()).padding(.top,CGFloat(generation % 2))
   Button("Rebuild Home") {generation += 1}.accessibilityIdentifier("rebuildHome")
   Text("Host revocations: \(host.revocations)").accessibilityIdentifier("hostRevocations")
  }
 }
}
@MainActor final class HarnessHost: ObservableObject {
 static let shared=HarnessHost()
 @Published var revocations=0
 func makeSession() -> EnterpriseSession {
  EnterpriseSession(baseURL:URL(string:"https://enterprise.ui-test.invalid")!,prepare:{
   let p=try Harness.voice.prepareLogin()
   return ["attempt_id":p.attemptID,"installation_id":p.installationID,"os":p.platform,"application_id":p.applicationID,"push_environment":p.pushEnvironment,"code_challenge":p.codeChallenge,"code_challenge_method":p.codeChallengeMethod]
  },exchange:{a,t in _ = try await Harness.voice.loginWithTicket(attemptID:a,ticket:t)},nativeLogout:{try await Harness.voice.logout()},transport:{request in
   let path=request.url!.path;let value:[String:String]
   if path.hasSuffix("login") {value=["enterprise_access_token":"eyJhbGciOiJSUzI1NiJ9.fixture.signature"]}
   else if path.hasSuffix("bootstrap") {let body=try JSONSerialization.jsonObject(with:request.httpBody!) as! [String:String];value=["attempt_id":body["attempt_id"]!,"login_ticket":String(repeating:"t",count:43)]}
   else {self.revocations += 1;value=[:]}
   return (try JSONSerialization.data(withJSONObject:value),HTTPURLResponse(url:request.url!,statusCode:200,httpVersion:nil,headerFields:nil)!)
  })
 }
}
@MainActor enum Harness {
    static let voice: CustomerVoice = {
        let api = VoiceAPI(config:try! VoiceConfig(backendURL:URL(string:"https://ui-test.invalid")!,accountID:"20",appID:"fixture-app"),store:HarnessStore(),transport:HarnessHTTP())
        return CustomerVoice(api:api,system:HarnessSystem(),makeMedia:{HarnessMedia()})
    }()
}
@MainActor final class HarnessStore: VoiceSessionStore {
    var installationID = UUID().uuidString
    var value: Credentials?
    func load() throws -> Credentials? { value }
    func save(_ value: Credentials) throws { self.value = value }
    func clear() throws { value = nil }
    func save(_ value: Credentials, installationID: String) throws {self.value=value;self.installationID=installationID}
    func renewInstallationID() throws {installationID=UUID().uuidString.lowercased()}
}
@MainActor final class HarnessHTTP: VoiceHTTPTransport {
    let session = UUID().uuidString.lowercased(), id = UUID().uuidString.lowercased()
    var callState: String?, version = 0
    func snapshot() -> [String:Any] { ["call_id":id,"direction":"OUTBOUND","state":callState ?? "ENDED","version":version,"is_owner":true,"business_number":"18001234"] }
    func send(_ request: URLRequest) async throws -> VoiceHTTPResponse {
        let path = request.url!.path, date = ISO8601DateFormatter(), now = Date()
        var data: [String:Any] = [:]
        if path.hasSuffix("/sessions/exchange") || path.hasSuffix("/refresh") {
            data = ["user_id":"123","session_id":session,"access_token":String(repeating:"a",count:43),"refresh_token":String(repeating:"r",count:43),"expires_at":date.string(from:now.addingTimeInterval(900)),"refresh_expires_at":date.string(from:now.addingTimeInterval(86400)),"session_expires_at":date.string(from:now.addingTimeInterval(86400)),"auth_protocol":2]
        } else if path.hasSuffix("/configuration") { data = ["session_id":session,"user_id":"123","voice_ready":true,"push_registered":true] }
        else if path.hasSuffix("/media-token") { data = ["url":"wss://media.ui-test.invalid","token":"fixture-grant","expires_at":date.string(from:now.addingTimeInterval(60)),"call_control_token":"cvc_"+String(repeating:"c",count:43),"call_control_expires_at":date.string(from:now.addingTimeInterval(1800))] }
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
