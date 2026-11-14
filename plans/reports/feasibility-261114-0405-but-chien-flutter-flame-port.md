# Port "Bút Chiến" sang Flutter + Flame: khả năng và ước lượng

Ngày 14/11/2026. Phân tích dựa trên toàn bộ mã nguồn hiện tại của artifact "Bút Chiến" (2.328 dòng, trong đó 2.001 dòng JavaScript).

## Kết luận

Port được. Phần kỹ thuật ít rủi ro, vì game là một file HTML tự chứa: không thư viện ngoài, không ảnh. Mọi hình đều vẽ bằng Canvas 2D và âm thanh được tổng hợp bằng WebAudio, nên cả hai chuyển sang Canvas của Flutter gần như một đổi một.

Phần tốn công nhất không nằm ở việc dịch mã. Trên claude.ai, nền tảng đã cung cấp sẵn danh tính người chơi, cơ sở dữ liệu có phân quyền và một nhóm người chơi quen biết nhau. Khi lên App Store và Google Play, bạn phải tự làm các phần đó, đồng thời xử lý chống gian lận, kiểm duyệt hình người chơi vẽ, yêu cầu của cửa hàng và pháp lý.

Ước lượng dưới đây cho một lập trình viên đã quen Flutter, làm toàn thời gian, sai số khoảng ±30%:

| Phương án | Ngày công | Quy ra lịch |
|---|---|---|
| Bản offline: chơi đơn, tủ đồ, nâng cấp, đấu bóng ma của chính mình, bot luyện tập | 40–62 | khoảng 2–3 tháng |
| Bản đầy đủ: thêm đấu trường online, bảng xếp hạng, chống gian lận, kiểm duyệt | 57–91 | khoảng 3–4,5 tháng |

Nếu dùng tài khoản Google Play cá nhân, cần cộng thêm ít nhất 14 ngày thử nghiệm kín. Khoảng này có thể chạy song song với việc code.

Khuyến nghị: làm hai giai đoạn. Giai đoạn đầu ra bản offline. Giai đoạn sau mới thêm đấu trường online, khi đã chốt thị trường phát hành và tình trạng pháp lý.

## 1. Mã nguồn hiện có

| Nhóm | Dòng JS | Nội dung | Cách chuyển |
|---|---|---|---|
| Lõi mô phỏng | ~650 | Bộ xương IK, tư thế, đo nét vẽ (mực, tầm đánh, dài × rộng), chỉ số vũ khí và khiên, máy trạng thái đòn đánh, va chạm theo bộ xương, đỡ và đỡ chuẩn, văng theo %, AI bot, sinh đồ cho bot | Dịch thẳng sang Dart |
| Dữ liệu tủ đồ | ~90 | 6 nhóm vật phẩm và logic chọn màu mực | Dịch thẳng |
| Đồ hoạ | ~450 | Người que ba lớp nét, 5 nét mặt, 6 mũ, 5 áo choàng, 5 kính, mực gradient, 6 hiệu ứng trúng đòn, vệt vung, hạt, chữ nổi, sân vực | Dịch sang Canvas của Flutter, gần một đổi một |
| Giao diện | ~610, cộng 310 dòng HTML và CSS | 7 màn hình, màn vẽ đồ, nút điều khiển | Viết lại bằng widget |
| Nền tảng | ~180 | Lưu tiến trình, cơ sở dữ liệu, tên người chơi, âm thanh | Thay bằng Firebase, lưu cục bộ và file âm thanh |

Sau khi port, dự kiến khoảng 6.000–8.000 dòng Dart. Nếu có đấu trường online thì thêm khoảng 1.000–1.500 dòng cho backend.

## 2. Ánh xạ kỹ thuật

