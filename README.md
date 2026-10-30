# Workflow phát triển Fore

Workflow này dùng để rà soát và hoàn thiện ứng dụng Fore đang có, không phải bộ khung để tạo app mới.

## File chính
- `SPEC.md`: mục tiêu, người dùng, nghiệp vụ và luật sản phẩm.
- `TODO.md`: backlog theo trạng thái repo; mỗi vòng xử lý đúng một mục.
- `AGENTS.md`: hướng dẫn, giới hạn và tiêu chí an toàn cho AI.
- `NOTES.md`: quyết định, kết quả và việc cần chủ database.
- `scripts/check.sh`: người chấm — Flutter analyze, Flutter tests, invariant checks; `--full` thêm Android debug build.
- `scripts/loop.sh`: bounded loop qua Codex CLI hoặc Claude CLI.

## Trước khi chạy
1. Dùng Git Bash hoặc WSL tại repo `D:/fore_project`.
2. Đảm bảo `git status --short` sạch. Loop cố ý dừng nếu có thay đổi chưa commit, để không stage nhầm công việc sẵn có.
3. Xác nhận CLI hoạt động: `codex --version` hoặc `claude --version`.
4. Kiểm tra TODO đầu tiên còn phù hợp với sản phẩm và máy có Flutter/Android build prerequisites.

## Chạy an toàn
Chạy thử một vòng trước:

```bash
AGENT=codex MAX_ITER=1 bash workflow/scripts/loop.sh
```

`MAX_ITER` là giới hạn cứng số vòng agent. Agent lỗi thì dừng ngay, không retry/ngủ. Mỗi vòng chạy `check.sh`; khi qua và working tree sạch từ đầu, loop tạo commit riêng. Khi TODO hết, loop chạy `check.sh --full` một lần rồi dừng.

Codex CLI cần có trong PATH của Git Bash. Codex desktop và Codex CLI là hai cách chạy riêng; app desktop không tự làm cho lệnh `codex` xuất hiện trong terminal. `codex exec` flags có thể khác theo phiên bản; nếu lỗi, xem `workflow/.loop/agent_N.log` và `codex exec --help` trước khi sửa script.

## Giới hạn
- Loop không chạy nếu repo có thay đổi chưa commit.
- Không chạy reset/seed database; `database/` chỉ đọc.
- Lỗi check sau một vòng được đánh dấu trong `workflow/.loop/check_failed`; vòng kế tiếp chỉ sửa check đó.
- Không dùng workflow để tự động triển khai, publish hoặc đụng dữ liệu production.
