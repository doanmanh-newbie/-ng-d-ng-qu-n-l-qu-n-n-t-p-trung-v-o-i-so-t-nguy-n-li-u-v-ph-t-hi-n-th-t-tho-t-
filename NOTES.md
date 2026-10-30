# NOTES — ghi nhớ workflow

## Quyết định
- Repo đã có app Flutter; giữ `provider` và kiến trúc hiện tại. Không chuyển framework chỉ vì TODO cũ ghi Riverpod/Go Router.
- `database/` chỉ đọc trong vòng lặp workflow.
- Loop mặc định tối đa 2 lượt; lỗi agent thì dừng, không tự retry/ngủ. Chạy thử bằng `MAX_ITER=1`.
- Loop chỉ chạy từ working tree sạch; commit tự động chỉ sau khi check qua và vì thế không gom thay đổi có sẵn của người dùng.

## Bài học / lỗi đã gặp
- TODO cũ được viết như app chưa tồn tại, khiến AI định dựng lại nền Flutter. Đã thay bằng backlog kiểm toán tính năng hiện có.
- Git Bash chạy từ `D:/fore_project`; script nằm ở `scripts/` ở gốc repo.
- Codex CLI không nhận `--full-auto` hoặc `--ask-for-approval` ở bản cài của người dùng. Loop dùng `codex exec --sandbox workspace-write`; nếu tham số còn sai, xem `.loop/agent_N.log` và `codex exec --help`.
- Một phiên Codex có log lỗi OAuth của Figma MCP; lỗi connector đó không phải lỗi Flutter. Chỉ xử lý nếu tác vụ thực sự cần Figma.

## Cần chủ database
- Chưa có.

- T01 xong: check.sh chạy qua (201 test, mất khoảng 35 giây), script chạy từ gốc repo.
- Codex không chạy được flutter trong sandbox (pub get, --version đều treo, trong khi Git Bash chạy bình thường). Codex chỉ sửa code; loop chạy check.sh bên ngoài sandbox.
- T02: luồng đăng nhập/tạo tài khoản nhân viên dùng thông tin liên hệ làm thông tin xác thực, nên đã cảnh báo rõ đây là thử nghiệm không an toàn ngay trên hai màn hình; test vai trò xác nhận không gian lấy từ hồ sơ, không lấy từ lựa chọn form.
- T03: luồng tạo/chuyển quán gọi RPC database; kiểm tra `008_staff_setup.sql` cho thấy các thao tác nhạy cảm dùng `SECURITY DEFINER` và kiểm tra quyền/định danh, `shop_invites` bật RLS. Thêm test controller/repository giả cho tạo/chuyển quán, lời mời chờ/nhận/từ chối và lỗi quyền. Chưa chạy Flutter theo quy tắc sandbox; loop sẽ chạy kiểm tra ngoài sandbox.
