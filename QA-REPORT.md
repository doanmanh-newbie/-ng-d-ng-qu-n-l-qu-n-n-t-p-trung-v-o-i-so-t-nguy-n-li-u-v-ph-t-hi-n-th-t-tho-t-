# QA-REPORT

Màn | Mục kiểm | Kết quả | Bằng chứng | Ghi chú
--- | --- | --- | --- | ---
1 — Đăng nhập | Đăng nhập nhân viên theo phương thức thử nghiệm đã chốt | Đạt (theo quyết định đã chốt) | `.playwright-mcp/page-2026-10-30T08-37-26-524Z.yml` | Có lựa chọn Số điện thoại / Email; không có ô mật khẩu.
1 — Đăng nhập | Cảnh báo đăng nhập thử nghiệm còn hiện | Đạt (theo quyết định đã chốt) | `.playwright-mcp/page-2026-10-30T08-37-31-888Z.yml` | Giao diện cảnh báo không có mật khẩu hay mã xác nhận và ai biết số/email đều có thể vào tài khoản.
1 — Đăng nhập | Tên đọc được cho mọi nút và ô nhập | Đạt | `.playwright-mcp/page-2026-10-30T08-37-26-524Z.yml` | Snapshot có tên cho các nút Chủ quán, Nhân viên, Số điện thoại, Email, Đăng nhập, Tạo tài khoản nhân viên và ô email.
1 — Đăng nhập | Bỏ trống email rồi bấm Đăng nhập hiển thị lỗi và không vào app | Đạt | `.playwright-mcp/page-2026-10-30T08-37-44-141Z.yml` | Hiện “Nhập email.”; URL vẫn `/#/welcome`.
1 — Đăng nhập | Nhập sai thông tin hiện lỗi, không vào được app | Không kiểm được | `.playwright-mcp/page-2026-10-30T08-37-26-524Z.yml` | Không gửi thông tin đăng nhập giả. `qa-accounts.local.md` không có trong workspace nên không thể kiểm tra luồng với tài khoản QA.
1 — Đăng nhập | Tài khoản chưa được thêm vào quán có thông báo tương ứng | Không kiểm được | `.playwright-mcp/page-2026-10-30T08-37-26-524Z.yml` | Thiếu `qa-accounts.local.md`; chưa có tài khoản test để kiểm tra.
1 — Đăng nhập | Đăng nhập nhân viên không thấy menu chủ | Không kiểm được | `.playwright-mcp/page-2026-10-30T08-37-31-888Z.yml` | Thiếu `qa-accounts.local.md`; chưa thể xác thực tài khoản nhân viên.
1 — Đăng nhập | Bố cục ở 360×800 không tràn/cắt | Đạt | `.playwright-mcp/page-2026-10-30T08-37-44-141Z.yml` | Bounding box nội dung nằm trong viewport: rộng tối đa 351/360 px, cao 675/800 px.
1 — Đăng nhập | Không có lỗi đỏ trong console | Đạt | Kiểm tra console Playwright | 0 lỗi, 0 cảnh báo.
