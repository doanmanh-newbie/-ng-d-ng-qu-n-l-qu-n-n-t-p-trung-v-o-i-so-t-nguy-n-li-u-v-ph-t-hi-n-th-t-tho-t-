# Database của Fore (PostgreSQL chạy trên Supabase)

Thư mục này là **toàn bộ phần dữ liệu và luật tính toán**. App Flutter chỉ gọi vào, không tự tính đối soát.

## Chạy trên Supabase
Mở **SQL Editor** của dự án Supabase, dán và chạy lần lượt (đúng thứ tự, mỗi file một lần):

| File | Làm gì |
|---|---|
| `001_tables.sql` | Tạo bảng và ràng buộc (kể cả chống 2 máy mở/thanh toán trùng 1 bàn); **bảng cấu hình** `app_settings` (mọi con số) và `waste_types` (loại hao hụt) cùng giá trị mặc định |
| `002_rules.sql` | Bảng sổ kho/nhật ký **chỉ thêm, không sửa/xóa**; tự ghi nhật ký khi đổi giá/công thức; phân quyền chủ/nhân viên |
| `003_actions.sql` | Các thao tác nghiệp vụ app gọi: mở/đóng ca, mở bill, thêm món, thanh toán, hủy bill bằng PIN chủ (số lần sai và thời gian khóa lấy từ `app_settings`), nhập kho, đếm mù, hao hụt (chọn loại trong `waste_types`) |
| `004_reconcile.sql` | Hàm `reconcile_shift` (đối soát) và các view tồn dự kiến / còn pha được |
| `005_cash_reconcile.sql` | Đối soát **tiền mặt**: bảng `cash_movements` (2 hướng `in`/`out` + ghi chú), hàm `reconcile_cash` |
| `006_waste_report.sql` | Báo cáo hao hụt cho chủ: `waste_report(ca)` (theo nguyên liệu và loại, % so với lượng dùng lý thuyết, cờ cảnh báo) và view `v_waste_detail` |
| `007_corrections.sql` | Sửa nhập nhầm bằng dòng **điều chỉnh** (dòng gốc vẫn còn), chỉ chủ làm |
| `008_staff_setup.sql` | Tạo chủ đầu tiên, nối tài khoản nhân viên |
| `009_shift_report.sql` | `shift_report(ca)`: MỘT hàm trả khối JSON cho màn hình chủ (nguyên liệu, tiền, hao hụt, thu/chi, cờ, trạng thái chung) + cờ **xu hướng** (nhiều ca liên tiếp lệch cùng chiều) |
| `sim/sim_data.sql` | **Dữ liệu MÔ PHỎNG** 30 ngày có gian lận cài sẵn (chỉ chạy trên database thử, không phải database quán thật) |
| `sim/evaluate_simulation.sql` | Đo tỉ lệ phát hiện / báo nhầm trên dữ liệu mô phỏng, dùng cho báo cáo |
| `sim/evaluate_noise_reduction.sql` | So sánh cách "để ý" cũ (mọi vàng/đỏ) với cách mới (đỏ hoặc có cờ xu hướng) trên dữ liệu mô phỏng |
| `dev/reset_schema.sql` | NGUY HIỂM: xóa sạch toàn bộ bảng/hàm của Fore trong schema `public` để chạy lại từ `001` (CHỈ project Supabase thử) |
| `dev/reset_all.sql` | NGUY HIỂM: xóa sạch dữ liệu để làm lại (dọn dữ liệu mô phỏng) |
| `tests/` | Kiểm thử chạy trên PostgreSQL thường (không dùng trên Supabase) |

## Công thức đối soát (chỉ viết ở database)
- Thực dùng = tồn đầu + nhập − tồn cuối (nhân viên đếm mù)
- Lý thuyết = Σ (số bán × định lượng công thức), ghi vào sổ kho **lúc thanh toán** nên đổi công thức sau này không làm lệch ca cũ
- Chênh lệch = thực dùng − lý thuyết; sau điều chỉnh = chênh lệch − hao hụt có lý do
- Quy ra ly = chênh lệch ÷ (lượng trung bình mỗi ly có nguyên liệu đó); quy ra tiền = số ly × giá bán trung bình (**ước tính**)
- Ngưỡng mặc định (TẠM, phải chỉnh theo quán thật): nguyên liệu `important` vàng ≥ 3%, đỏ ≥ 5%; `normal` vàng ≥ 10%, đỏ ≥ 15%. Mỗi nguyên liệu có thể đặt ngưỡng riêng (`warn_pct`, `alert_pct`).

