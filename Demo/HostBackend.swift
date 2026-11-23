import Foundation

enum HostBackendError: String, Error {
    case hostLoginRequired = "HOST_LOGIN_REQUIRED"
    case requestFailed = "BOOTSTRAP_REQUEST_FAILED"
    case invalidResponse = "INVALID_BOOTSTRAP_RESPONSE"
    case invalidPreparation = "INVALID_PREPARATION"
    case httpsRequired = "HTTPS_HOST_REQUIRED"
}

/// Supply the application's authenticated HTTP client when it does not use URLSession.shared cookies.
@MainActor struct HostBackend {
    typealias Transport = (URLRequest) async throws -> (Data, HTTPURLResponse)
    let url: URL
    var transport: Transport = { request in
        let (bytes, response) = try await URLSession.shared.bytes(for: request, delegate: HostNoRedirect())
        guard let http = response as? HTTPURLResponse else { throw HostBackendError.requestFailed }
        var data = Data()
        for try await byte in bytes {
            guard data.count < 16384 else { throw HostBackendError.invalidResponse }
            data.append(byte)
        }
        return (data, http)
    }

    func requestTicket(_ preparation: [String:String]) async throws -> String {
        guard url.scheme == "https", let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else {
            throw HostBackendError.httpsRequired
        }
        let fields = ["attempt_id", "installation_id", "os", "application_id", "push_environment", "code_challenge", "code_challenge_method"]
        guard fields.allSatisfy({ !(preparation[$0] ?? "").isEmpty }) else { throw HostBackendError.invalidPreparation }
        let body = Dictionary(uniqueKeysWithValues: fields.map { ($0, preparation[$0]!) })
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        do {
            let (data, response) = try await transport(request)
            guard response.url == url else { throw HostBackendError.requestFailed }
            if response.statusCode == 401 { throw HostBackendError.hostLoginRequired }
            guard (200..<300).contains(response.statusCode) else { throw HostBackendError.requestFailed }
            guard data.count <= 16384,
                  let ticket = try? JSONSerialization.jsonObject(with: data) as? [String:Any],
                  ticket["attempt_id"] as? String == preparation["attempt_id"],
                  let value = ticket["login_ticket"] as? String,
                  value.range(of: "^[A-Za-z0-9_-]{43}$", options: .regularExpression) != nil,
                  let expires = ticket["expires_at"] as? String else { throw HostBackendError.invalidResponse }
            let date = ISO8601DateFormatter()
            date.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let fractional = date.date(from: expires)
            date.formatOptions = [.withInternetDateTime]
            guard fractional != nil || date.date(from: expires) != nil else { throw HostBackendError.invalidResponse }
            return value
        } catch let error as HostBackendError { throw error }
        catch { throw HostBackendError.requestFailed }
    }
}

private final class HostNoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