| Trên web | Trong Flutter/Flame | Ghi chú |
|---|---|---|
| Canvas 2D: path, arc, bezier, translate, rotate, scale, clip | `Canvas` và `Path` của `dart:ui` | Gần một đổi một; `arc` và `ellipse` có góc xoay cần viết lại theo API khác |
| `globalAlpha` (khiên mờ khi đang giơ, nền mực 12–14%) | Alpha trên từng `Paint`, hoặc `saveLayer` | Không dùng `saveLayer` thì chỗ các nét chồng nhau sẽ đậm hơn bản web |
| `setLineDash` (vùng vẽ khiên, vạch tầm đánh) | Flutter không có sẵn, phải tự cắt nét bằng `PathMetrics` | Khoảng nửa ngày |
| Gradient mực lửa, mực cầu vồng đổi màu | `ui.Gradient.linear` | Dễ |
| `fillText`, `strokeText` (chữ nổi, banner, bóng thoại) | `TextPainter` | Cần cache `TextPainter`, không tạo mới mỗi khung hình |
| `requestAnimationFrame`, dt giới hạn 33 ms | `update(dt)` của Flame | Nên đổi sang bước thời gian cố định (mục 3) |
| Pointer events, nút giữ, bàn phím | Widget `Listener`, `KeyboardEvents` của Flame | Các nút phải nhận đa điểm, ví dụ vừa giữ ĐỠ vừa giữ TỚI |
| WebAudio tổng hợp 9 tiếng | Render sẵn ra WAV hoặc OGG, phát bằng `flutter_soloud` hoặc `flame_audio` | Có thể render tự động bằng `OfflineAudioContext` trong Chromium |
| `localStorage` | File JSON hoặc `shared_preferences` | Dễ |
| `window.claude` (db, user) | Firebase Auth và Firestore | API gần giống, nhưng phải đổi cách lưu nét vẽ (mục 5.4) |
| CSS: viền vẽ tay, giấy ô li, xoay nhẹ | `BorderRadius` hỗ trợ bo elip từng góc; nền giấy vẽ bằng `CustomPainter` | Làm được, chỉ tốn thời gian |
| Font Coiny và Patrick Hand | Đóng gói file TTF (giấy phép OFL) | Kiểm tra đủ dấu tiếng Việt khi đóng gói |

## 3. Kiến trúc đề xuất

1. Lõi game là một package Dart thuần, không import Flutter. Package này chứa model, công thức chỉ số, bộ xương, mô phỏng trận, AI và công thức kinh tế. Nhờ vậy lõi chạy unit test nhanh, cho kết quả tái lập được, và sau này có thể chạy trên server để kiểm tra lại trận đấu.
2. Mô phỏng chạy theo bước thời gian cố định, ví dụ 120 Hz với bộ tích luỹ, và mỗi trận có một bộ sinh số ngẫu nhiên riêng với seed. Bản web dùng dt thay đổi theo khung hình, nên trận đấu trên máy 60, 90 và 120 Hz sẽ hơi khác nhau. Đấu trường cần công bằng nên phải sửa điểm này. Mã hiện có khoảng 40 dòng dùng số ngẫu nhiên.
3. Tách mô phỏng khỏi giao diện. Phần trận đấu hiện có 12 dòng ghi thẳng vào DOM (HUD, nút ĐÁNH sáng lên). Bản port nên để mô phỏng chỉ đổi state, còn giao diện tự đọc state đó.
4. Flutter làm vỏ ứng dụng, Flame chỉ dùng cho màn đấu. Các màn menu viết bằng widget. Nhân vật ở sảnh, thẻ trước trận, khung xem thử ở tủ đồ và khung vẽ dùng `CustomPainter` và gọi chung các hàm vẽ với màn đấu.
5. Lúc đầu, port nguyên cách vẽ tức thời (immediate mode) để giữ đúng cảm giác của bản web. Chỉ chuyển sang component của Flame ở những chỗ thấy thật sự có lợi.

Nói thẳng về Flame: game này không dùng sprite, tilemap hay engine vật lý. Flame chủ yếu cho vòng lặp game, camera, input, vòng đời ứng dụng và âm thanh. Phần nặng là code Dart không phụ thuộc framework. Chọn Flame không sai, nhưng dùng Flutter thuần (`CustomPainter` với `Ticker`) cũng làm được.

Phương án để so sánh: gói nguyên file HTML hiện tại bằng Capacitor thì phần chuyển đổi ước chừng chỉ mất 2–3 tuần thay vì 7–11 tuần. Các mục backend, kiểm duyệt và cửa hàng vẫn phải làm như nhau. Đổi lại, Flutter cho mã có kiểu dữ liệu, dễ phát triển lâu dài và tránh được các lỗi riêng của WebView về âm thanh, cảm ứng và bộ nhớ. Nếu bạn chọn Flutter vì muốn phát triển game lâu dài thì nên giữ lựa chọn này.

