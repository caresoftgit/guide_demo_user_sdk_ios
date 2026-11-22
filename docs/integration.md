# Tích hợp Customer Voice trên iOS

Luồng xác thực hiện tại: [phiên doanh nghiệp → ticket PKCE → SDK](host-bootstrap.md).

## 1. Chuẩn bị thông tin

| Thông tin | Nguồn | Cách dùng |
|---|---|---|
| Gateway HTTPS URL | Caresoft cung cấp | `VoiceConfig.backendURL`, không thêm `/api/v1/voice` |
| Account ID | Caresoft cung cấp | `VoiceConfig.accountID` |
| Caresoft App ID | Tạo ở bước 2 | `VoiceConfig.appID` |
| Apple Bundle ID, Team ID | Apple Developer | Phải khớp app ký và cấu hình push |
| Phiên doanh nghiệp | Backend doanh nghiệp xác thực, tự lấy user_id Caresoft; không nhập từ app |
| Credential tích hợp | Chỉ lưu backend doanh nghiệp để issue ticket; không cấp cho SDK/app |
| Đầu số hỗ trợ | Caresoft cấp sau khi định tuyến | Ứng dụng tự giữ và truyền nguyên bản vào `call` |

Không gửi SIP URI, IP tổng đài hoặc prefix định tuyến từ ứng dụng. Gateway xử lý
SIP; mọi nền tảng dùng chung gateway.

## 2. Tạo App trên Caresoft và cấu hình APNs

1. Đăng nhập trang quản trị Caresoft đúng môi trường.
2. Vào **Admin Settings → Cơ bản → Voice SDK**. Nếu không có mục này, nhờ quản trị
   viên cấp quyền Voice SDK.
3. Tạo App, nhập tên và bật **Hoạt động**. Lưu và sao chép **App ID** do Caresoft sinh.
   App ID Caresoft khác Bundle ID Apple.
4. Trong **Cấu hình push**, thêm **iOS/APNs VoIP**. Có thể dùng chung Caresoft App ID
   với Android, nhưng phải có cấu hình push iOS riêng.
5. Điền Bundle ID đúng bản app cuối cùng, Apple Team ID, Key ID và môi trường APNs
   phù hợp với provisioning profile. Bản demo này dùng **production**.
6. Trong Apple Developer → Certificates, Identifiers & Profiles → Keys, tạo/chọn
   APNs authentication key có quyền gửi cho app. Tải `.p8`, nhập **nội dung PEM đầy
   đủ** của file vào phần credential server Caresoft. Không chuyển key vào app.
7. Lưu và bật cấu hình push. Nếu giao diện quản trị chưa có trường tương ứng,
   quản trị hệ thống bổ sung cấu hình phía server; không tạo API token hoặc APNs
   credential trong `app.config` của ứng dụng.

APNs VoIP dùng topic `<bundle-id>.voip`; thông báo hủy/cập nhật dùng token APNs
thường, topic `<bundle-id>`. Caresoft chọn cấu hình theo app/platform/environment.
Ứng dụng không truyền `push_config_id`.

## 3. Thêm SDK

Bộ bàn giao này có binary **0.5.0** và checksum trong `SDK/`. Kiểm tra `SDK/SHA256.json`, chạy `python3 scripts/generate-demo-project.py`, sau đó `cd Demo && pod install`; mở `CustomerVoiceDemo.xcworkspace`. Podfile dùng podspec local và đã kèm các framework cần thiết. Không thêm LiveKit lần thứ hai. Không tham chiếu tag remote chưa được publish.

Bật capabilities **Push Notifications** và **Background Modes**:
**Audio, AirPlay, and Picture in Picture**, **Voice over IP**, **Remote notifications**.
Thêm `NSMicrophoneUsageDescription` giải thích quyền micro.
Khai báo cả `NSCameraUsageDescription`: thư viện LiveKit/WebRTC đi kèm có tham
chiếu API camera nên App Store Connect có thể yêu cầu khóa này dù app chỉ gọi
thoại (lỗi 90683). Với demo chỉ gọi thoại, mô tả rõ thư viện có API camera nhưng
bản demo không truy cập camera. Khai báo này không tự xin quyền camera; không
thêm lời nhắc cấp quyền nếu app không sử dụng camera.

