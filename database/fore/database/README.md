# Database của Fore (PostgreSQL chạy trên Supabase)

Thư mục này là **toàn bộ phần dữ liệu và luật tính toán**. App Flutter chỉ gọi vào, không tự tính đối soát.

## Chạy trên Supabase
Mở **SQL Editor** của dự án Supabase, dán và chạy lần lượt (đúng thứ tự, mỗi file một lần):

| File | Làm gì |
|---|---|
| `001_tables.sql` | Tạo bảng và ràng buộc (kể cả chống 2 máy mở/thanh toán trùng 1 bàn) |
| `002_rules.sql` | Bảng sổ kho/nhật ký **chỉ thêm, không sửa/xóa**; tự ghi nhật ký khi đổi giá/công thức; phân quyền chủ/nhân viên |
| `003_actions.sql` | Các thao tác nghiệp vụ app gọi: mở/đóng ca, mở bill, thêm món, thanh toán, hủy bill bằng PIN chủ, nhập kho, đếm mù, hao hụt |
| `004_reconcile.sql` | Hàm `reconcile_shift` (đối soát) và các view tồn dự kiến / còn pha được |
| `005_sim_data.sql` | **Dữ liệu MÔ PHỎNG** 30 ngày có gian lận cài sẵn (chỉ chạy trên database thử, không phải database quán thật) |
| `006_evaluate_simulation.sql` | Đo tỉ lệ phát hiện / báo nhầm trên dữ liệu mô phỏng, dùng cho báo cáo |
| `dev/reset_all.sql` | NGUY HIỂM: xóa sạch dữ liệu để làm lại (dọn dữ liệu mô phỏng) |
| `tests/` | Kiểm thử chạy trên PostgreSQL thường (không dùng trên Supabase) |

## Công thức đối soát (chỉ viết ở database)
- Thực dùng = tồn đầu + nhập − tồn cuối (nhân viên đếm mù)
- Lý thuyết = Σ (số bán × định lượng công thức), ghi vào sổ kho **lúc thanh toán** nên đổi công thức sau này không làm lệch ca cũ
- Chênh lệch = thực dùng − lý thuyết; sau điều chỉnh = chênh lệch − hao hụt có lý do
- Quy ra ly = chênh lệch ÷ (lượng trung bình mỗi ly có nguyên liệu đó); quy ra tiền = số ly × giá bán trung bình (**ước tính**)
- Ngưỡng mặc định (TẠM, phải chỉnh theo quán thật): nguyên liệu `important` vàng ≥ 3%, đỏ ≥ 5%; `normal` vàng ≥ 10%, đỏ ≥ 15%. Mỗi nguyên liệu có thể đặt ngưỡng riêng (`warn_pct`, `alert_pct`).

## App gọi như thế nào
Nhân viên **không ghi trực tiếp** vào bills, kho... mà gọi hàm (Flutter: `supabase.rpc('ten_ham', params: {...})`):

`open_shift`, `close_shift`, `open_bill`, `add_bill_line`, `void_bill_line`, `set_bill_discount`, `pay_bill`, `cancel_open_bill`, `cancel_paid_bill`, `mark_prep_done`, `add_purchase`, `submit_stock_count`, `add_waste`, `set_staff_pin`, và (chỉ chủ) `reconcile_shift`.
Chủ quán được ghi trực tiếp các bảng cấu hình: `ingredients`, `menu_items`, `menu_sizes`, `recipe_lines`, `areas`, `dining_tables`, `staff`.
Bảng `staff` không đọc được cột `pin_hash`: app phải chọn cột cụ thể, không dùng `select *`.

### Mã lỗi trả về (app dịch ra tiếng Việt)
| Mã | Ý nghĩa |
|---|---|
| `NOT_STAFF` / `OWNER_ONLY` | Chưa đăng nhập đúng / chỉ chủ được làm |
| `NO_OPEN_SHIFT` / `SHIFT_ALREADY_OPEN` | Chưa mở ca / ca đang mở rồi |
| `TABLE_HAS_OPEN_BILL` | Bàn đang có bill mở (máy khác vừa mở) |
| `BILL_NOT_OPEN` | Bill đã thanh toán/hủy (máy khác vừa thao tác) |
| `BILL_EMPTY`, `BILL_NOT_PAID` | Bill không có món / bill chưa thanh toán |
| `OPEN_BILLS_REMAIN` | Còn bill mở, chưa đóng ca được |
| `MISSING_CLOSE_COUNTS` | Chưa đếm kho cuối ca đủ nguyên liệu |
| `ONLY_CURRENT_SHIFT` | Chỉ hủy được bill đã thu tiền trong ca hiện tại |
| `REASON_REQUIRED`, `DISCOUNT_INVALID`, `ITEM_UNAVAILABLE`, `PIN_FORMAT`, `TABLE_REQUIRED` | Thiếu lý do / giảm giá sai / món ngừng bán / PIN không phải 4-6 số / thiếu bàn |

`cancel_paid_bill` trả về chữ `OK`, `WRONG_PIN` hoặc `PIN_LOCKED` (không raise lỗi để lần sai PIN vẫn được ghi lại). Sai 3 lần liên tiếp thì khóa 15 phút.

## Lưu ý quan trọng cho cả nhóm
1. **Đếm mù được ép ở database:** nhân viên không đọc được sổ kho, kiểm kê, tồn dự kiến. Màn "Còn pha được" và kết quả đối soát chỉ hiện cho tài khoản chủ.
2. **Chỉ thêm, không sửa:** sổ kho, kiểm kê, nhập, hao hụt, nhật ký bị trigger chặn sửa/xóa kể cả quản trị viên. Chỉ `TRUNCATE` bằng quyền quản trị mới xóa được (dùng cho `dev/reset_all.sql`).
3. **Đăng nhập:** mỗi nhân sự dùng một tài khoản Supabase Auth, ghép với bảng `staff` qua `auth_user_id`. PIN chủ chỉ dùng để xác nhận hủy bill đã thu tiền. Không đưa `service_role` key vào app.
4. **Chỉ một quán:** chưa có bảng `shops`. Muốn bán cho nhiều quán sau này phải thêm `shop_id` vào các bảng và policy.
5. Bản mô phỏng và kết quả đo chỉ chứng minh logic hoạt động trên dữ liệu giả lập; phải chạy thử ở quán thật để chỉnh ngưỡng.

## Chạy kiểm thử trên máy (Postgres thường)
```
createdb fore_test
psql -d fore_test -f tests/00_supabase_stub.sql   # giả lập role/auth của Supabase
psql -d fore_test -f 001_tables.sql -f 002_rules.sql -f 003_actions.sql -f 004_reconcile.sql
psql -d fore_test -f tests/10_reconcile_exercises.sql   # phải in "TẤT CẢ KIỂM THỬ ĐỀU ĐÚNG"
psql -d fore_test -f 005_sim_data.sql -f 006_evaluate_simulation.sql
```
(`tests/10` xóa sạch dữ liệu của database thử trước khi chạy.)
