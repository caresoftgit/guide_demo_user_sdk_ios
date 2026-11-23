# Phiên doanh nghiệp và ticket PKCE trên iOS native

Áp dụng SDK **0.5.0** và gateway `auth_protocol=2`. Khách hàng đăng nhập ứng dụng doanh nghiệp theo cơ chế đang có. Backend doanh nghiệp đã tra cứu/tạo khách hàng qua Customer REST và ánh xạ principal đã xác thực sang `user_id` Caresoft. App không cho người dùng nhập ID này.

## Cấu hình và trách nhiệm

| Nơi sử dụng | Thông tin cần có |
|---|---|
| App iOS | HTTPS gateway, Account ID, Caresoft App ID, Bundle ID, môi trường push và đầu số được cấp |
| HTTP client ứng dụng | Endpoint bootstrap của doanh nghiệp và phiên ứng dụng hiện có |
| Backend doanh nghiệp | Credential tích hợp có scope issue/revoke/read, Account/App và ánh xạ khách hàng |
| Tra cứu khách hàng | Customer REST credential riêng, chỉ ở backend nếu cần |
| Apple/Caresoft | Bundle ID, Team/Key ID, APNs key phía server và môi trường khớp provisioning |

Account/App/Bundle ID/đầu số là cấu hình công khai, không phải secret. Credential tích hợp, Customer REST token và APNs private key chỉ ở server. App không nhận account API token. Caresoft App ID khác Apple Bundle ID. Không đưa token vào URL, log, analytics hoặc báo cáo crash.

## Luồng hoàn chỉnh

```mermaid
sequenceDiagram
    participant User as Khach hang
    participant App as App doanh nghiep
    participant Host as Backend doanh nghiep
    participant SDK as iOS Voice SDK
    participant Gateway as Caresoft Gateway
    User->>App: Dang nhap ung dung
    App->>Host: Xac thuc theo co che san co
    Host-->>App: Phien ung dung hop le
    App->>SDK: prepareLogin()
    SDK-->>App: Preparation cong khai
    App->>Host: Bootstrap qua HTTP client da xac thuc
    Host->>Host: Lay user_id tu principal server
    Host->>Gateway: Issue ticket bang credential server
    Gateway-->>Host: Ticket mot lan
    Host-->>App: Ticket va attempt_id
    App->>SDK: loginWithTicket()
    SDK->>Gateway: Ticket va verifier PKCE
    Gateway-->>SDK: Phien Voice protocol 2
    SDK->>Gateway: Readiness va dong bo cuoc goi
```

### 1. Phiên đăng nhập ứng dụng

Giữ nguyên đăng nhập/SSO, refresh và logout doanh nghiệp hiện có. SDK không xác thực username/password doanh nghiệp, không cấp phiên doanh nghiệp và không quy định API login riêng.

Native thường dùng bearer của ứng dụng qua HTTP client đã xác thực. Đây là **bearer doanh nghiệp**, khác access token Voice và credential Caresoft. Nếu dùng cookie, dùng cookie/session client hiện có; backend phải bảo vệ CSRF theo cơ chế cookie của ứng dụng, nhất là endpoint dùng chung với Web. Native không có CORS bảo vệ như browser; server luôn phải xác thực phiên và kiểm tra quyền.

### 2. App chuẩn bị và xin ticket

Các ví dụ Swift thao tác SDK chạy trên `@MainActor`.

```swift
let voice = CustomerVoice.shared
let p = try voice.prepareLogin()
let preparation = [
    "attempt_id": p.attemptID, "installation_id": p.installationID,
    "os": p.platform, "application_id": p.applicationID,
    "push_environment": p.pushEnvironment,
    "code_challenge": p.codeChallenge, "code_challenge_method": p.codeChallengeMethod
]
// HostBackend là helper source trong Demo/, không phải API của SDK.
// authenticatedTransport là HTTP client của ứng dụng, tự gắn phiên doanh nghiệp.
let host = HostBackend(url: applicationBootstrapURL, transport: authenticatedTransport)
let ticket = try await host.requestTicket(preparation)
_ = try await voice.loginWithTicket(attemptID: p.attemptID, ticket: ticket)
```

`applicationBootstrapURL` và `authenticatedTransport` do ứng dụng cung cấp. Transport có kiểu `(URLRequest) async throws -> (Data, HTTPURLResponse)`; giữ nguyên URL, method/body, timeout, không follow redirect, không log request/response xác thực. Với bearer, gắn Authorization của **phiên ứng dụng** trong client này; không thêm API token Caresoft vào config.