## Nguyên tắc: công thức nằm trong code, CON SỐ do quán quyết định
Chỉ **nhãn** và **con số** mới nằm trong bảng cấu hình để chủ chỉnh; thứ gì làm đổi **công thức** thì để trong code (sửa bằng file migration mới).

| Chỗ chỉnh | Là gì | Ai sửa |
|---|---|---|
| `app_settings` | Mọi con số: ngưỡng cảnh báo nguyên liệu (quan trọng/thường), ngưỡng hao hụt, ngưỡng lệch tiền mặt, ngưỡng lệch tiền đầu ca, số lần đếm lại, số lần sai PIN, số phút khóa | Chủ (chỉ sửa được `value_int`, không đổi tên khóa, không xóa) |
| `waste_types` | Loại hao hụt (mã `code` không đổi; chủ đổi tên hiển thị, bắt buộc ghi chú hay không, ẩn đi) | Chủ (không xóa, chỉ ẩn) |
| `ingredients.warn_pct / alert_pct` | Ngưỡng riêng của một nguyên liệu (ưu tiên hơn ngưỡng chung) | Chủ |
| `ingredients.min_abs_qty` | Lệch **tuyệt đối** tối thiểu (đơn vị gốc) mới cảnh báo; dưới mức này thì bỏ qua dù % vượt ngưỡng. 0 = tắt | Chủ |

Khóa trong `app_settings`: `important_warn_pct` (3), `important_alert_pct` (5), `normal_warn_pct` (10), `normal_alert_pct` (15), `waste_warn_pct` (10), `cash_warn_vnd` (20000), `cash_alert_vnd` (50000), `opening_diff_warn_vnd` (1000), `recount_flag_after` (2), `pin_max_attempts` (3), `pin_lock_minutes` (15), `streak_shifts` (3: số ca liên tiếp lệch cùng chiều thì gắn cờ xu hướng, tối thiểu 2). **Mọi giá trị mặc định chỉ là số TẠM**, phải chỉnh theo quán thật (xem kết quả mô phỏng bên dưới để thấy ngưỡng ảnh hưởng thế nào).

**Cố ý viết cứng trong code** (đổi là đổi công thức hoặc bảo mật): đơn vị `ml/g/piece`, hướng thu/chi tiền mặt (`in`/`out`), loại sổ kho, vai trò `owner/staff`, loại bill, phương thức thanh toán `cash/transfer`.

## Công thức đối soát tiền mặt (`reconcile_cash`)
- Tiền đáng ra có = tiền đầu ca + tiền mặt từ bill đã thanh toán (không tính chuyển khoản, không tính bill đã hủy) + tiền bỏ thêm vào két − tiền lấy ra khỏi két
- Chênh lệch tiền = tiền đếm cuối ca − tiền đáng ra có (âm = thiếu, dương = thừa)
- Khoản thu/chi chỉ có **2 hướng**: `out` (lấy ra khỏi két: mua đá, trả tiền hàng, chủ rút...) và `in` (bỏ vào két: đổi tiền lẻ, chủ nạp...). Chi tiết nằm trong **ghi chú** người nhập viết. Lấy tiền ra (`out`) thì **ghi chú bắt buộc**; bỏ tiền vào (`in`) thì không bắt buộc. Mỗi khoản có người nhập, giờ nhập, không sửa/xóa được, không cần PIN. Việc ghi cũng không bắt buộc: ca không có thu/chi thì không có dòng nào.
- Chủ đọc danh sách ghi chú (`v_cash_movements`) để biết từng khoản. Báo cáo cũng hiện: tiền đầu ca lệch bao nhiêu so với cuối ca trước, tổng chuyển khoản (để chủ so với loa/app ngân hàng), số bill đã thu rồi hủy.
- **Giới hạn đã biết:** hệ thống không kiểm chứng được sự thật bên ngoài (đá thật tốn bao nhiêu, tiền chuyển khoản có về tài khoản không). Nó chỉ ghi dấu vết và hiện số cho chủ.
- Hai đối soát (nguyên liệu và tiền mặt) bổ sung cho nhau: bán không lên bill chỉ nguyên liệu bắt được; lấy bớt tiền của bill đã ghi chỉ đếm tiền bắt được.

## App gọi như thế nào
Nhân viên **không ghi trực tiếp** vào bills, kho... mà gọi hàm (Flutter: `supabase.rpc('ten_ham', params: {...})`):

