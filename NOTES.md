# NOTES — ghi nhớ workflow

## Quyết định
- Repo đã có app Flutter; giữ `provider` và kiến trúc hiện tại. Không chuyển framework chỉ vì TODO cũ ghi Riverpod/Go Router.
- `database/` chỉ đọc trong vòng lặp workflow.
- Loop mặc định tối đa 2 lượt; lỗi agent thì dừng, không tự retry/ngủ. Chạy thử bằng `MAX_ITER=1`.
- Loop chỉ chạy từ working tree sạch; commit tự động chỉ sau khi check qua và vì thế không gom thay đổi có sẵn của người dùng.

## Bài học / lỗi đã gặp
- TODO cũ được viết như app chưa tồn tại, khiến AI định dựng lại nền Flutter. Đã thay bằng backlog kiểm toán tính năng hiện có.
- Git Bash chạy từ `D:/fore_project`; script phải tự dùng đường dẫn `workflow/`.
- Codex CLI không nhận `--full-auto` hoặc `--ask-for-approval` ở bản cài của người dùng. Loop dùng `codex exec --sandbox workspace-write`; nếu tham số còn sai, xem `workflow/.loop/agent_N.log` và `codex exec --help`.
- Một phiên Codex có log lỗi OAuth của Figma MCP; lỗi connector đó không phải lỗi Flutter. Chỉ xử lý nếu tác vụ thực sự cần Figma.

## Cần chủ database
- Chưa có.
