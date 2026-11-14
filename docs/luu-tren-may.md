# Lưu tiến trình trên mây (Firebase)

Bản Android và iOS lưu toàn bộ tiến trình lên Firestore: xu, cấp, màn, sao, đồ, bản vẽ vũ khí và khiên, sổ giao dịch đã mua. Bản web chỉ dùng nội bộ nên chỉ lưu trên máy.

Khi build không kèm cấu hình Firebase, phần lưu trên mây tắt hẳn: game chạy và lưu trên máy như cũ, Cài đặt không hiện mục "Lưu trên mây".

## Người chơi thấy gì

- Mở game là có một tài khoản ẩn danh, tiến trình tự sao lưu. Không cần đăng nhập.
- Cài đặt có mục "Lưu trên mây" với nút "Liên kết Google". Cửa hàng nhắc liên kết sau khi người chơi đã mua gì đó.
- Cài lại app hoặc sang máy khác: bấm "Liên kết Google", chọn đúng tài khoản cũ, tiến trình quay về.
- Có nút "Xoá tài khoản và dữ liệu trên mây". Google Play yêu cầu nút này với app cho tạo tài khoản. Tiến trình trên máy vẫn giữ và được sao lưu dưới một tài khoản ẩn danh mới.

Tài khoản chỉ ẩn danh (chưa liên kết Google) sẽ mất khi xoá app, vì mã ẩn danh nằm trên máy. Đó là lý do game nhắc liên kết.

## Đồng bộ chạy thế nào

- Bản lưu trên máy là bản game dùng để chơi, nên game chơi offline được hoàn toàn.
- Mỗi lần mở game (và khi quay lại app), game tải bản trên mây về và gộp với bản trên máy, một lần cho mỗi phiên và mỗi tài khoản. Trước khi gộp xong, game không tải gì lên, nên mở game lúc mất mạng không thể ghi đè một bản tốt hơn trên mây.
- Sau khi gộp, mỗi thay đổi được tải lên sau khoảng 8 giây, và ngay khi app bị ẩn.

Luật gộp (`lib/core/save_merge.dart`):

1. Bản có lần "Xoá tiến trình" mới hơn thắng (số `epoch` trong bản lưu). Nhờ vậy xoá tiến trình trên một máy thì áp dụng cho cả tài khoản.
2. Nếu không, bản qua nhiều màn hơn thắng; bằng nhau thì bản cấp cao hơn, rồi nhiều kinh nghiệm hơn, rồi nhiều trận hơn. Bằng hết thì giữ bản trên máy.
3. Đồ mua bằng tiền thật luôn được gộp từ cả hai bản:
   - gói xu và gói khởi đầu chỉ có ở bản thua thì cộng xu vào bản thắng, mỗi giao dịch một lần;
   - đồ độc quyền và gỡ quảng cáo được giữ.
4. Lượt xu miễn phí trong ngày lấy số đã dùng lớn hơn. Âm thanh và rung giữ theo máy đang dùng.

Tiến trình chơi của bản thua (màn, cấp, xu kiếm được, bản vẽ) bị bỏ, theo đúng lựa chọn "tự lấy bản tiến xa hơn".

## Mua hàng đi theo tài khoản

RevenueCat dùng mã người chơi Firebase làm App User ID. Game gọi `logIn` sau khi đã gộp bản lưu, để mốc thời gian mua hàng đã đúng. Nhờ vậy, trường hợp hiếm "đã trả tiền gói xu nhưng mất mạng, rồi cài lại app" được giải quyết, miễn là người chơi đã liên kết Google:

1. Cài lại, liên kết lại tài khoản Google cũ.
2. Game chuyển về mã người chơi cũ và gộp bản lưu cũ, trong đó có mốc `storeSince` và sổ giao dịch.
3. RevenueCat trả lịch sử mua của mã đó. Giao dịch chưa có trong sổ thì được cộng.

## Thiết lập Firebase

### Tạo project

