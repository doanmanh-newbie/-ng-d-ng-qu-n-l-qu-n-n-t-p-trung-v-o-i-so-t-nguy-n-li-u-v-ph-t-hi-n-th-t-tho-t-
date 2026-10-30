# TODO — rà soát và hoàn thiện Fore hiện có

Mỗi lượt chỉ làm đúng một mục `[ ]` đầu tiên theo `AGENTS.md`. Các mục này là việc kiểm chứng repo hiện tại, không phải dựng ứng dụng từ đầu. Nếu một tiêu chí đã đạt, bổ sung bằng chứng test/ghi chú và chờ script tick sau khi check xanh, không viết lại tính năng.

## Nền tảng, phiên và vòng đời ca
- [x] T01 Đồng bộ workflow với repo thật.
  Xong khi: SPEC mô tả đúng stack/thư mục hiện có; TODO không còn yêu cầu cài framework đã có hoặc đổi Provider; các script chạy từ repo root dù được gọi qua `scripts/`; script dừng khi agent lỗi và không stage/commit thay đổi ngoài lượt.
- [ ] T02 Rà soát đăng ký, đăng nhập, khôi phục phiên và phân quyền vai trò.
  Trạng thái: chờ check xanh
  Xong khi: test xác nhận đăng nhập sai hiện lỗi, phiên được khôi phục/đăng xuất đúng, chủ và nhân viên vào đúng không gian; mọi luồng demo/passwordless được ghi rõ là thử nghiệm và không trình bày như xác thực production.
  Bằng chứng: `login_controller_test.dart` kiểm tra thông tin sai; `session_controller_test.dart` kiểm tra khôi phục và đăng xuất; `role_home_screen_test.dart` kiểm tra không gian theo vai trò thật. Luồng tạo/đăng nhập nhân viên hiện cảnh báo rõ trong UI là thử nghiệm không an toàn; `StaffCredentials` ghi rõ rủi ro.
- [ ] T03 Rà soát khởi tạo quán, chuyển quán, lời mời và nhóm nhân viên.
  Trạng thái: chờ check xanh
  Xong khi: test bao phủ chủ tạo quán, đổi quán, lời mời chờ/nhận/từ chối và lỗi quyền; RLS vẫn là lớp bảo mật chính.
  Bằng chứng: `shop_flow_test.dart` bao phủ tạo/chuyển quán, nhận/từ chối lời mời, gửi lời mời nhân viên và lỗi quyền; `008_staff_setup.sql` dùng RPC `SECURITY DEFINER` kiểm tra vai trò/định danh, còn `shop_invites` bật RLS và chỉ cấp quyền đọc lời mời chủ quán.

- [ ] T04 Rà soát vòng đời ca và kiểm kê đếm mù.
  Trạng thái: chờ check xanh
  Xong khi: test bao phủ mở ca, trạng thái nhiều thiết bị, nhắc kiểm kê đầu ca, bắt buộc kiểm kê cuối ca, chặn đóng ca khi còn bill/mục đếm thiếu; không có số dự kiến hay kết quả đúng/sai trong UI nhân viên.
  Bằng chứng: `shift_controller_test.dart` bao phủ mở ca, ca vừa mở/đóng trên thiết bị khác và từ chối đóng khi bill/kiểm kê còn thiếu; `stocktake_controller_test.dart` bao phủ kiểm kê đầu/cuối ca, số 0 hợp lệ, đếm lại từ ô trống và xóa số sau khi lưu; `no_shift_view_test.dart` xác nhận có lời nhắc kiểm kê đầu ca sau khi mở ca, có thể chọn đếm ngay. `StocktakeScreen` chỉ hiện tiến độ và trạng thái đã đếm, không hiển thị lượng đã nhập hay đúng/sai.

## Nâng cấp giao diện chủ quán và nhân viên
- [ ] T11 Giao diện chủ quán 5 tab (Tổng quan, Đối soát, Thực đơn, Kho, Thêm) theo thiết kế đã duyệt.
  Xong khi: dữ liệu thật từ `shift_report` và các bảng đã có, không số mẫu; nhân viên không thấy các tab này; mỗi tab có test widget.
- [ ] T12 Màn Tổng quan chủ.
  Xong khi: kết luận Xanh/Vàng/Đỏ ở đầu, 5 ca gần nhất kèm trạng thái, cảnh báo cần kiểm tra; hiển thị theo SPEC mục 13–14, không có chữ “gian lận”.
- [ ] T13 Màn Báo cáo ca đủ 6 khối của SPEC mục 13.
  Xong khi: ước tiền có nhãn “ước tính”, không cộng tổng ước tiền; test với dữ liệu mẫu cho cả 4 trạng thái `ok`/`warn`/`alert`/`no_data`.
- [ ] T14 Thống nhất giao diện nhân viên: sơ đồ bàn, bill, thanh toán đúng SPEC mục 3–5, trạng thái bàn có chữ.
  Xong khi: không còn màn trùng chức năng; test điều hướng chính qua.

## Vận hành: bàn, bill, kho và thu chi
- [ ] T05 Rà soát bàn, bill, đơn mang đi và thanh toán.
  Xong khi: test bao phủ tạo bill, món/số lượng/tổng, lý do khi sửa/hủy, hai phương thức thanh toán, cập nhật xung đột từ máy khác; không thêm hành vi ngoài SPEC.
- [ ] T06 Rà soát kho, nhập hàng, hao hụt và thu/chi.
  Xong khi: test xác nhận đơn vị gốc và số nguyên, danh mục hao hụt lấy từ dữ liệu, ghi chú bắt buộc đúng trường hợp, nhân viên không xem tồn/lịch sử bị cấm.

## Chủ quán và chất lượng
- [ ] T07 Rà soát dashboard, báo cáo đối soát, danh sách ca và thông báo.
  Xong khi: test xác nhận chủ thấy doanh thu/ca/cảnh báo từ dữ liệu thật, nhân viên không truy cập được dữ liệu chủ, cảnh báo có chữ/biểu tượng và diễn đạt không kết luận thất thoát.
- [ ] T08 Rà soát quản lý thực đơn, nguyên liệu, cài đặt và lịch sử điều chỉnh.
  Xong khi: test xác nhận thao tác thêm/sửa/ẩn đúng quyền, dữ liệu đã ghi không bị xóa, công thức size đã bán được bảo vệ, điều chỉnh giữ bản gốc và có lý do.
- [ ] T09 Rà soát trải nghiệm giao diện trên Android và web mục tiêu.
  Xong khi: chạy kiểm tra tự động liên quan và kiểm tra thủ công các luồng chính ở kích thước điện thoại; ghi nhận ảnh/thiết bị và lỗi còn lại; không tuyên bố Playwright nếu ứng dụng đang được kiểm tra qua Flutter.
- [ ] T10 Chạy kiểm tra phát hành và ghi lại giới hạn còn tồn tại.
  Xong khi: `bash scripts/check.sh --full` qua trên môi trường có dependency; test tự động qua; các bước cần Supabase/emulator thật được ghi riêng nếu không thể chạy trong CI/local.

- [ ] T15 Dọn mã cũ không còn dùng (`features/shell`, `home_tab`, `features/shift`) sau khi xác nhận không màn nào gọi tới.
  Xong khi: `flutter analyze` không lỗi, test không tham chiếu mã đã xóa.