## 4. Khởi tạo trước khi có giao diện

Thực hiện trong `application(_:didFinishLaunchingWithOptions:)`, kể cả cold start
bởi VoIP push. Dùng một instance `CustomerVoice.shared` cho toàn bộ app.

```swift
import CustomerVoice

try CustomerVoice.shared.initialize(config: VoiceConfig(
    backendURL: URL(string: "https://voice.example.com")!,
    accountID: "<ACCOUNT_ID>",
    appID: "<CARESOFT_APP_ID>",
    pushEnvironment: .production
))
application.registerForRemoteNotifications()
```

SDK tự quản lý PushKit khi `managesPushKit=true` (mặc định). Không tạo PushKit
registry thứ hai. Nếu host đã có registry, đặt `managesPushKit=false`, chuyển token
qua `updatePushToken`, chuyển payload/completion qua `handleVoIPPush`, và gọi
`unregisterPushToken` khi token VoIP mất hiệu lực. Khởi tạo CallKit vẫn phải sớm.
Không chờ HTTP trước khi chuyển VoIP push cho SDK.

Chuyển APNs thường cho SDK:

```swift
func application(_ application: UIApplication,
                 didRegisterForRemoteNotificationsWithDeviceToken token: Data) {
    CustomerVoice.shared.didRegisterForRemoteNotifications(deviceToken: token)
}
func application(_ application: UIApplication,
                 didReceiveRemoteNotification payload: [AnyHashable: Any],
                 fetchCompletionHandler done: @escaping (UIBackgroundFetchResult) -> Void) {
    Task {
        let handled = await CustomerVoice.shared.handleRemoteNotification(payload)
        done(handled ? .newData : .noData)
    }
}
```

Host có thể xin quyền hiển thị notification qua UNUserNotificationCenter. Quyền
notification thường không quyết định khả năng nhận VoIP qua CallKit. Token APNs
thường giúp dừng chuông khi caller hủy hoặc thiết bị khác đã nhận; iOS không bảo
đảm luôn đánh thức app cho background notification.

## 5. Đăng nhập từ luồng của ứng dụng

Dùng [hợp đồng bootstrap](host-bootstrap.md) và helper `Demo/EnterpriseSession.swift`. App gọi `try CustomerVoice.shared.prepareLogin()`, gửi bảy trường preparation tới backend doanh nghiệp qua phiên host, kiểm tra attempt_id rồi gọi `try await CustomerVoice.shared.loginWithTicket(attemptID: preparation.attemptID, ticket: ticket)`.

Form username/password thuộc host demo. Credential tích hợp và user_id server-side không thành input app. SDK giữ access/refresh trong Keychain và tự restore; theo dõi sessionState/readiness. Logout gọi cả SDK và backend doanh nghiệp kể cả một bên lỗi; không fallback về legacy login.

## 6. Quyền micro và readiness

Xin quyền micro trong app khi người dùng bắt đầu dùng chức năng gọi:

```swift
AVAudioSession.sharedInstance().requestRecordPermission { _ in
    Task { @MainActor in CustomerVoice.shared.resume() }
}
let state = try await CustomerVoice.shared.checkReadiness()
// state.isLoggedIn, state.canCall, state.canReceive, state.reasons
```

Kiểm tra mạng không thành công không đồng nghĩa đã logout. Khi phiên chưa kiểm
chứng được, readiness là `UNKNOWN` và không nhận định sẵn sàng. Lần kiểm chứng
có hiệu lực tối đa 30 giây. Simulator hỗ trợ gọi ra thật qua audio máy tính, nhưng `canReceive=false`; nhận cuộc gọi cần iPhone với APNs production qua TestFlight.
Khi app về foreground, gọi `resume()` để đồng bộ phiên, cuộc gọi và push token.

