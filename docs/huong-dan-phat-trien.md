# Bút Chiến bản Flutter: hướng dẫn phát triển

Bút Chiến là game đối kháng người que. Người chơi tự vẽ vũ khí và khiên với 800 mực, rồi đánh văng đối thủ khỏi sàn. Bản này port từ bản web (một file HTML) sang Flutter và Flame, chơi offline, có 120 màn.

## Yêu cầu

- Flutter 3.47.9 (Dart 3.13). Bản mới hơn cùng nhánh 3.x thường vẫn chạy được, nhưng dự án được kiểm tra với bản này.
- Build Android cần Android SDK 36, build-tools 36.0.0 và NDK 28.2.13676358.
- Build iOS cần máy macOS có Xcode. Mã nguồn iOS đã cấu hình sẵn: tên app, khoá màn dọc, icon.

## Lệnh thường dùng

```bash
flutter pub get
```

```bash
flutter run
```

```bash
flutter run -d chrome
```

```bash
flutter analyze
```

```bash
dart format lib test tool
```

`dart format` đọc độ rộng dòng 120 từ `analysis_options.yaml`.

```bash
flutter test
```

```bash
flutter build apk --release
```

```bash
flutter build web --release --no-web-resources-cdn
```

Bản web build với `--no-web-resources-cdn` để CanvasKit nằm sẵn trong thư mục build, chơi được khi không có mạng. Nếu deploy vào một đường dẫn con (ví dụ GitHub Pages `/pen-zz/`), thêm `--base-href /pen-zz/`. Bản web chỉ để chơi thử nội bộ, không có mua trong app và quảng cáo.

Bản Android và iOS có mua trong app (RevenueCat) và quảng cáo (AdMob). Build như trên thì dùng quảng cáo thử của Google và cửa hàng chưa mở. Cách tạo sản phẩm, lấy khoá và build bản thật nằm ở [kiem-tien.md](kiem-tien.md).

Bản Android và iOS lưu tiến trình lên Firebase khi build kèm cấu hình Firebase; không có cấu hình thì chỉ lưu trên máy. Cách thiết lập nằm ở [luu-tren-may.md](luu-tren-may.md).

Bản release ký bằng khoá trong `android/key.properties` (nằm ngoài git, gồm `storeFile`, `storePassword`, `keyAlias`, `keyPassword`). Không có file đó thì ký bằng khoá debug của Flutter, chỉ dùng để cài thử. Mã ứng dụng là `app.dantech.penzz` (`applicationId` trong `android/app/build.gradle.kts`); đổi trước lần đầu đưa lên Google Play nếu muốn, vì sau đó không đổi được nữa.

## Cấu trúc mã

| Thư mục | Nội dung |
|---|---|
| `lib/core` | Dart thuần, không phụ thuộc Flutter: hình học nét vẽ, bộ xương người que, chỉ số đồ, mô phỏng trận, AI, sân, màn, đối thủ, tủ đồ, lưu tiến trình |
| `lib/render` | Vẽ bằng Canvas: người que và trang phục, hiệu ứng hạt, sân đấu, chữ |
| `lib/game` | `BattleGame` chạy trên Flame: bước mô phỏng cố định 120 Hz, camera, hiệu ứng, âm thanh, rung |
| `lib/state` | `GameController`: tiến trình, mua đồ, cộng điểm, phần thưởng, sao, mở khoá mẫu. `Monetization`: luật quảng cáo, mua và khôi phục giao dịch. `CloudSync`: gộp và tải bản lưu lên mây |
| `lib/monetize` | Quảng cáo AdMob, cửa hàng RevenueCat và lưu trên mây Firebase cho mobile; bản rỗng cho web và test |
| `lib/ui` | Các màn hình Flutter: sảnh, vẽ đồ, trước trận, trận đấu, nâng cấp, tủ đồ, cửa hàng, luyện tập, cài đặt |
| `tool` | Công cụ phụ trợ, xem mục dưới |
| `test` | Test lõi game, so khớp với bản web, luồng giao diện |

## Công cụ

- `node tool/parity/gen-golden.mjs` tạo lại `test/fixtures/gear_golden.json` từ mã JavaScript gốc. Test `gear_parity_test.dart` dùng file này để đảm bảo chỉ số vũ khí, khiên và bộ xương giống hệt bản web.
- `dart run tool/balance.dart` mô phỏng hàng trăm trận AI với AI. Công cụ in tỉ lệ thắng của một người chơi mẫu ở từng quyển vở, và tỉ lệ thắng của từng loại mực hiệu ứng khi đấu với chính nó.
- `python3 tool/gen-sfx.py` dựng lại các tiếng của bản web (bộ tổng hợp WebAudio), cùng các tiếng mới, thành file WAV trong `assets/audio`.
- `node tool/icon/make-icon.js` vẽ icon vào `assets/icon`. Sau đó chạy `dart run flutter_launcher_icons` để sinh icon cho từng nền tảng.

