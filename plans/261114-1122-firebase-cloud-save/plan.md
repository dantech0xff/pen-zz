# Kế hoạch: lưu tiến trình lên Firebase

Trạng thái: xong phần code, chờ project Firebase thật (14/11/2026). Quyết định của người dùng (14/11/2026): lưu toàn bộ tiến trình lên Firebase; người chơi bắt đầu ẩn danh, liên kết Google để giữ tiến trình khi cài lại hoặc đổi máy; khi bản trên máy và bản trên mây khác nhau thì tự lấy bản tiến xa hơn, đồ mua bằng tiền thật và xu đã nạp luôn được gộp. Bản web (chỉ dùng nội bộ) không lưu lên mây.

## Kết quả cần đạt

- Bản Android và iOS tự lưu toàn bộ bản lưu (xu, cấp, màn, sao, đồ, bản vẽ, sổ giao dịch) lên Firestore, dưới tài khoản Firebase ẩn danh tạo lúc mở game.
- Cài đặt có nút liên kết Google. Cài lại hoặc sang máy khác, liên kết lại cùng tài khoản Google thì tiến trình quay về. Cửa hàng nhắc liên kết sau lần mua đầu tiên.
- RevenueCat dùng cùng mã người chơi với Firebase, nên đồ đã mua đi theo tài khoản.
- Gói xu đã trả tiền nhưng chưa kịp cộng (mất mạng rồi cài lại) được cộng khi người chơi liên kết lại tài khoản.
- Có nút xoá tài khoản và dữ liệu trên mây (chính sách Google Play cho app có tạo tài khoản).

## Ràng buộc

- Game vẫn chơi được hoàn toàn offline; bản lưu trên máy là chính, mây đồng bộ khi có mạng.
- Chưa có project Firebase: cấu hình qua `--dart-define`; thiếu cấu hình thì tắt lưu trên mây, game chạy như cũ.
- Gộp hai bản lưu: lần xoá tiến trình mới hơn (epoch) thắng; sau đó bản qua nhiều màn hơn, rồi cấp cao hơn. Giao dịch gói xu và gói khởi đầu chỉ ở một bản thì cộng xu vào bản được chọn; đồ độc quyền và gỡ quảng cáo gộp từ cả hai; lượt xu miễn phí trong ngày lấy số lớn hơn; âm thanh và rung giữ theo máy này.
- Luật Firestore: mỗi người chỉ đọc, ghi, xoá tài liệu của mình.

## Ngoài phạm vi

Server riêng hoặc Cloud Functions, chống gian lận bản lưu trên mây, Sign in with Apple (cần khi làm bản iOS có Google sign-in), Play Games Services, lưu trên mây cho bản web.

## Tiêu chí nghiệm thu

1. `flutter analyze` sạch, `flutter test` qua. Có test cho: luật gộp (epoch, tiến xa hơn, gộp giao dịch và gói khởi đầu không cộng hai lần, đồ độc quyền, gỡ quảng cáo, lượt xu miễn phí, cài đặt theo máy), đồng bộ lúc mở game, tải lên sau thay đổi, xoá tiến trình lan lên mây, liên kết sang tài khoản đã có, đổi mã người chơi của RevenueCat.
2. `flutter build apk --release` và `flutter build web --release` chạy thành công khi chưa có cấu hình Firebase.
3. Có `firestore.rules` và `firebase.json` để deploy luật; tài liệu hướng dẫn tạo project, bật Anonymous và Google, thêm SHA-1, tạo Firestore, deploy luật và build kèm cấu hình.

## Các bước

1. Bản lưu: thêm `epoch`, sổ giao dịch ghi kèm số xu; luật gộp thuần Dart cùng test.
2. Dịch vụ: `CloudService` (giao diện, bản Firebase cho mobile, bản rỗng cho web và test); `StoreService.identify`.
3. `CloudSync`: đồng bộ lúc mở game, tải lên sau thay đổi và khi ẩn app, liên kết Google, xoá tài khoản; nối với RevenueCat.
4. Giao diện: Cài đặt, nhắc liên kết trong cửa hàng.
5. Luật Firestore, cấu hình, tài liệu; kiểm tra, build, review, đẩy code.

## Kết quả

- `flutter analyze` sạch, `flutter test` qua 83/83, gồm test luật gộp, đồng bộ với bản mây giả mô phỏng Firestore (đọc từ máy chủ, ghi theo phiên bản, không có hàng đợi offline), liên kết và xoá tài khoản, RevenueCat đổi tài khoản qua kênh SDK giả lập.
- `flutter build apk --release` và `flutter build web --release` chạy thành công khi chưa có cấu hình Firebase; bản web không chứa mã lưu trên mây.
- Review độc lập: `plans/reports/code-reviewer-261114-1122-cloud-save-review.md`, 15 lỗi, đã sửa hết. Hai lỗi mất dữ liệu (bộ nhớ đệm và hàng đợi ghi của Firestore; số lần xoá tiến trình so giữa hai tài khoản) được thay bằng đọc từ máy chủ, ghi theo phiên bản và epoch theo tài khoản.
- Xoá tài khoản làm trong game theo quyết định của người dùng; link web cho Play Console ghi trong tài liệu.
- Còn lại: chưa có project Firebase thật nên chưa thử trên máy; Sign in with Apple khi làm bản iOS.

