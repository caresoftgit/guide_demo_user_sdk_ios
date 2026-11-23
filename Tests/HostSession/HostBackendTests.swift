import XCTest
@testable import VoiceHostBootstrap
@MainActor final class HostBackendTests: XCTestCase {
    let url = URL(string:"https://app.example.com/api/voice/bootstrap")!
    let preparation = ["attempt_id":"00000000-0000-4000-8000-000000000001", "installation_id":"00000000-0000-4000-8000-000000000002", "os":"ios", "application_id":"com.example.app", "push_environment":"production", "code_challenge":String(repeating:"c",count:43), "code_challenge_method":"S256"]
    func ticket() -> [String:Any] { ["attempt_id":preparation["attempt_id"]!,"login_ticket":String(repeating:"t",count:43),"expires_at":"2099-01-01T00:00:00.123Z"] }
    func testUsesExistingApplicationTransportAndOnlySevenPublicFields() async throws {
        var requests = [URLRequest]()
        let host = HostBackend(url:url, transport:{ request in
            requests.append(request)
            return (try JSONSerialization.data(withJSONObject:self.ticket()),HTTPURLResponse(url:self.url,statusCode:200,httpVersion:nil,headerFields:nil)!)
        })
        var extra = preparation; extra["user_id"]="untrusted"; extra["api_token"]="must-not-forward"
        let value = try await host.requestTicket(extra); XCTAssertEqual(value,String(repeating:"t",count:43))
        XCTAssertEqual(requests.count,1); let request=try XCTUnwrap(requests.first)
        XCTAssertEqual(request.url,url); XCTAssertEqual(request.httpMethod,"POST"); XCTAssertNil(request.value(forHTTPHeaderField:"Authorization"))
        XCTAssertEqual(request.value(forHTTPHeaderField:"Cache-Control"),"no-store"); XCTAssertEqual(request.timeoutInterval,5)
        let sent=try JSONSerialization.jsonObject(with:request.httpBody!) as! [String:String]; XCTAssertEqual(sent,preparation)
    }
    func testExpiredApplicationSessionRequiresHostLoginWithoutFallback() async throws {
        var count=0
        let host=HostBackend(url:url,transport:{req in count += 1;return (Data(),HTTPURLResponse(url:req.url!,statusCode:401,httpVersion:nil,headerFields:nil)!)})
        do { _ = try await host.requestTicket(preparation); XCTFail("Expected expired host session") }
        catch { XCTAssertEqual(error as? HostBackendError,.hostLoginRequired) }
        XCTAssertEqual(count,1)
    }
    func testRejectsMalformedTicketsAndWrongAttempt() async throws {
        let valid=ticket()
        for overrides: [String:Any] in [["attempt_id":"other"],["login_ticket":""],["expires_at":2026],["expires_at":"invalid"]] {
            let body=valid.merging(overrides,uniquingKeysWith:{$1})
            let host=HostBackend(url:url,transport:{req in (try JSONSerialization.data(withJSONObject:body),HTTPURLResponse(url:req.url!,statusCode:200,httpVersion:nil,headerFields:nil)!)})
            do { _ = try await host.requestTicket(preparation); XCTFail("Malformed bootstrap must be rejected") }
            catch { XCTAssertEqual(error as? HostBackendError,.invalidResponse) }
        }
    }
    func testRejectsUnsafeURLBeforeSending() async throws {
        for address in ["http://app.example.com/bootstrap","https://user:pass@app.example.com/bootstrap","https://app.example.com/bootstrap?token=x","https://app.example.com/bootstrap#fragment"] {
            let host=HostBackend(url:URL(string:address)!,transport:{_ in XCTFail("Must not send"); throw URLError(.badURL)})
            do { _ = try await host.requestTicket(preparation); XCTFail("Expected invalid URL") }
            catch { XCTAssertEqual(error as? HostBackendError,.httpsRequired) }
        }
    }
    func testSanitizesTransportFailuresAndRejectsRedirectResponses() async throws {
        let offline=HostBackend(url:url,transport:{_ in throw NSError(domain:"sensitive-provider-detail",code:1)})
        do { _ = try await offline.requestTicket(preparation); XCTFail("Expected failure") }
        catch { XCTAssertEqual(error as? HostBackendError,.requestFailed) }
        for status in [302,503] {
            let host=HostBackend(url:url,transport:{req in (Data(),HTTPURLResponse(url:req.url!,statusCode:status,httpVersion:nil,headerFields:nil)!)})
            do { _ = try await host.requestTicket(preparation); XCTFail("Expected HTTP failure") }
            catch { XCTAssertEqual(error as? HostBackendError,.requestFailed) }
        }
        let redirected=HostBackend(url:url,transport:{_ in (try JSONSerialization.data(withJSONObject:self.ticket()),HTTPURLResponse(url:URL(string:"https://other.invalid")!,statusCode:200,httpVersion:nil,headerFields:nil)!)})
        do { _ = try await redirected.requestTicket(preparation); XCTFail("Must not accept a redirected response") }
        catch { XCTAssertEqual(error as? HostBackendError,.requestFailed) }
    }
    func testRejectsOversizeResponseAndIncompletePreparation() async throws {
        let host=HostBackend(url:url,transport:{req in (Data(repeating:32,count:16385),HTTPURLResponse(url:req.url!,statusCode:200,httpVersion:nil,headerFields:nil)!)})
        do { _ = try await host.requestTicket(preparation); XCTFail("Expected size limit") }
        catch { XCTAssertEqual(error as? HostBackendError,.invalidResponse) }
        do { _ = try await host.requestTicket([:]); XCTFail("Expected incomplete preparation") }
        catch { XCTAssertEqual(error as? HostBackendError,.invalidPreparation) }
    }
}