## 7. Gọi CSKH bằng đầu số ứng dụng cấu hình

```swift
let call = try await CustomerVoice.shared.call(businessNumber: assignedHotline)
```

Đầu số được cấp trực tiếp sau khi định tuyến. Không có `getDestinations()`.
Nếu tạo cuộc gọi bị timeout, SDK không tự gửi lại request tạo cuộc gọi: đồng bộ
snapshot trước khi cho phép gọi lại để tránh hai cuộc gọi.

## 8. Dùng màn hình nghe/gọi có sẵn

SwiftUI: quan sát `voice.$calls`, chọn cuộc gọi có `voice.isCallPresentable(id)`
rồi present bằng `fullScreenCover`. Khi kết thúc, callback bỏ presentation:

```swift
CustomerVoiceCallView(callID: callID) { presentedCall = nil }
```

Xem `Demo/HomeView.swift` cho đầy đủ tự hiển thị incoming/outgoing và trở về Home.
Dùng `interactiveDismissDisabled()` để không vuốt mất màn hình trong lúc gọi.

UIKit:

```swift
// Property của host; gọi install trong/ sau viewDidAppear và giữ presenter.
callPresenter = CustomerVoiceUI.install(on: self)
// Có thể gọi callPresenter.showCall(callID:) khi host xuất hiện lại.
```

Hoặc dùng `CustomerVoiceUI.controller(callID:voice:onEnded:)` nếu host tự điều phối
presentation. Không dùng đồng thời hai cơ chế present cho cùng cuộc gọi.
SDK UI có trả lời/từ chối, kết thúc, micro, chọn âm thanh thực tế và DTMF.
UI không tự đăng nhập, tạo cuộc gọi hoặc tự trả lời khi bind/present.
Màn hình khóa dùng **CallKit native của iOS**, giao diện trong app theo mẫu Android.

UI tự hiển thị **Đang kết nối lại…** khi chuyển mạng hoặc media bị gián đoạn.
Host tự xây UI cần quan sát `voice.$connectionStates` theo `callID`. SDK giữ nguyên
cuộc gọi khi khôi phục; host không gọi lại `call()` khi nhận trạng thái này.
Không khôi phục trong 30 giây liên tục thì cuộc gọi đóng và host nhận event lỗi
`NETWORK_RECOVERY_TIMEOUT`. Xem [API](https://github.com/caresoftgit/user_voice_sdk_ios/blob/0.5.0/docs/api.md) để xử lý state và lỗi.

## 9. Đăng xuất và đăng nhập lại

```swift
try await CustomerVoice.shared.logout()
```

Logout dừng media, đóng màn hình và xóa phiên local trước khi revoke server.
Nếu lỗi `LOGOUT_REVOKE_UNCONFIRMED`, local vẫn logout nhưng chưa xác nhận được
revoke phía server. Ứng dụng xử lý thông báo phù hợp, không phục hồi phiên cũ.
Quan sát `sessionState` và event `login_required` để mở luồng đăng nhập của host.

## 10. Objective-C

Import `CustomerVoice/CustomerVoice-Swift.h`, dùng `CVCustomerVoice.shared`.
Façade cung cấp completion cho initialize/login/readiness/call/answer/reject/
hangup/mute/route/DTMF/logout, delegate `CVVoiceDelegate` nhận state và event.
Gọi trên main thread. Ví dụ:

```objc
#import <CustomerVoice/CustomerVoice-Swift.h>
[[CVCustomerVoice shared] loginWithUserID:userID tenantAPIToken:accountToken
 completion:^(NSDictionary *session, NSError *error) {
     // Cập nhật UI host; không ghi token hoặc response xác thực vào log.
 }];
```
