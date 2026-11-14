---
title: "Port Bút Chiến sang Flutter Flame: review, sửa lỗi, build web và APK"
date: 2026-11-14
summary: "Bản offline 120 màn đã xong; review tìm 9 lỗi (2 nặng làm mất đồ và nuốt phím Android), đã sửa, 27/27 test, build web và APK thành công"
---

# Port Bút Chiến sang Flutter Flame: review, sửa lỗi, build web và APK

## Chuyện gì đã xảy ra

- Bản web Bút Chiến (một file HTML/JS) được port sang Flutter 3.47.9 và Flame 1.38.2. Lõi game là Dart thuần, mô phỏng bước cố định 120 Hz với RNG theo seed. Nội dung gồm 120 màn trong 12 quyển vở, 12 sân có luật nhẹ, 35 mẫu vũ khí và 19 mẫu khiên cho bot, 6 loại mực có hiệu ứng, và thêm trang phục.
- Agent review độc lập xác nhận phần đánh nhau khớp bản gốc từng dòng, ngoài các thay đổi có chủ đích. Nó tìm ra 9 lỗi:
  - Nặng: dập mẫu đồ có thể vượt 800 mực. Lần mở game sau, `SaveData.fromJson` xoá cả vũ khí lẫn khiên khi tổng quá 830. Bản web gốc cũng có luật xoá này.
  - Nặng: `BattleGame.onKeyEvent` trả `handled` cho mọi phím. Phím âm lượng không chạy trong trận, Back không tới được `PopScope` trên Android 15 trở xuống, và mỗi sự kiện phím còn ghi đè trạng thái nút cảm ứng (bấm âm lượng làm rơi khiên).
  - Vừa: nét vũ khí kéo ra ngoài khung vẽ có toạ độ quá ±420, nên `cleanStrokes` bỏ cả bản vẽ khi mở lại.
  - Nhẹ: nút vẫn nhận lệnh khi tạm dừng; Back hệ thống ở bước vẽ khiên lần đầu làm mất vũ khí; gradient mực đặc biệt không cập nhật khi đang vẽ; viền chữ không mờ dần; người thắng đứng khựng sau trận; bong bóng thoại ném lỗi khi màn hình quá hẹp.

## Đã sửa

- `trimInk` cắt nét theo ngân sách mực. Lưu và đọc đồ đều cắt bớt chứ không xoá. `cleanStrokes` tách nét tại điểm hỏng. Màn vẽ giữ nét trong khung và từ chối mẫu không đủ mực, có gợi ý xoá bớt nét.
- Trạng thái phím và nút cảm ứng tách riêng. Phím không dùng trả `ignored` để hệ thống xử lý. Nút và phím đánh không có tác dụng khi tạm dừng.
- Màn vẽ có `PopScope` riêng đi theo các bước của nó. Cache gradient được khoá theo kích thước danh sách nét. Viền chữ mờ theo alpha, lượng tử 32 mức để tái dùng layout. `Battle.step` tiếp tục chạy động tác sau trận nhưng không chạy logic hiệp.
- Thêm 9 test hồi quy, tổng 27/27 test qua, `flutter analyze` sạch. Build web và APK release (51,7 MB) thành công. Đã chụp màn hình kiểm tra trận đầu và cả 12 sân.

## Trục trặc môi trường

- `repo.maven.apache.org` trả 429 khi build APK. Đã thêm init script Gradle trỏ sang mirror của Google, chỉ trên máy build này (`~/.gradle/init.d/maven-mirror.gradle`).
- Formatter kiểu mới tách `if` một dòng thành nhiều dòng, làm lint `curly_braces_in_flow_control_structures` báo lỗi ở `lib/render/fx.dart`. Đã thêm ngoặc.

## Quyết định

- Giữ công thức gốc. Các thay đổi có chủ đích: độ lì theo cấp, điểm nâng cấp giảm dần sau 20, chiều gió ngẫu nhiên mỗi hiệp, sàn co lại sau 75 giây.
- Không tự bật GitHub Pages vì repo đang public; để người dùng quyết.

## Việc tiếp theo

- Thử trên máy Android thật: Back trên Android 13 đến 15, rung, âm thanh.
- Tạo khoá ký release và chốt `applicationId` trước khi đưa lên Google Play.
- Quyết định có deploy bản web lên GitHub Pages hay không.
- Build iOS cần máy Mac có Xcode.

> Historical work record — not durable authority. Prefer docs/specs/ADRs for current decisions.
