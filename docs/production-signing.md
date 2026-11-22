# Production signing và APNs

Luồng xác thực hiện tại: [phiên doanh nghiệp → ticket PKCE → SDK](host-bootstrap.md).

Bản demo đã chọn APNs **production**. Cài trực tiếp một bản ký Apple Development
sẽ nhận token sandbox và **không tương thích** cấu hình production này.
Không đổi environment tự động để che lỗi signing.

1. Chủ tài khoản Apple chọn kênh: Ad Hoc, Enterprise (nếu đủ điều kiện) hoặc
   TestFlight/App Store. TestFlight cần quyền upload và quy trình riêng.
2. Cung cấp distribution identity hợp lệ trên máy build hoặc ký ở CI/máy do bạn quản lý.
   Không đưa `.p12`, private key hay mật khẩu vào source hoặc bản demo bàn giao.
3. Provisioning profile phải có Bundle ID/Team đúng app và `aps-environment=production`.
   Ad Hoc cần UDID iPhone trong profile. Profile App Store dùng kênh TestFlight/App Store.
4. Mở `Demo/CustomerVoiceDemo.xcodeproj`, chọn target `CustomerVoiceDemo`.
   Bundle ID/Team và version/build lấy từ `Demo/Config/Local.xcconfig`; file này
   không đưa vào Git/source ZIP. Project mặc định bật Automatic Signing.
   Kiểm tra Signing & Capabilities và profile đúng Team/Bundle ID; nếu dùng profile
   quản lý thủ công, chuyển signing tương ứng trong Xcode. Chọn Any iOS Device
   rồi Product → Archive. Chỉ upload TestFlight sau khi chủ tài khoản duyệt.
   Đối chiếu version/build đã có trên App Store Connect trước khi archive để upload.
5. Kiểm tra entitlements của **app đã ký**, không chỉ file Demo.entitlements:

```sh
codesign -d --entitlements :- /path/to/CustomerVoiceDemo.app
```

6. Cài bằng kênh phân phối đã chọn, login, xác nhận token VoIP đã đăng ký vào đúng
   cấu hình iOS production. APNs private key chỉ nằm trong cấu hình server.
7. Nghiệm thu theo ma trận `testing.md`. App Store review cần mô tả việc dùng VoIP
   cho cuộc gọi thật; không dùng PushKit để gửi dữ liệu nền không liên quan cuộc gọi.

Unsigned build chỉ chứng minh compiler/linker đã qua. Không thể gửi IPA unsigned
để cài iPhone hoặc coi build Development là bằng chứng APNs production.