Demo mặc định dùng `URLSession.shared` và cookie phiên ứng dụng đã có, từ chối redirect bằng task delegate. Nó không tạo cookie hoặc tự đăng nhập. Nếu ứng dụng dùng bearer/client khác, inject transport vào `HostBackend` hoặc inject closure `requestTicket` vào `HomeView`. Không cài backend đăng nhập mẫu đi kèm.

Ví dụ endpoint **do doanh nghiệp triển khai**:

```http
POST https://app.example.com/api/voice/bootstrap
Authorization: Bearer APPLICATION_SESSION_BEARER
Content-Type: application/json
Cache-Control: no-store
```

```json
{
  "attempt_id": "ATTEMPT_UUID",
  "installation_id": "INSTALLATION_UUID",
  "os": "ios",
  "application_id": "com.example.CustomerApp",
  "push_environment": "production",
  "code_challenge": "BASE64URL_SHA256_VERIFIER",
  "code_challenge_method": "S256"
}
```

Các giá trị viết hoa là placeholder. Bundle ID phải khớp app cuối cùng đã ký; `VoiceConfig.applicationID` mặc định lấy từ bundle. Môi trường APNs phải khớp bản phân phối, không tự chuyển sandbox/production để che lỗi signing.

Backend xác thực phiên, giới hạn tần suất, lấy `user_id` từ principal server. Account/App, Bundle ID, quyền truy cập khách hàng và host session phải được kiểm tra bằng dữ liệu server; không chấp nhận client override user/account/host session. Chưa ánh xạ khách hàng hoặc phiên hết hạn thì không cấp ticket.

### 3. Backend doanh nghiệp gọi gateway

```http
POST https://GATEWAY_HOST/ACCOUNT_ID/api/v1/voice/session-tickets
Authorization: Bearer SERVER_INTEGRATION_CREDENTIAL
Content-Type: application/json
```

```json
{
  "app_id": "CARESOFT_APP_ID",
  "user_id": "CARESOFT_USER_ID_FROM_SERVER",
  "host_session_ref": "SERVER_HOST_SESSION_UUID",
  "host_session_expires_at": "HOST_SESSION_EXPIRY_ISO8601",
  "attempt_id": "ATTEMPT_UUID",
  "installation_id": "INSTALLATION_UUID",
  "os": "ios",
  "application_id": "com.example.CustomerApp",
  "push_environment": "production",
  "code_challenge": "BASE64URL_SHA256_VERIFIER",
  "code_challenge_method": "S256"
}
```

ID dạng số truyền bằng chuỗi. `host_session_ref` do server quản lý, gắn đúng phiên doanh nghiệp. Gateway kiểm tra credential theo Account/App/scope, quyền truy cập khách hàng, trạng thái App, cấu hình iOS và chính sách phiên. Không forward browser Origin vào endpoint server-to-server này.

Response gateway bọc trong `data`; backend lấy các trường cần thiết và trả app response phẳng với `Cache-Control: no-store`:

```json
{
  "attempt_id": "ATTEMPT_UUID",
  "login_ticket": "OPAQUE_ONE_USE_TICKET",
  "expires_at": "TICKET_EXPIRY_ISO8601"
}
```

Không trả credential tích hợp, Customer REST token hay Voice access/refresh token từ endpoint bootstrap. Helper kiểm tra attempt, định dạng ticket/expiry và kích thước response, không hiển thị nội dung lỗi nhạy cảm. HTTP 401 yêu cầu ứng dụng đăng nhập lại bằng luồng hiện có.

### 4. Exchange và sẵn sàng gọi

SDK giữ verifier trong memory, không gửi cho backend doanh nghiệp. `loginWithTicket` tự gửi ticket, attempt, installation và verifier tới `POST /ACCOUNT_ID/api/v1/voice/sessions/exchange`. Chỉ attempt thuộc thế hệ hiện hành mới commit. Preparation mới không ngắt phiên/cuộc gọi đang có; exchange thành công mới thay thế phiên.

Exchange có kết quả không rõ thì tạo preparation/ticket mới; không retry ticket đã dùng hoặc fallback legacy login. SDK tự giữ access/refresh và đồng bộ push/readiness. Theo dõi `sessionState` và `readiness`; có token local chưa đồng nghĩa `canCall`/`canReceive`. Xin microphone từ tương tác phù hợp và gọi `resume()`/`checkReadiness()`.

## Hiệu lực, refresh và Keychain