1. Vào Firebase console, tạo project.
2. Thêm app Android với package `io.github.dantech0xff.pen_zz`.
3. Thêm SHA-1 và SHA-256 của mọi khoá ký app:
   - khoá debug: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android`;
   - khoá tải lên của bạn;
   - khoá Play App Signing, lấy ở Play Console, phần App integrity.
4. Authentication: bật Anonymous và Google.
5. Firestore Database: tạo database ở chế độ production, chọn vùng gần người chơi (ví dụ `asia-southeast1`).
6. Deploy luật trong repo:

```bash
firebase deploy --only firestore:rules --project <project-id>
```

### Lấy cấu hình

Trong Project settings, ở app Android, lấy:

| Biến `--dart-define` | Lấy ở đâu |
|---|---|
| `FB_PROJECT_ID` | Project ID |
| `FB_API_KEY` | Web API key (cũng có trong `google-services.json`, trường `current_key`) |
| `FB_SENDER_ID` | Project number |
| `FB_APP_ID_ANDROID` | App ID của app Android, dạng `1:…:android:…` |
| `GOOGLE_SERVER_CLIENT_ID` | OAuth client loại "Web application" mà Firebase tạo khi bật Google (Authentication, Google, Web SDK configuration, Web client ID) |

Đây là các mã định danh vốn nằm trong app, không phải mật khẩu. Dữ liệu được bảo vệ bằng luật Firestore. Dù vậy, nên để chúng trong một file ngoài git và build bằng `--dart-define-from-file`:

```bash
flutter build appbundle --release --dart-define-from-file=../pen-zz-keys.json
```

File đó có thể chứa luôn khoá RevenueCat và ID AdMob (xem [kiem-tien.md](kiem-tien.md)), ví dụ:

```json
{
  "FB_PROJECT_ID": "pen-zz-xxxx",
  "FB_API_KEY": "AIza...",
  "FB_SENDER_ID": "123456789012",
  "FB_APP_ID_ANDROID": "1:123456789012:android:abcdef",
  "GOOGLE_SERVER_CLIENT_ID": "123456789012-xxxx.apps.googleusercontent.com",
  "RC_KEY_ANDROID": "goog_..."
}
```

### iOS (cần máy Mac)

Thêm app iOS trong Firebase rồi điền `FB_APP_ID_IOS` và `GOOGLE_IOS_CLIENT_ID`. Thêm `REVERSED_CLIENT_ID` vào `CFBundleURLTypes` trong `ios/Runner/Info.plist` theo hướng dẫn của gói `google_sign_in`. App Store yêu cầu có thêm Sign in with Apple khi app cho đăng nhập Google; phần này chưa làm.

## Trước khi phát hành

- Play Console, Data safety: khai báo thu thập mã người dùng (Firebase), email (khi liên kết Google) và tiến trình chơi; dữ liệu được mã hoá khi truyền; người dùng xoá được dữ liệu.
- Google Play yêu cầu thêm một đường link web để người dùng xin xoá tài khoản mà không cần mở app. Tạo một trang (hoặc biểu mẫu, email) cho việc đó rồi điền vào Play Console.
- Thử: liên kết Google trên máy A; xoá app, cài lại, liên kết lại; chơi trên máy B rồi mở máy A; xoá tiến trình trên một máy rồi mở máy kia; xoá tài khoản.

## Giới hạn

- Người chơi có thể sửa bản lưu trên mây của chính mình (ví dụ cộng xu). Với game chơi một mình thì chấp nhận được; muốn chặn cần server riêng, nằm ngoài phạm vi.
- Khi chuyển sang tài khoản Google đã có, tài khoản ẩn danh cũ và bản lưu của nó vẫn nằm lại trên Firestore. Bản lưu này nhỏ và không ai đọc tới.
- Hai máy cùng chơi một lúc: bản tiến xa hơn thắng ở lần mở game sau, tiến trình của bản kia mất (đồ đã mua thì không mất).
