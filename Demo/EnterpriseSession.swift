import Foundation

enum EnterpriseSessionError: String, Error { case invalidResponse = "INVALID_ENTERPRISE_RESPONSE", requestFailed = "ENTERPRISE_REQUEST_FAILED", sessionChanged = "SESSION_CHANGED", httpsRequired = "HTTPS_HOST_REQUIRED" }

/** Demo host bearer is memory-only. Production apps supply their durable enterprise session/logout. */
@MainActor final class EnterpriseSession {
    typealias Transport = (URLRequest) async throws -> (Data, HTTPURLResponse)
    private let baseURL: URL
    private let prepare: () async throws -> [String:String]
    private let exchange: (String,String) async throws -> Void
    private let nativeLogout: () async throws -> Void
    private let transport: Transport
    private var bearer: String?
    private var epoch = 0
    init(baseURL: URL, prepare: @escaping () async throws -> [String:String], exchange: @escaping (String,String) async throws -> Void, nativeLogout: @escaping () async throws -> Void, transport: @escaping Transport = { request in
        let config=URLSessionConfiguration.ephemeral;config.httpCookieStorage=nil;config.timeoutIntervalForResource=5
        let session=URLSession(configuration:config,delegate:EnterpriseNoRedirect(),delegateQueue:nil)
        defer {session.invalidateAndCancel()}
        let (bytes,response) = try await session.bytes(for:request)
        var data=Data()
        for try await byte in bytes {guard data.count<16384 else {throw EnterpriseSessionError.requestFailed};data.append(byte)}
        guard let http = response as? HTTPURLResponse else { throw EnterpriseSessionError.requestFailed }
        return (data,http)
    }) { self.baseURL=baseURL; self.prepare=prepare; self.exchange=exchange; self.nativeLogout=nativeLogout; self.transport=transport }
    private func check(_ captured: Int) throws { if captured != epoch { throw EnterpriseSessionError.sessionChanged } }
    private func request(_ route: String, _ body: [String:String], token: String?) async throws -> [String:Any] {
        guard baseURL.scheme == "https", baseURL.host != nil, baseURL.user == nil, baseURL.password == nil, baseURL.query == nil, baseURL.fragment == nil,
              let url = URL(string:baseURL.absoluteString.trimmingCharacters(in:CharacterSet(charactersIn:"/"))+route) else { throw EnterpriseSessionError.httpsRequired }
        var request=URLRequest(url:url,cachePolicy:.reloadIgnoringLocalCacheData,timeoutInterval:5)
        request.httpMethod="POST";request.httpBody=try JSONSerialization.data(withJSONObject:body);request.setValue("application/json",forHTTPHeaderField:"Content-Type")
        if let token {request.setValue("Bearer "+token,forHTTPHeaderField:"Authorization")}
        do {
            let (data,response)=try await transport(request)
            guard response.url == url, (200..<300).contains(response.statusCode), data.count <= 16384 else { throw EnterpriseSessionError.requestFailed }
            if data.isEmpty { return [:] }
            guard let value=try JSONSerialization.jsonObject(with:data) as? [String:Any] else { throw EnterpriseSessionError.invalidResponse };return value
        } catch { throw EnterpriseSessionError.requestFailed }
    }
    func login(username: String, password: String) async throws {
        epoch += 1;let captured=epoch
        if bearer != nil { try await retryLogout() }
        try check(captured)
        let auth=try await request("/api/auth/login",["username":username,"password":password],token:nil)
        guard let token=auth["enterprise_access_token"] as? String,token.count <= 8192,token.range(of:"^[A-Za-z0-9._~+/-]+=*$",options:.regularExpression) != nil else { throw EnterpriseSessionError.invalidResponse }
        if captured != epoch { _ = try? await request("/api/auth/logout",[:],token:token);throw EnterpriseSessionError.sessionChanged }
        bearer=token
        let preparation=try await prepare();try check(captured)
        let ticket=try await request("/api/voice/bootstrap",preparation,token:token);try check(captured)
        guard let attempt=preparation["attempt_id"],ticket["attempt_id"] as? String == attempt,let value=ticket["login_ticket"] as? String,value.range(of:"^[A-Za-z0-9_-]{43}$",options:.regularExpression) != nil else {throw EnterpriseSessionError.invalidResponse}
        try await exchange(attempt,value);try check(captured)
    }
    func retryLogout() async throws { try await revoke(bearer) }
    private func revoke(_ captured: String?) async throws {
        guard let token=captured else {return}
        _ = try await request("/api/auth/logout",[:],token:token)
        if bearer == token {bearer=nil}
    }
    func logout() async throws {
        let captured=bearer
        epoch += 1;var failure: Error?
        do { try await nativeLogout() } catch { failure=error }
        try await revoke(captured)
        if let failure {throw failure}
    }
}

private final class EnterpriseNoRedirect: NSObject, URLSessionTaskDelegate {
 func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {completionHandler(nil)}
}
