# Fore — hướng dẫn cho AI

## Nguồn sự thật
- Đây là repo Flutter/Dart hiện có. Trước khi chọn việc, kiểm tra `pubspec.yaml`, `lib/`, `test/` và các thay đổi Git.
- Stack hiện tại: Flutter, Dart, `supabase_flutter`, `provider`, PostgreSQL/Supabase. Không tự chuyển sang Riverpod, Go Router hay kiến trúc khác.
- Đặc tả sản phẩm: `workflow/SPEC.md`. Việc cần làm: `workflow/TODO.md`. Ghi chú: `workflow/NOTES.md`.
- `database/` là chỉ đọc đối với workflow này. Không sửa migration, seed hay dữ liệu Supabase.

## Mỗi lượt
1. Đọc SPEC, NOTES, TODO và `git status --short`.
2. Nếu `workflow/.loop/check_failed` tồn tại, chỉ sửa lỗi trong `workflow/.loop/check.log`.
3. Nếu không, lấy đúng mục `[ ]` đầu tiên trong `workflow/TODO.md`. Chỉ xử lý mục đó. Nếu mục đã hoàn thành trong code, kiểm chứng bằng code/test rồi đánh dấu hoàn thành, không dựng lại.
4. Trước khi sửa, xác định tiêu chí nghiệm thu và các file cần chạm. Giữ nguyên thay đổi có sẵn của người dùng.
5. Viết/cập nhật test cho hành vi thay đổi. Chạy `bash workflow/scripts/check.sh`; chỉ báo đạt khi lệnh trả mã 0.
6. Chỉ tick `[x]` khi tiêu chí và kiểm tra đạt. Ghi quyết định ngắn vào NOTES.
7. Không tự stage hoặc commit. Chỉ commit khi người dùng yêu cầu hoặc khi loop đã xác nhận working tree sạch trước khi bắt đầu và commit chỉ thay đổi của lượt đó.

## Luật sản phẩm
- Đếm mù: màn kiểm kê không hiện tồn dự kiến, tồn hệ thống, số đếm trước hay phản hồi đúng/sai. Nhân viên không xem tồn kho.
- Đối soát chỉ cảnh báo, không kết luận gian lận và không chặn thao tác. Cảnh báo chỉ ở giao diện chủ. Dùng “lệch”, “cần kiểm tra”; tránh “gian lận”, “trộm”.
- Màu trạng thái luôn có chữ hoặc biểu tượng đi kèm.
- Không xóa dữ liệu nghiệp vụ đã ghi; hủy/điều chỉnh phải giữ lịch sử và có lý do theo SPEC.
- Số lượng là số nguyên theo đơn vị gốc ml/g/cái; tiền là đồng nguyên, hiển thị theo quy ước của app.
- Khi có xung đột đồng thời `TABLE_HAS_OPEN_BILL`, `BILL_NOT_OPEN`, tải lại dữ liệu liên quan.
- Ẩn menu chủ với nhân viên chỉ là UX; quyền bảo mật thuộc RLS/database.

## Giới hạn và an toàn
- Một lượt = một mục TODO. Không mở rộng ngoài SPEC.
- Không chạy lệnh reset, seed hoặc phá hủy dữ liệu. Không đưa `.env`, anon/service keys hoặc thông tin xác thực vào Git.
- Không dùng `git add -A`. Không commit thay đổi có sẵn của người dùng.
- Nếu cần API/schema database chưa có, ghi vào “Cần chủ database” trong NOTES và đánh mục `[!]`; không tự sửa SQL.
- Nếu check lỗi, thử sửa tối đa hai lần. Nếu vẫn lỗi, ghi log/nguyên nhân vào NOTES, đánh `[!]` và dừng.
