# QA giao diện bằng Playwright — Fore

Mục đích: AI mở app trên trình duyệt, đi qua từng màn, bấm thử các nút và đối chiếu với `SPEC.md`. **AI chỉ báo lỗi, không sửa code.** Lỗi tìm được sẽ thành mục trong `TODO.md` để vòng build xử lý.

## Điều kiện bắt buộc
- App chạy ở cửa sổ khác: `flutter run -d web-server --web-port 8080 --dart-define-from-file=env.json`, trỏ vào **Supabase TEST**, không phải dữ liệu thật.
- Tài khoản test (chủ + nhân viên) nằm trong `qa-accounts.local.md` (file này không commit). Không bao giờ đưa mật khẩu hay khóa vào báo cáo, ảnh chụp hay chat.
- Dữ liệu AI tạo ra phải có tiền tố `QA-` (ví dụ ghi chú "QA-thử").

## Cách thao tác
1. Mở `http://localhost:8080`, đợi 5 giây, đặt khung 360x800 (`browser_resize`).
2. Bật trợ năng: `browser_evaluate` chạy `document.querySelector('flt-semantics-placeholder').click()` (bấm thường bị lỗi "outside of the viewport").
3. Ưu tiên `browser_snapshot` (văn bản, rẻ). Chỉ chụp ảnh khi cần xem bố cục hoặc màu.
4. **Mỗi lượt chỉ kiểm MỘT màn** (tiết kiệm hạn mức). Ghi kết quả vào `QA-REPORT.md`, mỗi dòng: Màn | Mục kiểm | Đạt / Lỗi / Không kiểm được | Bằng chứng (đường dẫn ảnh hoặc trích snapshot) | Ghi chú.
5. Không sửa file nào ngoài `QA-REPORT.md`. Không tự mở địa chỉ khác `localhost:8080`.

## Kiểm tra chung (mọi màn)
- Mọi nút/ô nhập có tên đọc được trong snapshot.
- Màu trạng thái xanh/vàng/đỏ luôn kèm chữ hoặc biểu tượng.
- Không có nút hay lệnh "Xóa" cho dữ liệu đã ghi.
- Tiền hiển thị dạng `29.000đ`; số lượng là số nguyên, không có số thập phân.
- Thông báo lỗi là câu tiếng Việt trong bảng "Thông báo lỗi" của SPEC, không lộ mã chữ hoa (ví dụ `NOT_STAFF`).
- Không có chữ "gian lận" hay "trộm". Không có lỗi đỏ trong console. Không bị tràn/cắt nội dung ở 360x800.

## Màn 1 — Đăng nhập
- Có ô email, ô mật khẩu, nút Đăng nhập (SPEC). Ghi lại mọi chỗ lệch SPEC, đặc biệt: nhân viên đăng nhập không cần mật khẩu.
- Nhập sai thông tin: hiện lỗi, không vào được app.
- Tài khoản chưa được thêm vào quán: hiện câu "chưa được thêm vào quán".
- Đúng thiết kế thử nghiệm, chỉ kiểm cảnh báo thử nghiệm còn hiện.
- Đăng nhập bằng nhân viên: menu **không** có mục của chủ.

## Màn 2 — Mở ca
- Có ô "Tiền đầu ca" và nút Mở ca. **Không** hiện số tiền đóng ca của ca trước.
- Đã có ca đang mở: nút đổi thành "Vào ca đang mở".

## Màn 3 — Sơ đồ bàn
- Bàn Trống / Đang dùng khác nhau và có chữ. Có nút "Mang đi".
- Chưa mở ca: hiện thông báo kèm nút Mở ca, không cho gọi món.

## Màn 4 và 5 — Bill, thanh toán
- **Không** hiện công thức hay nguyên liệu của món.
- Bỏ dòng, giảm giá, hủy bill: có ô lý do bắt buộc, nút xác nhận **khóa** cho đến khi điền.
- Giảm giá lớn hơn tổng tiền: báo lỗi.
- Bill trống: thanh toán báo "chưa có món". Thanh toán xong không sửa được bill.

## Màn 6 — Đơn mang đi
- Không bắt nhập tên hay số điện thoại khách. Bấm "Xong" thì đơn biến mất.

## Màn 7 — Hủy bill đã thu
- Ô PIN ẩn ký tự (4 đến 6 số). Thiếu lý do thì không xác nhận được. Sai PIN hiện "Sai PIN".

## Màn 8 — Nhập hàng
- Nhân viên **không** thấy lịch sử nhập và số tồn. Không có nút sửa hay xóa.

## Màn 9 — Kiểm kê (ĐẾM MÙ — quan trọng nhất)
- Đăng nhập bằng **nhân viên**. Đọc toàn bộ văn bản của màn: **không** được có số dự kiến, tồn hệ thống, số đếm lần trước.
- Sau khi nhập và lưu: **không** hiện đúng/sai hay chênh lệch.
- Nhân viên không có màn xem tồn kho ở bất kỳ mục menu nào (thử cả đường dẫn trực tiếp nếu biết).

## Màn 10, 11 — Hao hụt, thu chi
- Loại hao hụt chọn từ danh sách, không gõ tự do. Loại "Khác" ghi chú dưới 5 ký tự: báo lỗi.
- Chi tiền mặt không ghi chú: báo lỗi. Thu vào không bắt buộc ghi chú.

## Màn 12 — Đóng ca
- **Không** hiện số tiền đáng ra có, kết quả đối soát, doanh thu. Còn bill mở: liệt kê việc thiếu. Đóng xong chỉ hiện "Đã đóng ca".

## Màn 13 — Báo cáo ca (đăng nhập bằng chủ)
- Đầu màn có kết luận một dòng Xanh/Vàng/Đỏ.
- "Quy ra ly" và "ước tiền" có nhãn "ước tính"; **không** có tổng cộng ước tiền của nhiều nguyên liệu.
- Nhân viên không vào được màn này.
