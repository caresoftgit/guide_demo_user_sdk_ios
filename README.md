# Demo và hướng dẫn Customer Voice iOS

Tích hợp chức năng **Gọi CSKH** và nhận cuộc gọi trong ứng dụng khách hàng.
Demo dùng **CustomerVoice 0.1.1**, giao diện nghe/gọi có sẵn của SDK, không có
màn hình quay số hoặc cấu hình trạng thái agent.
Yêu cầu iOS 15.1+, Xcode có toolchain Swift 6.2+ cho bộ dependency đã ghim;
bản source đã kiểm chứng trên Xcode 26.4 / Swift 6.3.

## Bắt đầu

1. Chuẩn bị gateway URL, Account ID, tài khoản test và đầu số được cấp từ Caresoft.
2. [Tạo App Caresoft và cấu hình APNs](docs/integration.md#2-tạo-app-trên-caresoft-và-cấu-hình-apns).
3. Clone repo này, sao chép cấu hình mẫu:

   ```sh
   cp Demo/Config/Config.example.xcconfig Demo/Config/Local.xcconfig
   open Demo/CustomerVoiceDemo.xcodeproj
   ```

4. Điền `Local.xcconfig`: HTTPS URL, Account ID, Caresoft App ID, đầu số, Bundle ID
   và Apple Team. URL trong xcconfig phải viết `https:/$()/ten-mien-cua-ban`
   để Xcode không hiểu `//` là comment. Không điền account API token vào file.
5. Xcode resolve package từ
   `https://github.com/caresoftgit/user_voice_sdk_ios.git`, **Exact Version 0.1.1**.
   Cần quyền Git đọc SDK nếu repository giới hạn truy cập.
6. Chọn scheme **CustomerVoiceDemo**, chọn Simulator rồi Run để kiểm tra gọi ra.
   Bản demo dùng APNs production; nhận cuộc gọi trên iPhone cần bản phân phối
   có entitlement production, ví dụ TestFlight.
7. Trong demo, nhấn **Đăng nhập**, nhập User ID đã xác thực và account API token,
   cấp quyền micro, chờ sẵn sàng rồi nhấn **Gọi CSKH**.

Form đăng nhập thuộc host demo. Khi tích hợp thật, ứng dụng cấp phiên theo luồng
đăng nhập sẵn có của mình. Không đưa token, private key hay Local.xcconfig vào Git.
Các giá trị trong cấu hình mẫu đều là placeholder, phải thay trước khi chạy.

## Đọc theo nhu cầu

| Tài liệu | Nội dung |
|---|---|
| [Tích hợp từng bước](docs/integration.md) | Tạo App, thêm SDK, login, readiness, UI, nhận gọi và logout |
| [API](https://github.com/caresoftgit/user_voice_sdk_ios/blob/0.1.1/docs/api.md) | Hàm, observable state, event, mã lỗi |
| [Chạy demo và checklist](docs/testing.md) | Luồng thao tác, kiểm thử thiết bị và UI harness |
| [Simulator](docs/simulator-testing.md) | Kiểm tra gọi ra bằng audio máy tính |
| [Signing/APNs](docs/production-signing.md) | Bundle/Team, profile và môi trường push |

## Cấu trúc

- `Demo/`: host SwiftUI, cấu hình mẫu và Xcode project đã ghim SDK.
- `Tests/`: UI harness dùng gateway/media giả, không tạo cuộc gọi thật.
- `scripts/`: tái tạo Xcode project; không cần chạy khi chỉ mở demo.

Project đã được sinh sẵn. Để tái tạo:

```sh
python3 scripts/generate-ui-test-project.py
```

Để phát triển bằng SDK checkout local, chạy lệnh sau rồi không commit project
chứa đường dẫn local; chạy lại lệnh không có biến môi trường để trở về bản Git:

```sh
CUSTOMER_VOICE_LOCAL_SDK=/absolute/path/user_voice_sdk_ios \
  python3 scripts/generate-ui-test-project.py
```

Hướng dẫn này chỉ chứa thông tin khách hàng cần tích hợp.
[Gateway server](https://github.com/caresoftgit/sdk_voice_gateway) được quản lý riêng.