`open_shift`, `close_shift`, `open_bill`, `add_bill_line`, `void_bill_line`, `set_bill_discount`, `pay_bill`, `cancel_open_bill`, `cancel_paid_bill`, `mark_prep_done`, `add_purchase`, `submit_stock_count`, `add_waste`, `add_cash_movement`, `set_staff_pin`, và (chỉ chủ) `shift_report` (gom tất cả cho một màn hình), `reconcile_shift`, `reconcile_cash`, `waste_report`, `correct_purchase`, `correct_waste`.
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
| `RECIPE_IN_USE` | Size đã từng bán: không sửa/xóa/thêm dòng công thức. Muốn đổi: ẩn size cũ (`active=false`), tạo size mới |
| `MISSING_CLOSE_COUNTS` | Chưa đếm kho cuối ca đủ nguyên liệu |
| `ONLY_CURRENT_SHIFT` | Chỉ hủy được bill đã thu tiền trong ca hiện tại |
| `WASTE_TYPE_INVALID`, `NOTE_REQUIRED` | Loại hao hụt không có/đã ẩn / thiếu ghi chú (loại hao hụt bắt buộc ghi chú, hoặc lấy tiền ra khỏi két mà chưa ghi chú) |
| `DIRECTION_INVALID`, `AMOUNT_INVALID` | Hướng thu/chi không phải `in`/`out` / số tiền không dương |
| `REASON_REQUIRED`, `DISCOUNT_INVALID`, `ITEM_UNAVAILABLE`, `PIN_FORMAT`, `TABLE_REQUIRED` | Thiếu lý do / giảm giá sai / món ngừng bán / PIN không phải 4-6 số / thiếu bàn |

`cancel_paid_bill` trả về chữ `OK`, `WRONG_PIN` hoặc `PIN_LOCKED` (không raise lỗi để lần sai PIN vẫn được ghi lại). Sai 3 lần liên tiếp thì khóa 15 phút.

## Kết quả mô phỏng (số đo thật, tái lập được)
Bộ `sim/` mô phỏng 30 ngày (ngày bắt đầu **cố định**, nên chạy lại cho đúng cùng kết quả) với gian lận cài sẵn: bán không lên bill (A: 12 ly/ngày × 5 ngày; D: 3 ly/ngày × 2 ngày), rót dư sữa +20% (B: 3 ngày), lấy trộm 3 kg trân châu (C: 1 ngày). Có 19 ca sạch để đo báo nhầm. Chỉ xét **nguyên liệu**.

**Bảng 1: ảnh hưởng của ngưỡng** (nguyên liệu quan trọng, cách cũ: ca bị báo nếu có nguyên liệu vàng hoặc đỏ)

| Ngưỡng vàng/đỏ | Gian lận lớn (A, B, C: 9 ca) | Gian lận nhỏ (D: 2 ca) | Ca sạch bị báo nhầm (19 ca) |
|---|---|---|---|
| 3% / 5% (mặc định) | 9/9 (đều đỏ) | 2/2 vàng | 3 (15,8%), 0 đỏ |
| 4% / 6% | 9/9 (đều đỏ) | 0/2 | 0 |
| 5% / 8% | 9/9 (đều đỏ) | 0/2 | 0 |

**Bảng 2: cách "để ý" mới** (đỏ, hoặc có cờ xu hướng; vàng lẻ bỏ qua), ngưỡng 3% / 5%, `streak_shifts` = 3

| | Gian lận lớn | Gian lận nhỏ (D) | Ca sạch báo nhầm |
|---|---|---|---|
| Cách cũ (mọi vàng/đỏ) | 9/9 | 2/2 | 3/19 |
| Cách mới | 9/9 | 0/2 | 0/19 |

