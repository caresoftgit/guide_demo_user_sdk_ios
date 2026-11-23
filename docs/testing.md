# Demo và kiểm thử

Luồng xác thực hiện tại: [phiên doanh nghiệp → ticket PKCE → SDK](host-bootstrap.md).

## Chạy demo

1. Dùng SDK binary và dependency đi kèm đúng bản phát hành.
2. Sao chép `Demo/Config/Config.example.xcconfig` thành `Demo/Config/Local.xcconfig`.
3. Điền gateway, account, App ID, đầu số được cấp, Bundle ID, Apple Team và VOICE_BOOTSTRAP_URL của ứng dụng doanh nghiệp. File local
   bị Git bỏ qua; không đưa account token hoặc APNs private key vào đây.
4. Chạy `python3 scripts/generate-demo-project.py`, `cd Demo && pod install`, mở `CustomerVoiceDemo.xcworkspace`, chọn scheme CustomerVoiceDemo.
5. Dùng simulator để gọi ra thật bằng audio máy tính, hoặc cấu hình TestFlight production để nhận cuộc gọi trên iPhone.
6. Dùng phiên đăng nhập doanh nghiệp có sẵn; nối HTTP client đã xác thực vào HostBackend. Nhấn **Kết nối Voice**, không có form username/password hoặc ID khách hàng.
7. Kiểm tra readiness. Nhấn **Gọi CSKH**, không có dialer chủ động hoặc agent status.
8. Trong cuộc gọi kiểm tra micro, loa thoại/ngoài/Bluetooth, DTMF và kết thúc.
9. Khi kết thúc, app phải trở về Home. Ngắt Voice rồi kết nối lại bằng phiên ứng dụng còn hiệu lực; test logout ứng dụng và đổi tài khoản riêng.

Không dùng simulator để kết luận APNs/PushKit/CallKit màn hình khóa đã hoạt động.
Simulator có adapter audio riêng: `canCall` có thể true sau đăng nhập và cấp micro; `canReceive=false`. Không giả lập CallKit hoặc APNs.

## Kiểm thử tự động

Trong repo demo, `swift test` chạy kiểm thử HostBackend: whitelist bảy trường, phiên host hết hạn, response sai, HTTPS/redirect, lỗi transport và giới hạn kích thước. Không gọi backend/tổng đài thật.


SDK có regression core/presentation/media theo bản source; chạy `swift test` trong repository
SDK. UI harness ở repository demo dùng gateway/media giả để kiểm tra đăng nhập →
gọi → kết thúc về Home → ngắt Voice → kết nối lại; phiên host hết hạn phải yêu cầu đăng nhập ứng dụng và không mở form mẫu, không dùng dữ liệu khách hàng.
Kiểm thử tự động không thay thế kiểm thử âm thanh, APNs và mạng thực tế trên iPhone.

## Ma trận nghiệm thu trên iPhone thật

| Nhóm | Thực hiện | Đạt khi |
|---|---|---|
| Phiên | Login, force quit/reopen, logout/login, mất mạng/refresh | Không lộ token, không phục hồi phiên đã logout |
| Outbound | Gọi đầu số được cấp | Đúng route, hai chiều nghe rõ, UI theo server ACTIVE |
| Incoming foreground | Gọi vào khách hàng đã đăng nhập | Đổ chuông, answer/reject đúng, không lặp cuộc gọi |
| Khóa màn hình | Khóa iPhone, gọi vào, trả lời | CallKit hiện, mic/audio hoạt động sau activation |
| Background/cold start | App background hoặc hệ thống đã dừng app, gọi vào | CallKit báo ngay, reconcile không hồi sinh call cũ |
| Người dùng force quit | Thử riêng và ghi nhận giới hạn iOS | Không cam kết iOS luôn đánh thức app sau user force quit |
| Caller hủy | Hủy trước khi nhận, cả khi app suspend | Dừng chuông qua snapshot/deadline; APNs thường best effort |
| Nhiều thiết bị | Cùng user Android+iOS nhận, một máy answer | Chỉ winner publish, máy còn lại dừng chuông |
| Audio | Micro/speaker/receiver/Bluetooth, ngắt kết nối route | Hiển thị route thực tế, không publish sau hangup |
| Mute | Tắt/bật mic nhiều lần từ app và CallKit | Agent nghe lại ngay khi bật, UI phản ánh trạng thái |
| Uplink | Nói liên tục ngay từ đầu cuộc gọi | Agent nghe rõ, không giật/mất tiếng; gateway cần bật SIP jitter buffer |
| Chuyển mạng | Wi-Fi → 5G → Wi-Fi trong cùng cuộc gọi | Hiện Đang kết nối lại, phục hồi âm thanh hai chiều, không gọi lại |
| Mất mạng | Ngắt mọi mạng trên 30 giây | Đóng media, CallKit và UI; kết nối lại không hồi sinh cuộc gọi |
| DTMF | Nhấn các phím trong cuộc gọi vào IVR | IVR nhận đúng SIP DTMF |
| Terminal | Local/remote hangup, media fail, session revoke | Dừng room và đóng call UI về màn hình trước |
| Push rotation | Đổi token VoIP/thường, login lại | Token đúng kind/config, không xóa token mới bởi response cũ |

Apple có thể trì hoãn/bỏ background notification; không coi APNs thường là
điều kiện duy nhất để dừng chuông. Server snapshot và thời hạn cuộc gọi là nguồn
sự thật; background cancellation là tín hiệu hỗ trợ.

## Lệnh kiểm chứng

```sh
# Trong repository demo: chỉ kiểm tra compiler, không ký hoặc gọi thật.
python3 scripts/generate-demo-project.py
(cd Demo && pod install)
xcodebuild -workspace Demo/CustomerVoiceDemo.xcworkspace -scheme CustomerVoiceDemo \
  -destination 'generic/platform=iOS Simulator' ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGNING_ALLOWED=NO build

# UI harness cần source checkout SDK 0.5.0 (dùng @testable), không dùng binary shipping.
CUSTOMER_VOICE_LOCAL_SDK=/absolute/path/user_voice_sdk_ios python3 scripts/generate-ui-test-project.py
# Chọn UDID Simulator đang boot từ: xcrun simctl list devices booted
xcodebuild -project Tests/UITestHarness.xcodeproj -scheme CustomerFlowUITests \
  -destination 'platform=iOS Simulator,id=<SIMULATOR_UDID>' ARCHS=arm64 ONLY_ACTIVE_ARCH=YES test
```

UI harness chỉ dùng trong cấu hình Debug để cho phép `@testable import`.
Không ghi token, private key, SDP hoặc nội dung push vào log công khai.

## Bảo mật bàn giao

- Source/config/binary chỉ có placeholder hoặc cấu hình công khai; không nhúng credential hay tài khoản test.
- Chặn user_id/account/host_session_ref do app tự chọn; ticket hết hạn/dùng lại/sai PKCE phải bị server từ chối.
- HTTP 401 yêu cầu đăng nhập ứng dụng, không fallback legacy hoặc backend login mẫu.
- Logout ứng dụng chặn bootstrap và ghi HOST-revoke outbox, retry/poll tới khi server xác nhận.
- UI harness/mobile simulator không xác nhận chất lượng audio, APNs, Bluetooth hoặc chuyển mạng trên thiết bị thật.