## 4. Hạng mục công việc và ước lượng

| # | Hạng mục | Việc cụ thể | Ngày công | Rủi ro |
|---|---|---|---|---|
| 0 | Khung dự án | Flutter và Flame, chia package, môi trường dev và prod, CI, font, lint | 2–3 | Thấp |
| 1 | Lõi game | Dịch phần mô phỏng và dữ liệu sang Dart, bước thời gian cố định, seed ngẫu nhiên, unit test | 6–9 | Thấp |
| 1b | Bộ so khớp với bản web | Chạy mô phỏng JS không giao diện với seed và chuỗi thao tác kịch bản, so trạng thái từng bước với bản Dart | 2–3 | Giảm rủi ro cho mục 1 |
| 2 | Đồ hoạ | Người que, trang phục, hiệu ứng, chữ nổi, rung màn, hitstop, sân đấu; so ảnh chụp với bản web | 7–11 | Vừa |
| 3 | Màn vẽ đồ | Bắt nét bút, giới hạn mực, vùng vẽ khiên, hoàn tác, chỉ số cập nhật trực tiếp, gợi ý so kèo, xem trước vũ khí đối thủ, bố cục cho máy màn nhỏ | 4–6 | Vừa |
| 4 | Giao diện 7 màn | Sảnh, trước trận, HUD và 4 nút giữ đa điểm, nâng cấp, tủ đồ 6 tab, đấu trường; theme vở ô li | 8–12 | Vừa |
| 5 | Âm thanh | Render 9 tiếng ra file, phát với độ trễ thấp, nút bật tắt, xử lý khi ứng dụng chạy nền | 1–2 | Thấp |
| 6 | Lưu cục bộ | Model có số phiên bản, làm sạch dữ liệu, ghi khi ứng dụng chạy nền | 1–2 | Thấp |
| 7 | Backend Firebase | Đăng nhập, cấu trúc dữ liệu mới, security rules và test trên emulator, đồng bộ tiến trình, bảng xếp hạng, ghép trận, nickname | 6–10 | Vừa |
| 8 | Chống gian lận | Cloud Function kiểm tra đồ khi đăng, cúp tính ở server qua vé trận, giới hạn tần suất, bảng xếp hạng tính sẵn | 5–8 | Cao |
| 9 | An toàn nội dung và tuân thủ | Báo cáo, chặn người chơi, ẩn đồ bị báo cáo, lọc nickname, xoá tài khoản, chính sách quyền riêng tư, khai báo dữ liệu | 4–7 | Cao |
| 10 | Nền tảng | Safe area, máy màn nhỏ và màn dài, khoá màn dọc, cỡ chữ hệ thống, rung phản hồi, tối ưu cho Android cấu hình thấp | 4–6 | Vừa |
| 11 | Kiểm thử và phát hành | Test tích hợp, thử trên nhiều máy, Crashlytics, TestFlight, thử nghiệm kín, icon, ảnh cho cửa hàng | 5–8 | Vừa |
| 12 | Chỉnh cảm giác tay | Cân lại tốc độ đi, thời gian vung, độ khó bot khi chơi bằng ngón tay | 2–4 | Vừa |
| | **Bản đầy đủ** | Tất cả các mục | **57–91** | |
| | **Bản offline** | Bỏ mục 7–9, rút gọn mục 4 và 11 | **40–62** | |

Rủi ro "Cao" nghĩa là bỏ qua thì ứng dụng không qua được xét duyệt của cửa hàng, hoặc bảng xếp hạng mất ý nghĩa.

Ước lượng chưa tính: màn chơi hay vật phẩm mới, nhạc nền, kiếm tiền (quảng cáo hoặc mua trong ứng dụng), ngôn ngữ khác ngoài tiếng Việt, PvP thời gian thực (đó là một dự án khác hẳn), kiểm tra replay trên server (thêm 10–15 ngày) và thời gian làm thủ tục pháp lý.

