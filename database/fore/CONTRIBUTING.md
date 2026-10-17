# Quy tắc làm việc

## Nhánh và Pull Request
- Không code trực tiếp trên `main`. Mỗi việc một nhánh: `feat/ten-viec`, `fix/ten-loi`, `docs/ten-tai-lieu`.
- Xong việc thì mở Pull Request, **ít nhất 1 người khác xem** rồi mới gộp.
- Mỗi PR gắn với 1 issue (`Closes #12`).

## Commit
Dạng: `loại: mô tả ngắn`. Loại: `feat`, `fix`, `docs`, `test`, `refactor`.
Ví dụ: `feat: thêm màn hình nhập kiểm kê`. Commit đều mỗi ngày làm việc.

## Quy tắc code (bắt buộc)
- Tiền = số nguyên (đồng). Định lượng = số nguyên theo đơn vị gốc (ml, g, cái).
- Giá lưu theo thời điểm bán, không tính lại.
- Hóa đơn, nhập, kiểm kê, hao hụt, nhật ký: chỉ thêm, không sửa, không xóa (hủy = đổi trạng thái kèm lý do).
- Công thức đối soát nằm ở database, app chỉ gọi và hiển thị.
- Không đưa khóa bí mật lên GitHub. Lỡ đưa thì đổi khóa ngay.
- Kiểm kê: nhân viên nhập số đo trước, app chưa hiện số dự kiến.

## Thế nào là "xong"
Chạy được trên điện thoại, đúng tiêu chí trong issue, người khác đã xem PR, người làm giải thích lại được cho nhóm.

## Kẹt thì sao
Kẹt quá 2 giờ phải hỏi trong nhóm. Hỏi sớm là việc tốt.