## Gameplay giữ nguyên từ bản web

- Mực vẽ ra công và thủ. Độ dài vũ khí quyết định thời gian vung (tăng theo bình phương), chiều cao khiên quyết định thời gian giơ khiên.
- Va chạm tính theo đúng bộ xương. Khiên chỉ chặn khi đã giơ hẳn. Giơ khiên trong 0,2 giây trước khi đòn tới là đỡ chuẩn, làm đối thủ choáng.
- Khi đòn trúng khiên, bên có chỉ số thấp hơn bị đẩy lùi theo phần chênh lệch giữa công và thủ.
- Trúng đòn cộng %, % càng cao thì càng văng xa. Văng khỏi sàn là thua hiệp, thắng 2 hiệp là thắng trận.
- Bot vẽ khiên sau khi thấy vũ khí của bạn. AI giữ nguyên logic gốc: phản xạ, đỡ, lùi né, phạt khi đối thủ hớ.

## Thay đổi so với bản web

- Mô phỏng chạy theo bước cố định 120 Hz, mỗi trận có bộ sinh số ngẫu nhiên riêng với seed. Nhờ vậy trận đấu trên máy 60, 90 hay 120 Hz như nhau, và test có thể chạy lại trận y hệt.
- Điểm nâng cấp tính đủ tới 20 điểm (đúng như bản gốc), từ điểm thứ 21 trở đi hiệu quả giảm dần.
- Thêm chỉ số độ lì theo cấp. Đòn văng tính tương đối giữa công bên đánh và độ lì bên bị đánh, nên ở màn cao một đòn không còn đủ đánh văng ngay.
- Đối thủ mỗi màn là cố định: cùng tên, cùng vũ khí, cùng trang phục ở mọi lần đánh. Riêng khiên thì bot vẽ lại mỗi trận.
- Gió ở các sân đổi chiều ngẫu nhiên theo từng hiệp, để người chơi đứng bên trái không được lợi sẵn.
- Hiệp kéo dài quá 75 giây thì sàn bắt đầu co lại, tránh trận đấu bế tắc.
- Thêm nút tạm dừng, hướng dẫn ở trận đầu tiên, rung phản hồi, sao cho từng màn và phần cài đặt.

## Nội dung

| Quyển vở | Sân | Luật sân | Mẫu mở khoá (màn 5 / màn 10) |
|---|---|---|---|
| Vở Toán | Trang ô li | Như bản gốc | Khiên cục tẩy / Com-pa |
| Vở Văn | Giấy dòng kẻ | Vệt mực loang làm chậm bước | Khiên quyển sách / Bút lông |
| Vở Tiếng Anh | Sổ chính tả | Sàn hẹp | Khiên quyển vở / Cờ hiệu |
| Vở Lý | Quạt trần | Gió đổi chiều mỗi 5 giây | Khiên đĩa quang / Nam châm |
| Vở Hóa | Phòng thí nghiệm | Sàn trơn | Khiên lục giác / Chùy phân tử |
| Vở Sử | Thành cổ | Sàn sụt dần sau 18 giây | Khiên mai rùa / Đại đao |
| Vở Địa | Bản đồ | Sàn rộng, đầm lầy gần mép | Khiên địa cầu / Mái chèo |
| Vở Sinh | Vườn trường | Gió nhẹ đổi chiều mỗi hiệp, vũng bùn | Khiên lá sen / Lá kiếm |
| Vở Mỹ thuật | Giá vẽ | Vũng sơn trơn | Khiên bảng màu / Cọ vẽ khổng lồ |
| Vở Thể dục | Sân trường | Sàn rộng, gió giật | Khiên ngôi sao / Vợt cầu lông |
| Vở Tin học | Màn hình | Sàn hẹp, co dần sau 15 giây | Khiên màn hình / Chuột cáp |
| Vở Âm nhạc | Khuông nhạc | Gió theo nhịp, sàn hơi trơn | Khiên mặt trống / Dùi trống trường |

Mỗi màn chấm tối đa 3 sao: thắng, thắng 2-0, và một thử thách riêng của màn. Bot dùng 35 mẫu vũ khí và 19 mẫu khiên. Người chơi có sẵn 2 mẫu vũ khí và 2 mẫu khiên, hạ trùm để mở thêm. Sáu loại mực đặc biệt (đá, gió, băng, lửa, sét, hút) có hiệu ứng đánh; mực cầu vồng chỉ để trang trí.

Có thể chỉnh độ khó từng quyển bằng `botPower` trong `lib/core/levels.dart`, chỉnh luật sân trong `lib/core/arenas.dart`, chỉnh hiệu ứng mực trong `lib/core/ink_fx.dart`. Sau mỗi lần chỉnh, chạy lại `dart run tool/balance.dart` để xem tác động.