Nếu để Claude Code làm phần dịch mã máy móc ở mục 1–4 và lấy bộ so khớp làm đáp án, có thể rút bớt khoảng 2–4 tuần. Các phần thử trên máy thật, nộp cửa hàng, tuân thủ và chỉnh cảm giác tay thì gần như không rút ngắn được.

## 5. Những điểm dễ bị bỏ sót

### 5.1 Gian lận

Hiện mỗi người chơi tự ghi số cúp, cấp và điểm nâng cấp của mình vào `arena/<uid>`. Bên đọc chỉ kiểm tra tổng mực không quá 830 và giới hạn điểm theo cấp, mà cấp cũng do người chơi tự khai (tối đa 999). Giữa bạn bè trên claude.ai thì chấp nhận được. Trên cửa hàng, bảng xếp hạng sẽ bị sửa rất nhanh, vì ai cũng gọi thẳng được API của Firestore bằng token của chính mình.

Mức tối thiểu cần có:
- Security rules chỉ cho mỗi người ghi tài liệu của mình, và kiểm tra kiểu dữ liệu cùng giới hạn giá trị.
- Một Cloud Function đo lại mực và số điểm mỗi khi người chơi đăng đồ lên đấu trường.
- Cúp do server tính qua "vé trận": server chọn đối thủ và cấp mã trận, client báo kết quả đúng một lần, có giới hạn tần suất.

Kể cả có những thứ trên, kết quả thắng thua vẫn do client tự báo. Muốn chặn hẳn thì server phải chạy lại trận từ chuỗi thao tác, nên lõi game cần cho kết quả tái lập được như mục 3. Phần này để giai đoạn sau.

### 5.2 Hình vẽ do người chơi tạo

Vũ khí và khiên một người tự vẽ sẽ hiện trước mặt người lạ, và vẽ bậy bằng 800 mực rất dễ. Apple (mục 1.2 của hướng dẫn xét duyệt) và Google Play đều yêu cầu ứng dụng có nội dung do người dùng tạo phải lọc được nội dung, có nút báo cáo, cho chặn người dùng và công bố thông tin liên hệ.

Cụ thể cần:
- Nút báo cáo ở màn trước trận và sau trận.
- Tự ẩn bộ đồ sau một số lần bị báo cáo.
- Danh sách chặn được tính khi ghép trận.
- Bộ lọc nickname tiếng Việt và tiếng Anh.
- Một người xử lý báo cáo. Đây là chi phí vận hành lâu dài, không chỉ là code.

### 5.3 Tài khoản

- Dùng Firebase Anonymous Auth để người chơi vào ngay, rồi cho liên kết với Google hoặc Apple để giữ tiến trình.
- Nếu có đăng nhập bằng Google trên iOS, Apple yêu cầu thêm một lựa chọn đăng nhập bảo vệ quyền riêng tư tương đương (mục 4.8), mà trên thực tế là Sign in with Apple.
- Có cho tạo tài khoản thì phải cho xoá tài khoản ngay trong ứng dụng (Apple mục 5.1.1(v)). Google Play còn yêu cầu thêm một đường dẫn web để xoá.
- Tên trên bảng xếp hạng hiện lấy từ hồ sơ claude.ai, nên phải tự làm hệ thống nickname.

### 5.4 Firestore không nhận mảng lồng mảng

Nét vẽ đang lưu theo dạng `[[[x,y],…],…]`. Cơ sở dữ liệu của artifact chấp nhận dạng này, nhưng Firestore không cho một mảng chứa trực tiếp mảng khác.

Có hai cách đổi:
- Lưu thành `[{p:[x0,y0,x1,y1,…]}, …]`, vẫn làm tròn 0,1 như hiện tại.
- Nén thành Int16 rồi mã hoá base64, khoảng 20–27 KB cho 5.000 điểm.

Security rules không có vòng lặp nên không đo được độ dài nét. Việc kiểm tra mực vì vậy phải làm trong Cloud Function.

### 5.5 Chi phí đọc dữ liệu

