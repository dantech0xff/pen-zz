# Mua trong app và quảng cáo

Bản Android và iOS có mua trong app qua RevenueCat và quảng cáo AdMob. Bản web chỉ để chơi thử nội bộ nên không có hai phần này.

Khi chưa có khoá thật, game vẫn chạy: quảng cáo dùng ID thử của Google (bấm thoải mái, không ra tiền), còn cửa hàng báo "chưa sẵn sàng".

## Quảng cáo

| Loại | Ở đâu | Luật |
|---|---|---|
| Thưởng nhân đôi | Thẻ kết quả trận | Mỗi trận một lần, khi trận có thưởng |
| Thưởng xu miễn phí | Cửa hàng | 3 lượt mỗi ngày, mỗi lượt 60 + 6 × số màn đã qua xu |
| Chen giữa | Khi rời thẻ kết quả | Chỉ sau khi qua màn 3, cứ 3 trận một lần, cách quảng cáo toàn màn hình trước đó (kể cả quảng cáo có thưởng) và lúc mở game ít nhất 150 giây |
| Banner | Dưới sảnh | Một banner cố định ở đáy màn hình |

Mua "Gỡ quảng cáo" sẽ tắt banner và quảng cáo chen giữa. Quảng cáo có thưởng vẫn còn vì người chơi tự chọn xem. Các con số nằm trong `AdRules` ở `lib/core/store_catalog.dart`.

Người chơi từ 13 tuổi trở lên, nên quảng cáo bị giới hạn ở mức nội dung T (Teen). Game hiện thông điệp xin đồng ý của Google (UMP) trước khi tải quảng cáo. Khi UMP yêu cầu, phần Cài đặt có nút "Tuỳ chọn quyền riêng tư cho quảng cáo".

## Sản phẩm

| Mã sản phẩm | Loại | Entitlement RevenueCat | Nội dung |
|---|---|---|---|
| `pz_remove_ads` | Mua một lần | `no_ads` | Tắt banner và quảng cáo chen giữa |
| `pz_starter_pack` | Mua một lần | `starter_pack` | 2.000 xu và mực Nhũ ngọc |
| `pz_set_royal` | Mua một lần | `set_royal` | Vương miện ngọc, áo choàng hoàng gia, mực vũ khí hoàng kim |
| `pz_set_galaxy` | Mua một lần | `set_galaxy` | Mũ ngân hà, áo choàng ngân hà, mực vũ khí ngân hà |
| `pz_coins_1000` | Tiêu hao | không có | 1.000 xu |
| `pz_coins_3500` | Tiêu hao | không có | 3.500 xu |
| `pz_coins_9000` | Tiêu hao | không có | 9.000 xu |

Giá do bạn đặt trên Google Play và App Store; game hiện giá lấy từ cửa hàng theo đơn vị tiền của người chơi. Đồ độc quyền chỉ để trang trí, mực độc quyền không có hiệu ứng đánh, bot không bao giờ dùng đồ độc quyền.

Danh sách sản phẩm nằm ở `storeProducts` trong `lib/core/store_catalog.dart`. Đổi mã hay thêm sản phẩm ở đó, rồi tạo lại đúng mã trên cửa hàng và RevenueCat.

## Thiết lập

### Google Play Console

1. Tạo app với mã ứng dụng `app.dantech.penzz`, bật Play App Signing và tạo khoá tải lên của riêng bạn.
2. Tải một bản `.aab` lên kênh Thử nghiệm nội bộ. Google chỉ cho tạo và thử sản phẩm khi app đã có bản tải lên.
3. Vào phần sản phẩm trong app (In-app products), tạo 7 mã ở bảng trên rồi kích hoạt.
4. Thêm tài khoản Google dùng để thử vào License testing, để mua thử không mất tiền.

### RevenueCat

1. Tạo project, thêm app Google Play với package name ở trên, và kết nối tài khoản dịch vụ (service account) theo hướng dẫn của RevenueCat.
2. Nhập 7 sản phẩm. Đặt 3 gói xu là Consumable, 4 sản phẩm còn lại là Non-consumable.
3. Tạo 4 entitlement `no_ads`, `starter_pack`, `set_royal`, `set_galaxy`, gắn mỗi cái với sản phẩm tương ứng.
4. Lấy Public SDK key của app Android (bắt đầu bằng `goog_`). Với iOS, thêm app App Store và lấy key bắt đầu bằng `appl_`.

### AdMob

1. Tạo app Android (và iOS), lấy App ID dạng `ca-app-pub-…~…`.
2. Với mỗi nền tảng, tạo 3 đơn vị quảng cáo: Banner, Interstitial, Rewarded.
3. Trong Privacy & messaging, tạo thông điệp GDPR cho người dùng châu Âu và Anh. Với iOS, tạo thêm thông điệp IDFA.
4. Đăng `app-ads.txt` trên website của bạn để quảng cáo được trả giá tốt hơn.

## Build kèm khoá thật

