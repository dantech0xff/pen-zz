# Kế hoạch: mua trong app (RevenueCat) và quảng cáo (AdMob)

Trạng thái: đang làm. Quyết định của người dùng (14/11/2026): IAP dùng RevenueCat, quảng cáo dùng AdMob, bản web chỉ để chơi thử nội bộ nên không có hai tính năng này.

## Kết quả cần đạt

Bản Android và iOS có:

- Quảng cáo AdMob: xem quảng cáo để nhân đôi xu và kinh nghiệm sau trận, xem quảng cáo nhận xu miễn phí (giới hạn mỗi ngày), quảng cáo chen giữa các trận (giới hạn tần suất), banner ở sảnh.
- Mua qua RevenueCat: gỡ quảng cáo, ba gói xu, gói khởi đầu, hai bộ trang phục độc quyền, khôi phục giao dịch.

## Ràng buộc

- Người chơi từ 13 tuổi. Xin đồng ý quảng cáo qua UMP của Google; có nút tuỳ chọn quyền riêng tư khi UMP yêu cầu.
- Chưa có khoá thật: quảng cáo dùng ID thử của Google, khoá RevenueCat đưa vào bằng `--dart-define`. Thiếu khoá thì cửa hàng báo chưa sẵn sàng, game vẫn chạy bình thường.
- Không bán sức mạnh: đồ độc quyền chỉ để trang trí, mực độc quyền không có hiệu ứng đánh. Bot không dùng đồ độc quyền.
- Bản web không gọi SDK quảng cáo hay RevenueCat.

## Ngoài phạm vi

Gói đăng ký (subscription), server riêng xác minh giao dịch (RevenueCat đã xác minh với cửa hàng), mediation quảng cáo, analytics, thu hồi đồ trang trí khi hoàn tiền.

## Tiêu chí nghiệm thu

1. `flutter analyze` sạch, `flutter test` qua. Có test cho: nhân đôi phần thưởng chỉ một lần mỗi trận, giới hạn xu miễn phí theo ngày, nhịp quảng cáo chen giữa, gỡ quảng cáo tắt banner và quảng cáo chen giữa, một giao dịch gói xu chỉ cộng xu một lần, gói khởi đầu chỉ cộng xu một lần, đồ độc quyền không mua được bằng xu.
2. `flutter build apk --release` và `flutter build web --release` chạy thành công.
3. Cấu hình nền tảng: App ID AdMob của Android lấy từ thuộc tính Gradle (mặc định ID thử); `Info.plist` của iOS có `GADApplicationIdentifier`, `SKAdNetworkItems`, `NSUserTrackingUsageDescription`.
4. Tài liệu hướng dẫn tạo sản phẩm trên Google Play và RevenueCat (mã sản phẩm, entitlement), tạo đơn vị quảng cáo AdMob, và lệnh build kèm khoá thật.

## Các bước

1. Luật kinh tế và dữ liệu lưu (Dart thuần) cùng test.
2. Dịch vụ: giao diện chung, bản AdMob và RevenueCat cho mobile, bản rỗng cho web và test (import có điều kiện).
3. Giao diện: thẻ kết quả, tủ đồ, cửa hàng, sảnh, cài đặt; đồ độc quyền.
4. Cấu hình Android và iOS, tài liệu.
5. Kiểm tra, build, review, đẩy code.