Mỗi lần "Tìm trận" đọc tới 40 tài liệu, và đọc thêm 40 nếu không có ai trong khoảng ±200 cúp. Mỗi lần mở đấu trường đọc 30 tài liệu của bảng xếp hạng, rồi tra thêm tên người chơi. Hạn mức miễn phí khoảng 50.000 lượt đọc mỗi ngày, tương đương vài trăm lượt tìm trận.

Khi đã có người chơi thật thì nên:
- Tính sẵn bảng xếp hạng vào một tài liệu bằng hàm chạy định kỳ.
- Gom bóng ma thành từng nhóm theo khoảng cúp.
- Ghi kèm nickname vào tài liệu đấu trường.

Khi đó mỗi thao tác chỉ còn 1–2 lượt đọc.

### 5.6 Đấu trường trống lúc ra mắt

Những người chơi đầu tiên sẽ chỉ thấy thông báo "chỉ có bạn". Có thể dùng luôn hàm sinh đối thủ hiện có (`genStageOpp`) để tạo sẵn bóng ma bot, có ghi rõ là bot.

### 5.7 Cảm giác tay

Ngoài bước thời gian cố định, cần làm thêm:
- Các nút giữ dùng `Listener` để nhận đa điểm và tránh xung đột nhận diện cử chỉ.
- Rung phản hồi khi trúng đòn và khi đỡ chuẩn.
- Thử trên máy thật ngay từ sớm.

Một ví dụ lỗi dễ gặp khi dịch: `Math.round` của JS làm tròn 0,5 về phía dương vô cùng, còn `round()` của Dart làm tròn xa số 0. Vì vậy `eloDelta` khi thua (giá trị âm) có thể lệch 1 cúp. Bộ so khớp sẽ bắt được những lỗi kiểu này.

### 5.8 Hiệu năng trên Android cấu hình thấp

Mỗi khung hình, game vẽ lại toàn bộ nét của hai nhân vật, mỗi nét ba lớp. Va chạm được kiểm tra tới 14 bước con, mỗi bước so từng điểm vũ khí với từng điểm khiên. Dart biên dịch AOT thường không chậm hơn JS, nhưng vẫn nên:
- Cache vũ khí và khiên thành `Picture`, vì hình dạng không đổi trong trận.
- Dùng `Float32List` cho toạ độ điểm.
- Đo FPS trên một máy Android cấu hình thấp ngay tuần đầu.

### 5.9 Pháp lý nếu phát hành tại Việt Nam

Nghị định 147/2024/NĐ-CP có hiệu lực từ 25/12/2024:
- Game G1 (nhiều người chơi tương tác qua máy chủ) cần giấy phép và quyết định phát hành.
- Game G2–G4 cần giấy chứng nhận và giấy xác nhận thông báo phát hành.
- Các loại giấy này đều cấp cho doanh nghiệp.
- Tài khoản người chơi phải xác thực bằng số điện thoại Việt Nam, người dưới 16 tuổi do cha mẹ đăng ký.
- Người dưới 18 tuổi bị giới hạn giờ chơi. Các bài tổng hợp nêu 60 phút mỗi game và 180 phút tổng mỗi ngày, và hiện đang có dự thảo sửa đổi.

Đấu bóng ma bất đồng bộ nằm ở vùng xám giữa G1 và G2. Cơ quan quản lý cũng đã nhiều lần phối hợp với Apple và Google gỡ game không phép tại Việt Nam.

Đây là điểm duy nhất có thể chặn hẳn kế hoạch, và nó không phải chuyện kỹ thuật, nên cần luật sư xác nhận trước khi chọn thị trường. Hai cách thường gặp:
- Phát hành quốc tế trước, không chọn storefront Việt Nam.
- Lập doanh nghiệp, hoặc hợp tác với một nhà phát hành đã có giấy phép.

### 5.10 Yêu cầu của cửa hàng

- Trên Google Play, tài khoản cá nhân tạo sau ngày 13/11/2023 phải chạy thử nghiệm kín với ít nhất 12 người tham gia liên tục trong 14 ngày rồi mới được xin phát hành chính thức. Tài khoản tổ chức không bị yêu cầu này nhưng cần số D-U-N-S.
- Cả hai cửa hàng đều cần chính sách quyền riêng tư, phần khai báo dữ liệu và bảng câu hỏi xếp hạng độ tuổi.
- Chủ đề trường học dễ thu hút trẻ dưới 13 tuổi. Nếu nhắm tới trẻ em, game sẽ phải theo chính sách dành cho gia đình của Google Play và mục Kids của Apple, vốn hạn chế SDK quảng cáo và analytics. Vì vậy nên chủ động chọn độ tuổi mục tiêu từ 13 trở lên.