1. Chép `keys.example.json` thành `keys.json` ở thư mục gốc repo (file này đã nằm trong `.gitignore`), rồi điền khoá RevenueCat, ID AdMob và cấu hình Firebase ([luu-tren-may.md](luu-tren-may.md)). Ô nào để trống thì phần đó dùng mặc định: thiếu `RC_KEY_ANDROID` thì cửa hàng báo chưa sẵn sàng, thiếu một ID quảng cáo thì chỗ đó dùng quảng cáo thử, thiếu cấu hình Firebase thì chỉ lưu trên máy.
2. Để ký bằng khoá của bạn, tạo `android/key.properties` (cũng nằm ngoài git) với `storeFile`, `storePassword`, `keyAlias`, `keyPassword`. Không có file này thì bản release ký bằng khoá debug, chỉ dùng để cài thử.
3. Build. App ID AdMob của Android đi qua thuộc tính Gradle `admobAppId`:

```bash
flutter build appbundle --release --dart-define-from-file=keys.json -PadmobAppId=ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY
```

Khoá RevenueCat public và các ID AdMob vốn nằm sẵn trong app, không phải mật khẩu, nhưng không nên commit vào repo.

Với iOS (cần máy Mac): sửa `GADApplicationIdentifier` trong `ios/Runner/Info.plist`, thêm danh sách SKAdNetwork đầy đủ theo hướng dẫn của Google, bật In-App Purchase trong Signing & Capabilities của Xcode, rồi build với `RC_KEY_IOS` và các ID `ADMOB_*_IOS`.

## Kiểm tra trước khi phát hành

- Đừng bấm quảng cáo thật trên máy của mình. Dùng ID thử, hoặc khai báo máy của bạn là thiết bị thử trong AdMob.
- Dùng tài khoản License testing để mua thử từng sản phẩm, bấm "Khôi phục giao dịch", rồi xoá app, cài lại và khôi phục.
- Trên Play Console, điền Data safety (quảng cáo dùng mã quảng cáo, có mua hàng), thêm URL chính sách quyền riêng tư, và khai báo đối tượng từ 13 tuổi.

## Trong code

| Chỗ | Việc |
|---|---|
| `lib/core/store_catalog.dart` | Sản phẩm, entitlement, luật quảng cáo |
| `lib/monetize/` | `AdsService`, `StoreService`, bản AdMob và RevenueCat; `services.dart` chọn bản rỗng cho web |
| `lib/state/monetization.dart` | Nhân đôi thưởng, xu miễn phí, nhịp quảng cáo chen giữa, mua và khôi phục |
| `GameController.applyStore` | Entitlement mở đồ và tắt quảng cáo; gói xu cộng đúng một lần cho mỗi giao dịch |
| `lib/ui/screens/store_sheet.dart` | Màn cửa hàng |

Vài điều cần biết:

- Gói xu được ghi theo mã giao dịch của RevenueCat, lấy từ lịch sử mua mà RevenueCat trả về. Mỗi mã chỉ cộng một lần, mua bao nhiêu lần cũng vậy. Mã đơn hàng của Google trong kết quả mua không dùng tới, vì nó không bao giờ xuất hiện trong lịch sử.
- Gói xu không cộng lại khi cài lại app. Lần đầu bản lưu gặp cửa hàng, game ghi lại giờ của máy chủ cửa hàng (`storeSince`), không dùng giờ trên điện thoại. Gói xu mua trước mốc đó thuộc lần cài cũ nên được bỏ qua.
- Thanh toán đang chờ (ví dụ trả tiền mặt ở cửa hàng tiện lợi) được cộng khi RevenueCat báo giao dịch hoàn tất.
- Trường hợp hiếm: người chơi đã bị trừ tiền nhưng app chưa nhận được xác nhận (mất mạng đúng lúc đó), rồi xoá app và cài lại. Nếu người chơi đã liên kết Google, liên kết lại sau khi cài là gói xu được cộng (xem [luu-tren-may.md](luu-tren-may.md)). Nếu chưa liên kết, hãy tra giao dịch trên RevenueCat rồi bù cho người chơi.
- RevenueCat dùng mã người chơi Firebase làm App User ID khi bản build có cấu hình Firebase, nên đồ đã mua đi theo tài khoản.
- Xoá tiến trình vẫn giữ đồ đã mua, trạng thái gỡ quảng cáo và lịch sử giao dịch đã cộng.
- Bản web không có cửa hàng, nhưng vẫn tải file JavaScript của RevenueCat (khoảng 1 MB) đi kèm gói `purchases_flutter`, vì gói này có bản web. Game không gọi tới file đó. Việc này đã được chấp nhận vì bản web chỉ dùng nội bộ.
- Đồ đã mua không bị thu hồi khi hoàn tiền: đồ độc quyền và "Gỡ quảng cáo" giữ nguyên, để người đã trả tiền không bao giờ thấy quảng cáo quay lại khi đổi tài khoản. Trong RevenueCat, giữ Restore behavior là "Transfer to new App User ID" (mặc định).
- Chưa có: gói đăng ký, server riêng.
