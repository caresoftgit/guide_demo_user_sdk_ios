# Test gọi ra trên Simulator

1. Mở Simulator và chọn máy đã cài demo; mở app **CSKH Voice**.
2. Cho phép micro khi được hỏi. macOS cũng phải cho phép Simulator dùng micro.
3. Nhấn **Đăng nhập**, điền User ID và account API token của môi trường test.
4. Đợi **Sẵn sàng gọi hỗ trợ**. Việc chưa sẵn sàng nhận cuộc gọi trên Simulator là bình thường.
5. Nhấn **Gọi CSKH**. Demo dùng đầu số đã điền trong `Demo/Config/Local.xcconfig`, kết nối gateway và LiveKit thật.
6. Dùng micro/loa máy tính. Kiểm tra âm thanh hai chiều với hệ thống, mute và DTMF khi ACTIVE.
7. Nhấn **Kết thúc** để dừng micro ngay và trở về Home.

Simulator không nhận APNs VoIP/CallKit cuộc gọi đến như iPhone thật. Kiểm thử nhận cuộc gọi trên iPhone qua bản phân phối có môi trường APNs phù hợp; xem [signing](production-signing.md).

Khi tự build Simulator, dùng signing ad hoc/Run mặc định của Xcode để Keychain hoạt động. Bản build với `CODE_SIGNING_ALLOWED=NO` chỉ dùng kiểm tra compiler và có thể lỗi Keychain khi chạy.
