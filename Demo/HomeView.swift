import SwiftUI
import AVFAudio
import CustomerVoice
import CustomerVoiceUI

struct PresentedCall: Identifiable { let id: String }
@MainActor struct HomeView: View {
    @ObservedObject private var voice: CustomerVoice
    let configurationError: String?
    init(configurationError: String?, voice: CustomerVoice = .shared) {
        self.configurationError = configurationError; _voice = ObservedObject(wrappedValue:voice)
    }
    @State private var login = false
    @State private var userID = ""
    @State private var token = ""
    @State private var busy = false
    @State private var error: String?
    @State private var presented: PresentedCall?
    var body: some View {
        ZStack {
            CustomerVoiceTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing:22) {
                    HStack { Text("CARESOFT").font(.headline).tracking(2); Spacer(); if voice.sessionState.session != nil { Button("Đăng xuất") { run { try await voice.logout() } }.accessibilityIdentifier("logout") } }
                    Image(systemName:"headphones.circle.fill").font(.system(size:82)).foregroundColor(CustomerVoiceTheme.accent).padding(.top,32).accessibilityHidden(true)
                    Text("Chăm sóc khách hàng").font(.largeTitle.bold()).multilineTextAlignment(.center)
                    Text("Chúng tôi luôn sẵn sàng hỗ trợ bạn").foregroundColor(CustomerVoiceTheme.secondary).multilineTextAlignment(.center)
                    VStack(spacing:10) {
                        Text(voice.sessionState.session.map { "Tài khoản \($0.userID)" } ?? "Chưa đăng nhập").font(.headline)
                        Label(voice.readiness.canCall ? "Sẵn sàng gọi hỗ trợ":"Chưa sẵn sàng gọi",systemImage:voice.readiness.canCall ? "checkmark.circle.fill":"info.circle")
                        Label(voice.readiness.canReceive ? "Sẵn sàng nhận cuộc gọi":"Chưa sẵn sàng nhận cuộc gọi",systemImage:voice.readiness.canReceive ? "checkmark.circle.fill":"info.circle")
                        ForEach(voice.readiness.reasons,id:\.self) { Text(reason($0)).font(.footnote).foregroundColor(CustomerVoiceTheme.secondary).multilineTextAlignment(.center) }
                    }.padding(24).frame(maxWidth:.infinity).background(.white,in:RoundedRectangle(cornerRadius:24))
                    Button(action:callSupport) {
                        Label("Gọi CSKH",systemImage:"phone.fill").font(.title3.bold()).frame(maxWidth:.infinity,minHeight:64)
                    }.buttonStyle(.borderedProminent).tint(CustomerVoiceTheme.accent).disabled(busy || !voice.readiness.canCall || DemoConfig.hotline.isEmpty).accessibilityIdentifier("callSupport")
                    if voice.sessionState.session == nil {
                        Button("Đăng nhập") { login = true }.buttonStyle(.bordered).accessibilityIdentifier("login")
                    }
                    if busy { ProgressView("Đang xử lý…") }
                    if let message = configurationError ?? error { Text(message).font(.footnote).foregroundColor(.red).accessibilityIdentifier("homeError") }
                    Text("Đầu số hỗ trợ do ứng dụng cấu hình.").font(.footnote).foregroundColor(CustomerVoiceTheme.secondary)
                }.padding(24).frame(maxWidth:560).frame(maxWidth:.infinity)
            }
        }.foregroundColor(CustomerVoiceTheme.ink)
        .sheet(isPresented:$login,onDismiss:{token = ""}) { loginForm }
        .fullScreenCover(item:$presented) { item in CustomerVoiceCallView(callID:item.id,voice:voice) { presented = nil }.interactiveDismissDisabled() }
        .onReceive(voice.$calls) { _ in DispatchQueue.main.async { syncCall() } }
        .onReceive(voice.events) { event in if event.type == "login_required" { login = true }; if event.type == "call_stopped" { syncCall() }; if event.code == "NETWORK_RECOVERY_TIMEOUT" { error = "Cuộc gọi đã kết thúc vì mất kết nối quá 30 giây." } }
        .task { requestMicrophone(); _ = try? await voice.checkReadiness(); syncCall() }
    }
    private var loginForm: some View {
        NavigationView {
            Form {
                Section(header:Text("Phiên do ứng dụng cung cấp")) {
                    TextField("User ID",text:$userID).keyboardType(.numberPad).textContentType(.username).accessibilityIdentifier("userID")
                    SecureField("API token của account",text:$token).textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("apiToken")
                    Text("Demo nhập trực tiếp để kiểm thử. Ứng dụng tích hợp truyền thông tin từ luồng đăng nhập của mình.").font(.footnote)
                }
                if let error { Text(error).foregroundColor(.red) }
                Button("Thực hiện đăng nhập") {
                    run { defer { token = "" }; _ = try await voice.login(userID:userID,tenantAPIToken:token); login = false; requestMicrophone() }
                }.disabled(busy || userID.isEmpty || token.isEmpty).accessibilityIdentifier("submitLogin")
            }.navigationTitle("Đăng nhập").toolbar { ToolbarItem(placement:.cancellationAction) { Button("Đóng") { login = false } } }
        }
    }
    private func syncCall() {
        if let presented, !voice.isCallPresentable(presented.id) { self.presented = nil }
        if presented == nil, let call = voice.calls.first(where:{voice.isCallPresentable($0.callID)}) { login = false; presented = PresentedCall(id:call.callID) }
    }
    private func callSupport() { run { _ = try await voice.call(businessNumber:DemoConfig.hotline); syncCall() } }
    private func requestMicrophone() { AVAudioSession.sharedInstance().requestRecordPermission { _ in Task { @MainActor in voice.resume() } } }
    private func run(_ operation: @escaping () async throws -> Void) {
        guard !busy else { return }; busy = true; error = nil
        Task { defer { busy = false }; do { try await operation() } catch { self.error = (error as? VoiceError)?.code ?? "Không thể thực hiện. Vui lòng kiểm tra kết nối." } }
    }
    private func reason(_ value: String) -> String {
        ["LOGIN_REQUIRED":"Đăng nhập để gọi và nhận cuộc gọi.","SESSION_UNVERIFIED":"Đang kiểm tra phiên với máy chủ.","VOICE_NOT_READY":"Dịch vụ gọi chưa sẵn sàng.","MICROPHONE_PERMISSION_REQUIRED":"Cho phép micro trong Cài đặt.","CALL_SYSTEM_UNAVAILABLE":"Hệ thống cuộc gọi chưa khả dụng.","INCOMING_UNSUPPORTED_ON_SIMULATOR":"Nhận cuộc gọi cần iPhone qua TestFlight.","PUSH_NOT_REGISTERED":"Chưa đăng ký nhận cuộc gọi qua APNs.","CALL_IN_PROGRESS":"Đang có cuộc gọi."][value] ?? value
    }
}
