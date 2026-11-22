import XCTest
@testable import EnterpriseDemoAuth
@MainActor final class EnterpriseSessionTests: XCTestCase {
 let attempt="00000000-0000-4000-8000-000000000001"
 func testAuthenticatedBootstrapHasChallengeAndNoCustomerId() async throws {
  var requests=[URLRequest]();var exchanged=false
  let p=["attempt_id":attempt,"installation_id":"00000000-0000-4000-8000-000000000002","os":"ios","application_id":"com.example.app","push_environment":"production","code_challenge":String(repeating:"c",count:43),"code_challenge_method":"S256"]
  let host=EnterpriseSession(baseURL:URL(string:"https://enterprise.invalid")!,prepare:{p},exchange:{a,t in XCTAssertEqual(a,self.attempt);XCTAssertEqual(t,String(repeating:"t",count:43));exchanged=true},nativeLogout:{},transport:{request in
   requests.append(request);let body:[String:String]=request.url!.path.hasSuffix("login") ? ["enterprise_access_token":String(repeating:"h",count:43)] : ["attempt_id":self.attempt,"login_ticket":String(repeating:"t",count:43)]
   return (try JSONSerialization.data(withJSONObject:body),HTTPURLResponse(url:request.url!,statusCode:200,httpVersion:nil,headerFields:nil)!)
  })
  try await host.login(username:"customer",password:"password");XCTAssertTrue(exchanged);let bootstrap=requests[1];XCTAssertEqual(bootstrap.value(forHTTPHeaderField:"Authorization"),"Bearer "+String(repeating:"h",count:43));let sent=try JSONSerialization.jsonObject(with:bootstrap.httpBody!) as! [String:String];XCTAssertEqual(sent,p);XCTAssertNil(sent["user_id"])
 }
 func testHostLogoutRunsDespiteNativeFailure() async throws {
  var revoked=false
  let host=EnterpriseSession(baseURL:URL(string:"https://enterprise.invalid")!,prepare:{["attempt_id":self.attempt]},exchange:{_,_ in},nativeLogout:{throw URLError(.notConnectedToInternet)},transport:{req in
   let path=req.url!.path;let data:[String:String]
   if path.hasSuffix("login") {data=["enterprise_access_token":String(repeating:"h",count:43)]}else if path.hasSuffix("bootstrap"){data=["attempt_id":self.attempt,"login_ticket":String(repeating:"t",count:43)]}else{data=[:];revoked=true}
   return (try JSONSerialization.data(withJSONObject:data),HTTPURLResponse(url:req.url!,statusCode:200,httpVersion:nil,headerFields:nil)!)
  })
  try await host.login(username:"customer",password:"password");do {try await host.logout();XCTFail("Expected native failure")}catch{};XCTAssertTrue(revoked)
 }
 func testOpaqueJWTAndDelayedLogoutNeverRevokesNextUser() async throws {
  var continuation: CheckedContinuation<Void,Never>?
  var count=0;var revoked=[String]()
  let host=EnterpriseSession(baseURL:URL(string:"https://host.invalid")!,prepare:{["attempt_id":self.attempt]},exchange:{_,_ in},nativeLogout:{await withCheckedContinuation{continuation=$0}},transport:{req in
   let body:[String:String]
   if req.url!.path.hasSuffix("login") {count += 1;body=["enterprise_access_token":"eyJhbGciOiJSUzI1NiJ9.user\(count).signature"]}
   else if req.url!.path.hasSuffix("bootstrap") {body=["attempt_id":self.attempt,"login_ticket":String(repeating:"t",count:43)]}
   else {revoked.append(req.value(forHTTPHeaderField:"Authorization")!);body=[:]}
   return (try JSONSerialization.data(withJSONObject:body),HTTPURLResponse(url:req.url!,statusCode:200,httpVersion:nil,headerFields:nil)!)
  })
  try await host.login(username:"A",password:"password")
  let old=Task {try await host.logout()};while continuation == nil {await Task.yield()}
  try await host.login(username:"B",password:"password");continuation!.resume();try await old.value
  XCTAssertEqual(revoked,["Bearer eyJhbGciOiJSUzI1NiJ9.user1.signature","Bearer eyJhbGciOiJSUzI1NiJ9.user1.signature"])
  try await host.retryLogout();XCTAssertEqual(revoked.last,"Bearer eyJhbGciOiJSUzI1NiJ9.user2.signature")
 }

 func testLogoutDuringPriorHostCleanupCancelsReplacementLogin() async throws {
  var continuation: CheckedContinuation<Void,Never>?;var authentications=0;var cleanupCalls=0
  let host=EnterpriseSession(baseURL:URL(string:"https://host.invalid")!,prepare:{["attempt_id":self.attempt]},exchange:{_,_ in},nativeLogout:{},transport:{req in
   let body:[String:String]
   if req.url!.path.hasSuffix("login") {authentications += 1;body=["enterprise_access_token":"host.jwt.signature"]}
   else if req.url!.path.hasSuffix("bootstrap") {body=["attempt_id":self.attempt,"login_ticket":String(repeating:"t",count:43)]}
   else {cleanupCalls += 1;if cleanupCalls==1 {await withCheckedContinuation {continuation=$0}};body=[:]}
   return (try JSONSerialization.data(withJSONObject:body),HTTPURLResponse(url:req.url!,statusCode:200,httpVersion:nil,headerFields:nil)!)
  })
  try await host.login(username:"A",password:"password")
  let replacement=Task {try await host.login(username:"B",password:"password")};while continuation==nil {await Task.yield()}
  try await host.logout();continuation!.resume()
  do {try await replacement.value;XCTFail("Replacement must be superseded")}catch{}
  XCTAssertEqual(authentications,1)
 }

}