## 6. Lộ trình

1. Thử nghiệm kỹ thuật 3 ngày, làm điểm quyết định có đi tiếp hay không. Port phần lõi và dựng một trận tối thiểu trên Flame, chạy trên một iPhone và một máy Android cấu hình thấp. Đo FPS, độ trễ chạm và kiểm tra nút giữ đa điểm.
2. Dựng bộ so khớp. Chạy mô phỏng JS trong Node với seed và chuỗi thao tác kịch bản, ghi lại trạng thái từng bước, rồi yêu cầu bản Dart cho kết quả trùng khớp. Muốn vậy phải tách nhẹ phần mô phỏng khỏi DOM hoặc giả lập DOM.
3. Giai đoạn 1, bản offline, khoảng 8–12 tuần: các mục 0–6 và 10–12. Nên mở thử nghiệm kín trên Google Play càng sớm càng tốt để 14 ngày chờ chạy song song với việc code.
4. Giai đoạn 2, bản online, khoảng 4–6 tuần: các mục 7–9. Chỉ mở đấu trường ở những thị trường đã rõ pháp lý.

## Câu hỏi chưa giải quyết

- Phát hành ở thị trường nào, có storefront Việt Nam không? Câu trả lời quyết định phần pháp lý ở mục 5.9.
- Bản đầu tiên có cần đấu trường online không, hay chấp nhận ra bản offline trước?
- Có kiếm tiền không? Nếu bán xu bằng mua trong ứng dụng, kinh tế xu và vật phẩm phải chuyển lên server, và ước lượng sẽ tăng đáng kể.
- Người chơi mục tiêu bao nhiêu tuổi?
- Có cần chuyển tiến trình của người đang chơi trên claude.ai sang ứng dụng không?
- Bao nhiêu người làm, và đã quen Flutter hay Flame chưa? Ước lượng đang giả định một người đã quen Flutter.
- Hỗ trợ cả iPad hay chỉ iPhone?

## Nguồn

- Flame: [pub.dev – flame](https://pub.dev/documentation/flame/latest/), [GameDev.net – Flame v1.38.1](https://gamedev.net/news/5334-flame-engine-v1381-released/)
- Firestore: [Các kiểu dữ liệu được hỗ trợ](https://firebase.google.com/docs/firestore/manage-data/data-types)
- Apple: [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- Google Play: [Yêu cầu thử nghiệm với tài khoản cá nhân mới](https://support.google.com/googleplay/android-developer/answer/14151465)
- Nghị định 147/2024: [LuatVietnam – Kinh doanh trò chơi điện tử trên mạng](https://luatvietnam.vn/linh-vuc-khac/kinh-doanh-tro-choi-dien-tu-tren-mang-883-100134-article.html), [LuatVietnam – Cung cấp trò chơi G1](https://luatvietnam.vn/linh-vuc-khac/lam-the-nao-de-duoc-cung-cap-tro-choi-dien-tu-g1-883-99958-article.html), [Hoatieu – Giới hạn giờ chơi](https://hoatieu.vn/phap-luat/nguoi-duoi-18-tuoi-khong-duoc-choi-game-qua-60-phut-ngay-226987), [Thuviennhadat – Người dưới 16 tuổi](https://thuviennhadat.vn/phap-ly-nha-dat/nguoi-choi-tro-choi-dien-tu-tren-mang-duoi-16-tuoi-phai-duoc-cha-me-dang-ky-tai-khoan-605500.html), [VietNamNet – Siết game không phép](https://vietnamnet.vn/en/vietnam-cracks-down-on-unlicensed-games-with-new-regulation-2346358.html), [VnExpress – 142 game bị gỡ](https://e.vnexpress.net/news/news/142-illegal-games-removed-from-apple-google-app-stores-in-vietnam-3953610.html)