**Đọc kết quả cho đúng (đừng nói quá):**
- Gian lận **lớn** luôn bị bắt ở mọi ngưỡng thử.
- Gian lận **nhỏ** (3 ly/ngày, khoảng 1,4% lượng bán) nằm **trong mức nhiễu** của mô phỏng. Ở ngưỡng 3%/5% nó "bị bắt" nhờ vàng ngẫu nhiên (hai ngày vàng ở hai nguyên liệu khác nhau, Trà rồi Trân châu), không phải nhờ phát hiện đúng bản chất; ngưỡng cao hơn thì bỏ sót cả hai.
- Cách mới giảm báo nhầm 3 → 0, nhưng ở dữ liệu này **ngưỡng 4%/6% cũng cho kết quả tương tự**. Cờ xu hướng chưa chứng minh được lợi ích riêng ở đây, vì không ca sạch nào có nhiều ca liên tiếp cùng chiều cùng nguyên liệu, và gian lận nhỏ chỉ kéo dài 2 ngày. Cơ chế được kiểm tra bằng `tests/40` (đúng logic), nhưng hiệu quả ngoài thực tế phải đo ở quán thật.
- `min_abs_qty` đặt bằng lượng 2 ly **không đổi kết quả** ở dữ liệu này (các ca bị báo nhầm đều lệch lớn hơn 2 ly).
- Không có ngưỡng "đúng" chung: ngưỡng thấp bắt được nhiều hơn nhưng báo nhầm nhiều hơn. Vì vậy mọi ngưỡng nằm trong `app_settings` để chỉnh theo quán.
- **Giới hạn đã biết:** gian lận nhỏ nhưng kéo dài nhiều ngày khó thấy theo từng ca. Hướng cải tiến sau: gộp độ lệch theo tuần; thêm kịch bản gian lận nhỏ kéo dài vào mô phỏng để đo cờ xu hướng.
- Dữ liệu là giả lập: chỉ chứng minh logic, không chứng minh độ chính xác ngoài thực tế.

## Giới hạn thiết kế đã biết (chủ động chọn)

- **Một quán = một dự án Supabase (single-tenant).** Không có cột `shop_id`; ngay cả `one_open_shift` (chỉ một ca mở) cũng ngầm hiểu một quán. Bán cho nhiều quán: mỗi quán một dự án, chạy cùng bộ SQL. Chỉ khi có hàng chục quán mới cần đa quán trong một database (thêm `shop_id` vào ~15 bảng và viết lại RLS).
- **Công thức đã bán thì khóa** (`RECIPE_IN_USE`) để số ly và tiền ước tính của ca cũ không bị đổi. Số lý thuyết đối soát vốn đã cố định trong sổ kho lúc thanh toán.
- **Đóng ca / mở bill có khóa dòng ca**: `close_shift` khóa `FOR UPDATE`, `open_bill` khóa `FOR SHARE` và kiểm tra lại ca còn mở, nên không còn bill mở nằm trong ca đã đóng (có test `51_concurrency.sh`, bản cũ không khóa làm test này báo SAI).
- **PIN chủ băm bằng bcrypt trong database** (`crypt`): chỉ chạy khi hủy bill đã thanh toán hoặc đặt PIN (vài lần mỗi ca), không phải mỗi lần đăng nhập (đăng nhập dùng Supabase Auth), nên không gây nghẽn. Khóa sau 3 lần sai trong 15 phút (cấu hình được).
- `shift_report` gọi `reconcile_shift` khoảng 3 lần (ca đang xem + tối đa `streak_shifts − 1` ca trước), không tăng theo số ca của quán.

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
psql -d fore_test -f 001_tables.sql -f 002_rules.sql -f 003_actions.sql -f 004_reconcile.sql \
                   -f 005_cash_reconcile.sql -f 006_waste_report.sql -f 007_corrections.sql -f 008_staff_setup.sql -f 009_shift_report.sql
psql -d fore_test -f tests/10_reconcile_exercises.sql   # đối soát nguyên liệu: phải in "TẤT CẢ KIỂM THỬ ĐỀU ĐÚNG"
psql -d fore_test -f tests/20_cash_exercises.sql        # đối soát tiền mặt: phải in "TIEN MAT: TAT CA DEU DUNG"
psql -d fore_test -f tests/30_config_waste_exercises.sql # cấu hình + hao hụt: phải in "CAU HINH + HAO HUT: TAT CA DEU DUNG"
psql -d fore_test -f tests/40_shift_report_exercises.sql # shift_report + cờ xu hướng: phải in "SHIFT REPORT: TAT CA DEU DUNG"
psql -d fore_test -f tests/50_hardening_exercises.sql    # chặn sửa công thức đã bán + đóng/mở ca: phải in "HARDENING: TAT CA DEU DUNG"
bash tests/51_concurrency.sh                              # 2 phiên song song: mở bill lúc đóng ca: phải in "CONCURRENCY: DUNG"
psql -d fore_test -f sim/sim_data.sql -f sim/evaluate_simulation.sql -f sim/evaluate_noise_reduction.sql
```
(`tests/10`, `20`, `30`, `40` xóa sạch dữ liệu của database thử trước khi chạy. Không chạy trên Supabase.)
