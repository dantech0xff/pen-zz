# Kế hoạch: port Bút Chiến sang Flutter + Flame (bản offline)

Trạng thái: đang làm. Repo: `dantech0xff/pen-zz`, mã ở `/home/user/pen-zz`.

## Kết quả cần đạt

Một game mobile chơi offline (Android, mã nguồn iOS, web) giữ nguyên vòng chơi gốc: vẽ vũ khí và khiên với 800 mực, rồi đấu người que, trúng đòn cộng % và văng khỏi sàn. Game được mở rộng lên 120 màn, 12 sân đấu có luật nhẹ, nhiều vũ khí hơn (vũ khí cho bot, mẫu vũ khí và khiên mở khoá khi hạ trùm, mực có hiệu ứng đánh), thêm trang phục và hiệu ứng.

## Ràng buộc

- Giữ đúng công thức gốc: mực ra công/thủ, độ dài và chiều cao ra thời gian ra đòn, % và độ văng, đỡ và đỡ chuẩn, cách AI bot hành xử. Cảm giác ở các màn đầu phải giống bản web.
- Flutter 3.47.9 và Flame 1.38.2, giao diện tiếng Việt, màn dọc.
- Chỉ chạy offline, lưu tiến trình trên máy.

## Ngoài phạm vi

Đấu trường online, tài khoản, backend, kiếm tiền, ngôn ngữ khác, file cài iOS (không có máy Mac).

## Tiêu chí nghiệm thu

1. `flutter analyze` không lỗi; `flutter test` qua hết, gồm so khớp chỉ số vũ khí và khiên với mã JS gốc, trận đấu tái lập được theo seed, dữ liệu màn hợp lệ, lưu và đọc lại tiến trình.
2. 120 màn trong 12 quyển vở, mỗi quyển một sân riêng, trùm ở màn 5 và 10, mỗi màn chấm 1–3 sao.
3. Luật sân chạy đúng: gió, sàn trơn, sàn hẹp và rộng, sàn co dần, bùn.
4. Hơn 30 vũ khí cho bot; 14 mẫu vũ khí và 14 mẫu khiên dùng được trong màn vẽ; 6 loại mực có hiệu ứng, có kiểm tra cân bằng bằng mô phỏng.
5. Trang phục: ít nhất 15 mũ, 12 áo choàng, 10 kính, 12 màu mực, 15 hiệu ứng trúng đòn, 10 động tác ăn mừng.
6. `flutter build web` và `flutter build apk --release` chạy thành công; ảnh chụp bản web cho thấy các màn hiển thị đúng.
7. Mã được đẩy lên GitHub.

## Các bước

1. Lõi game bằng Dart thuần: hình học nét vẽ, bộ xương, chỉ số đồ, RNG, mô phỏng trận, AI, luật sân, hiệu ứng mực. Viết test, so khớp với mã JS gốc.
2. Nội dung: mẫu đồ, tủ đồ, sân, màn, sinh đối thủ; mô phỏng để cân bằng.
3. Đồ hoạ: vẽ nhân vật, hiệu ứng, sân, chữ.
4. Màn đấu bằng Flame, âm thanh, rung phản hồi.
5. Giao diện các màn, trạng thái, lưu tiến trình.
6. Tài nguyên: font, âm thanh, icon, cấu hình nền tảng.
7. Kiểm tra: analyze, test, build web và chụp màn hình, build APK; review; đẩy code.
