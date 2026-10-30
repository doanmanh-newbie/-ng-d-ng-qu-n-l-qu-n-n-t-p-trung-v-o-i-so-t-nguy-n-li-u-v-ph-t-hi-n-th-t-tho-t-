# TODO — rà soát và hoàn thiện Fore hiện có

Mỗi lượt chỉ làm đúng một mục `[ ]` đầu tiên theo `workflow/AGENTS.md`. Các mục này là việc kiểm chứng repo hiện tại, không phải dựng ứng dụng từ đầu. Nếu một tiêu chí đã đạt, bổ sung bằng chứng test/ghi chú rồi tick `[x]`, không viết lại tính năng.

## Giai đoạn 1 — nền và phiên
- [ ] T01 Đồng bộ workflow với repo thật.
  Xong khi: SPEC mô tả đúng stack/thư mục hiện có; TODO không còn yêu cầu cài framework đã có hoặc đổi Provider; các script chạy từ repo root dù được gọi qua `workflow/scripts/`; script dừng khi agent lỗi và không stage/commit thay đổi ngoài lượt.
- [ ] T02 Rà soát đăng ký, đăng nhập, khôi phục phiên và phân quyền vai trò.
  Xong khi: test xác nhận đăng nhập sai hiện lỗi, phiên được khôi phục/đăng xuất đúng, chủ và nhân viên vào đúng không gian; mọi luồng demo/passwordless được ghi rõ là thử nghiệm và không trình bày như xác thực production.
- [ ] T03 Rà soát khởi tạo quán, chuyển quán, lời mời và nhóm nhân viên.
  Xong khi: test bao phủ chủ tạo quán, đổi quán, lời mời chờ/nhận/từ chối và lỗi quyền; RLS vẫn là lớp bảo mật chính.

## Giai đoạn 2 — vận hành
- [ ] T04 Rà soát vòng đời ca và kiểm kê đếm mù.
  Xong khi: test bao phủ mở ca, trạng thái nhiều thiết bị, nhắc kiểm kê đầu ca, bắt buộc kiểm kê cuối ca, chặn đóng ca khi còn bill/mục đếm thiếu; không có số dự kiến hay kết quả đúng/sai trong UI nhân viên.
- [ ] T05 Rà soát bàn, bill, đơn mang đi và thanh toán.
  Xong khi: test bao phủ tạo bill, món/số lượng/tổng, lý do khi sửa/hủy, hai phương thức thanh toán, cập nhật xung đột từ máy khác; không thêm hành vi ngoài SPEC.
- [ ] T06 Rà soát kho, nhập hàng, hao hụt và thu/chi.
  Xong khi: test xác nhận đơn vị gốc và số nguyên, danh mục hao hụt lấy từ dữ liệu, ghi chú bắt buộc đúng trường hợp, nhân viên không xem tồn/lịch sử bị cấm.

## Giai đoạn 3 — chủ quán và chất lượng
- [ ] T07 Rà soát dashboard, báo cáo đối soát, danh sách ca và thông báo.
  Xong khi: test xác nhận chủ thấy doanh thu/ca/cảnh báo từ dữ liệu thật, nhân viên không truy cập được dữ liệu chủ, cảnh báo có chữ/biểu tượng và diễn đạt không kết luận thất thoát.
- [ ] T08 Rà soát quản lý thực đơn, nguyên liệu, cài đặt và lịch sử điều chỉnh.
  Xong khi: test xác nhận thao tác thêm/sửa/ẩn đúng quyền, dữ liệu đã ghi không bị xóa, công thức size đã bán được bảo vệ, điều chỉnh giữ bản gốc và có lý do.
- [ ] T09 Rà soát trải nghiệm giao diện trên Android và web mục tiêu.
  Xong khi: chạy kiểm tra tự động liên quan và kiểm tra thủ công các luồng chính ở kích thước điện thoại; ghi nhận ảnh/thiết bị và lỗi còn lại; không tuyên bố Playwright nếu ứng dụng đang được kiểm tra qua Flutter.
- [ ] T10 Chạy kiểm tra phát hành và ghi lại giới hạn còn tồn tại.
  Xong khi: `bash workflow/scripts/check.sh --full` qua trên môi trường có dependency; test tự động qua; các bước cần Supabase/emulator thật được ghi riêng nếu không thể chạy trong CI/local.
