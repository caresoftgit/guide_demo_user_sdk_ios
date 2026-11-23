# Demo và hướng dẫn Customer Voice iOS native

Bộ tích hợp **0.5.0** gồm XCFramework đã đóng gói, màn hình gọi mẫu SwiftUI và tài liệu cho ứng dụng doanh nghiệp. Yêu cầu iOS 15.1+, Swift 6.2+; source đã kiểm chứng trên Xcode 26.4 / Swift 6.3.

Khách hàng đăng nhập ứng dụng doanh nghiệp bằng cơ chế hiện có. Demo chỉ **Kết nối Voice / Ngắt Voice**, dùng ticket PKCE; không có form hay backend đăng nhập doanh nghiệp đi kèm.

1. [Luồng, payload và trách nhiệm backend](docs/host-bootstrap.md).
2. [Tích hợp SDK, CallKit và APNs](docs/integration.md).
3. [Chạy demo và kiểm thử](docs/testing.md), [simulator](docs/simulator-testing.md).
4. [Signing production](docs/production-signing.md).

## Bắt đầu

```sh
cp Demo/Config/Config.example.xcconfig Demo/Config/Local.xcconfig
python3 scripts/generate-demo-project.py
cd Demo
pod install
open CustomerVoiceDemo.xcworkspace
```

Điền gateway URL, Account ID, Caresoft App ID, đầu số, Bundle ID/Apple Team và `VOICE_BOOTSTRAP_URL` của **ứng dụng doanh nghiệp**. URL xcconfig viết `https:/$()/app.example.com/api/voice/bootstrap` để tránh `//` bị hiểu là comment. Các trường trong mẫu là placeholder cần thay.

Demo mặc định dùng cookie phiên có sẵn trong `URLSession.shared`. Với bearer hoặc client riêng, nối `Demo/HostBackend.swift` với HTTP client đã xác thực của ứng dụng hoặc inject `requestTicket` vào `HomeView`. SDK/demo không tạo phiên doanh nghiệp và không giữ bearer riêng. Nếu chưa nối ứng dụng/backend, chỉ chạy UI không thể đăng nhập/gọi thật.

Chọn scheme **CustomerVoiceDemo** và Simulator để gọi ra; iPhone nhận gọi cần signing/APNs phù hợp. Demo cấu hình production, không tự chuyển môi trường push. Bấm **Kết nối Voice**, cho phép microphone và đợi readiness trước khi gọi.

| Thành phần | Nội dung |
|---|---|
| `Demo/HomeView.swift` | Kết nối/ngắt Voice và UI gọi |
| `Demo/HostBackend.swift` | Adapter xin ticket qua phiên ứng dụng hiện có |
| `Demo/Config/Config.example.xcconfig` | Cấu hình công khai mẫu |
| `SDK/` | XCFramework, resources, licenses và checksum |
| `Tests/` | Bootstrap unit tests và UI/API/media giả lập |

Ngắt Voice không đăng xuất ứng dụng. Đăng xuất toàn bộ cần logout SDK và thu hồi HOST bền vững phía backend theo tài liệu. Không đưa API token, credential tích hợp, APNs key, mật khẩu hoặc tài khoản test vào source/config/binary. `Local.xcconfig` bị Git ignore nhưng các giá trị vẫn đi vào app khi build, chỉ dùng cấu hình công khai.

Để phát triển source SDK local, đặt `CUSTOMER_VOICE_LOCAL_SDK=/absolute/path/user_voice_sdk_ios` khi chạy generator. Không commit project chứa đường dẫn máy cá nhân; chạy lại generator không có biến này và `pod install` để trở về consumer binary.

[Source SDK và API](https://github.com/caresoftgit/user_voice_sdk_ios).