| Dữ liệu | Quy tắc |
|---|---|
| Preparation | Tối đa 120 giây; verifier chỉ ở memory |
| Ticket | Một lần, mặc định 60 giây, không vượt hạn phiên; dùng expiry server trả |
| Access Voice | Thông thường 15 phút, SDK tự refresh |
| Refresh/phiên | Hạn tuyệt đối theo chính sách server và phiên doanh nghiệp; rotation không kéo dài hạn này |
| Refresh mất response | Single-flight, UUID được lưu trước HTTP; retry cùng UUID/payload trong 30 giây kể cả restart |
| Phiên doanh nghiệp | Ứng dụng quản lý; SDK không lưu hoặc refresh phiên này |

Access/refresh và pending UUID lưu trong một record Keychain atomic, `AfterFirstUnlockThisDeviceOnly`. Namespace/locator ngăn khôi phục phiên đã logout hoặc record giữ lại sau reinstall. Verifier/ticket không persist. Không lưu Voice credentials vào UserDefaults, file cấu hình hoặc log; Keychain không phải chứng thực thiết bị.

Quá cửa sổ refresh cần bootstrap mới. Mất mạng có thể giữ readiness UNKNOWN; không coi mọi lỗi mạng là logout. Hết hạn tự nhiên chặn cuộc gọi mới; cuộc gọi ACTIVE có thể hoàn tất bằng capability giới hạn snapshot/hangup/media-token tới deadline server. Thu hồi rõ ràng/logout dừng media. Capability không thay bearer chung; restart cần phiên hợp lệ để đồng bộ.

## Ngắt Voice và đăng xuất ứng dụng

**Ngắt Voice:** `try await voice.logout()` dừng media, dọn phiên/preparation local trước rồi cố revoke phiên Voice hiện tại. Tài khoản ứng dụng vẫn đăng nhập và có thể xin ticket mới. Đây là hành vi nút **Ngắt Voice** trong demo.

**Đăng xuất ứng dụng:** thực hiện cả SDK logout và logout doanh nghiệp hiện có, kể cả một bên lỗi. Tuần tự hóa chuyển tài khoản/đăng xuất với kết nối Voice để request và cleanup luôn gắn đúng phiên cũ. Ví dụ trong luồng ứng dụng:

```swift
let voiceLogout = Task { try await voice.logout() }
let applicationLogout = Task { try await existingAppSession.logout() }
let results = (await voiceLogout.result, await applicationLogout.result)
// Kiểm tra cả hai Result, hiển thị lỗi hoặc trạng thái thu hồi đang chờ.
```

`existingAppSession` là thành phần đã có của doanh nghiệp. Backend vô hiệu hóa phiên host và ghi outbox HOST-revoke trong cùng transaction bền vững, từ đó chặn bootstrap mới. Worker dùng credential server:

```http
POST https://GATEWAY_HOST/ACCOUNT_ID/api/v1/voice/service/session-revocations
Authorization: Bearer SERVER_INTEGRATION_CREDENTIAL
X-Request-Id: STABLE_REVOCATION_UUID
Content-Type: application/json
```

```json
{"scope":"HOST","host_session_ref":"SERVER_HOST_SESSION_UUID"}
```

Retry cùng UUID và payload. Response trong `data` có `revocation_id`, `authority_revoked_at`, `cleanup_status`. `pending` chưa phải hoàn tất cleanup; theo dõi `GET /ACCOUNT_ID/api/v1/voice/service/session-revocations/REVOCATION_ID` bằng credential server và tiếp tục xử lý tới khi xác nhận. Không đặt outbox trong memory app.

Logout offline hoặc `LOGOUT_REVOKE_UNCONFIRMED` nghĩa local đã dọn nhưng chưa bảo đảm server thu hồi ngay. Không khôi phục token local đã xóa. Ngắt Voice không vô hiệu hóa phiên doanh nghiệp.

## Mã hóa và giới hạn nền tảng

API dùng HTTPS/TLS; media dùng WSS và WebRTC DTLS-SRTP. Không tắt kiểm tra chứng thư hoặc ATS. PKCE chứng minh sở hữu verifier, không mã hóa JSON, không thay xác thực phiên và không chứng thực thiết bị.

Khởi tạo CallKit/PushKit sớm khi app khởi động, không chờ HTTP trong VoIP callback; báo CallKit và completion trước reconciliation. Simulator kiểm tra gọi ra, không xác nhận nhận cuộc gọi APNs khi khóa máy. Nhận cuộc gọi, Bluetooth, chuyển mạng và audio vật lý phải nghiệm thu trên iPhone với provisioning/APNs phù hợp.
