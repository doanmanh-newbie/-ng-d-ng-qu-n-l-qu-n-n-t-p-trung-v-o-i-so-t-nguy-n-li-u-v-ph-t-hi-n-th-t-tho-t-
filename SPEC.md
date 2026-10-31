> **Ghi chú cho AI lập trình:** file này gốc là đặc tả cho người vẽ Figma. Khi code, hãy đọc kỹ các mục *Hiện gì, Không được hiện, Thao tác, Lỗi*, phần **Quy tắc ảnh hưởng trực tiếp đến thiết kế**, bảng **Thông báo lỗi** và phần **Dành cho người viết code** (ánh xạ màn hình ↔ hàm database). Các câu nhắc "người vẽ Figma" bỏ qua được. Mã SQL thật nằm trong thư mục `database/` (file 003 đến 009).

> **Trạng thái repo:** đây là đặc tả yêu cầu sản phẩm, không phải backlog cho một app chưa được tạo. Repo hiện là ứng dụng Flutter/Dart đã có mã nguồn trong `lib/`, dùng `supabase_flutter` và `provider`; hãy kiểm tra `pubspec.yaml` và test trước khi kết luận một tính năng chưa có. Không tự thêm Riverpod, Go Router hay thay stack. Một số luồng đăng nhập nhân viên trong code được ghi rõ là demo/thử nghiệm; không xem chúng là xác thực production. Nếu đặc tả này và code khác nhau, ghi nhận sai lệch, thêm test/việc vào TODO, không tự suy đoán thay đổi database.

# Fore – Đặc tả màn hình cho Figma

Oct 18, 2026 · @mạnh

## Đọc tài liệu này như thế nào

Tài liệu này cho người vẽ Figma biết mỗi màn hình của Fore dùng để làm gì, ai dùng, hiện gì và có thao tác nào, để vẽ đúng mà không cần đọc database.

Fore là app Android cho quán nước nhỏ. Nó ghi bán hàng và bàn, nhưng việc chính là **đối soát nguyên liệu và tiền mặt** để chủ quán phát hiện thất thoát: pha dư, đổ bỏ, bán không lên bill, thiếu tiền. App chỉ **cảnh báo, không kết luận ai gian lận và không chặn thao tác**.

Có hai loại người dùng: **nhân viên** (bán hàng, đếm kho, đóng ca) và **chủ quán** (xem báo cáo, sửa thực đơn và cài đặt). Mỗi màn hình dưới đây ghi rõ ai dùng. Người vẽ Figma chỉ cần đọc các mục *Ai dùng, Mục đích, Hiện gì, Không được hiện, Thao tác, Lỗi*; mục *Dành cho người viết code* bỏ qua được.

## Một ca làm việc, kể từ đầu đến cuối

Một ca là một vòng khép kín: mở ca, bán hàng, đếm kho, đóng ca, rồi chủ xem kết quả. Tất cả màn hình bên dưới nằm trên vòng này. Tại một thời điểm chỉ có **một ca đang mở** cho cả quán.

- **Nhân viên đăng nhập và mở ca.** Nhập số tiền có trong két lúc bắt đầu, rồi đếm kho đầu ca.

- **Bán hàng.** Chọn bàn (hoặc đơn mang đi), gọi món, thanh toán tiền mặt hoặc chuyển khoản. Mỗi bàn tối đa một bill đang mở.

- **Việc phát sinh trong ca.** Nhập hàng về, ghi đổ bỏ hoặc cho nhân viên, thu hay chi tiền mặt ngoài bán hàng (ví dụ mua đá).

- **Đếm kho cuối ca.** Nhân viên đo và nhập số thực tế còn lại. **App không được cho họ thấy số dự kiến.**

- **Đóng ca.** Nhập số tiền đếm được trong két. Chỉ đóng được khi hết bill đang mở và đã đếm đủ nguyên liệu.

- **Chủ quán xem báo cáo ca.** App so sánh nguyên liệu dùng thực tế với lượng lẽ ra phải dùng theo số ly đã bán, và so sánh tiền trong két với tiền đáng ra có. Lệch quá ngưỡng thì đánh dấu vàng hoặc đỏ.

## Quy tắc ảnh hưởng trực tiếp đến thiết kế

Có bảy quy tắc mà người vẽ Figma không thể tự đoán, và vẽ sai một trong số này thì app mất tác dụng.

- **Đếm mù.** Màn kiểm kê tuyệt đối không hiện số dự kiến, số tồn của hệ thống hay số đếm lần trước. Nếu hiện, nhân viên chỉ việc gõ lại đúng số đó và app hết tác dụng. Nhân viên cũng không có màn nào xem tồn kho.

- **Chỉ cảnh báo, không chặn.** Nhân viên không bao giờ bị chặn thao tác vì số liệu lệch. Cảnh báo chỉ hiện ở màn của chủ. Dùng chữ "lệch", "cần kiểm tra", không dùng chữ "gian lận" hay "trộm".

- **Màu kèm chữ.** Xanh là trong ngưỡng, vàng là cần chú ý, đỏ là lệch nhiều. Luôn kèm chữ hoặc biểu tượng, không chỉ dùng màu.

- **Không có nút "xóa" cho dữ liệu đã ghi.** Hủy bill, bỏ một dòng, giảm giá, đều là thao tác có lý do và được lưu nhật ký. Muốn sửa nhập nhầm thì chủ "ghi điều chỉnh", dòng cũ vẫn còn.

- **Lý do bắt buộc** ở các chỗ trong bảng dưới; ô lý do phải đánh dấu bắt buộc và nút xác nhận khóa cho đến khi điền.

- **Số nguyên, đơn vị gốc.** Nguyên liệu tính bằng ml, g hoặc cái, không có số thập phân. Trân châu tính bằng gam khô. Tiền là đồng, số nguyên, hiển thị kiểu 29.000đ.

- **Hai máy cùng thao tác.** Nếu bàn vừa có bill hoặc bill vừa được máy khác thanh toán, hiện thông báo rõ ràng và làm mới màn hình, không để người dùng bấm lại.

| Thao tác | Ghi chú/lý do |
| --- | --- |
| Bỏ một dòng món khỏi bill | Bắt buộc |
| Giảm giá lớn hơn 0 | Bắt buộc |
| Hủy bill (chưa hay đã thanh toán) | Bắt buộc |
| Ghi hao hụt loại "khác" | Bắt buộc, từ 5 ký tự |
| Chi tiền mặt ra | Bắt buộc, từ 3 ký tự |
| Thu tiền mặt vào, ghi hao hụt loại có sẵn | Không bắt buộc |

## Màn hình của nhân viên

Chủ quán cũng dùng được mọi màn dưới đây. Mỗi màn là một bảng 2 cột để vẽ theo.

### 1. Đăng nhập

> Giai đoạn thử nghiệm: chủ quán đăng nhập bằng email và mật khẩu. Nhân viên đăng nhập/đăng ký bằng số điện thoại hoặc email, không mật khẩu và không mã xác nhận; đây là luồng thử nghiệm, chưa phải xác thực an toàn cho môi trường production.

| Mục | Nội dung |
| --- | --- |
| Ai dùng | Nhân viên và chủ |
| Mục đích | Vào app bằng tài khoản email và mật khẩu |
| Hiện gì | Ô email, ô mật khẩu, nút Đăng nhập. Khi quán chưa có chủ: thêm nút "Tạo quán (tôi là chủ)" và ô họ tên |
| Thao tác | Đăng nhập; người đầu tiên tạo quán và trở thành chủ |
| Lỗi | Tài khoản chưa được chủ thêm vào quán; quán đã có chủ |
| Lưu ý | PIN không dùng để đăng nhập. PIN chỉ để chủ xác nhận hủy bill đã thu tiền (màn 7) |

### 2. Mở ca

| Mục | Nội dung |
| --- | --- |
| Ai dùng | Nhân viên và chủ |
| Mục đích | Bắt đầu ca, ghi tiền có trong két lúc bắt đầu |
| Hiện gì | Ô "Tiền đầu ca" (đồng), nút Mở ca. Mở xong chuyển sang kiểm kê đầu ca (màn 9) |
| Không được hiện | Số tiền đóng ca của ca trước |
| Lỗi | Đã có ca đang mở: đổi nút thành "Vào ca đang mở" |

### 3. Sơ đồ bàn

| Mục | Nội dung |
| --- | --- |
| Ai dùng | Nhân viên và chủ |
| Mục đích | Chọn bàn để gọi món, thấy bàn nào đang có khách |
| Hiện gì | Lưới bàn chia theo khu; mỗi bàn có trạng thái Trống hoặc Đang dùng (khác màu, có chữ); nút "Mang đi"; ca đang mở |
| Thao tác | Chạm bàn trống → nhập số khách (không bắt buộc) → mở bill. Chạm bàn đang dùng → vào bill đang mở |
| Lỗi | Chưa mở ca: hiện thông báo kèm nút Mở ca, không cho gọi món. Bàn vừa có bill từ máy khác |

### 4. Bill và gọi món

| Mục | Nội dung |
| --- | --- |
| Ai dùng | Nhân viên và chủ |
| Mục đích | Gọi món cho một bàn hoặc một đơn mang đi |
| Hiện gì | Thực đơn theo món và size kèm giá; danh sách dòng đã gọi (số lượng, đơn giá, thành tiền); giảm giá; tổng |
| Không được hiện | Công thức và nguyên liệu của món |
| Thao tác | Thêm món và số lượng; bỏ một dòng (cần lý do); giảm giá (số tiền + lý do); hủy bill chưa thanh toán (cần lý do); sang Thanh toán |
| Lỗi | Món ngừng bán; bill đã đóng; thiếu lý do; giảm giá lớn hơn tổng tiền |

### 5. Thanh toán

| Mục | Nội dung |
| --- | --- |
| Ai dùng | Nhân viên và chủ |
| Mục đích | Thu tiền và chốt bill |
| Hiện gì | Tổng tiền, giảm giá, số tiền phải thu; hai lựa chọn Tiền mặt / Chuyển khoản |
| Thao tác | Chọn cách trả, xác nhận |
| Lỗi | Bill trống; bill đã được thanh toán hoặc hủy từ máy khác |
| Lưu ý | Thanh toán xong không sửa được. Muốn hủy phải qua màn 7 |

### 6. Đơn mang đi và đơn chưa xong

| Mục | Nội dung |
| --- | --- |
| Ai dùng | Nhân viên và chủ |
| Mục đích | Theo dõi đơn mang đi nào đang đợi pha |
| Hiện gì | Danh sách đơn mang đi chưa xong, cũ nhất lên trên: số bill, giờ vào, các món |
| Thao tác | Tạo đơn mang đi (giống màn 4 nhưng không chọn bàn); nút "Xong" trên từng đơn, bấm xong thì đơn biến mất khỏi danh sách |
| Không làm | Không bắt nhập tên hay số điện thoại khách |

### 7. Hủy bill đã thu tiền

| Mục | Nội dung |
| --- | --- |
| Ai dùng | Nhân viên đưa máy cho chủ; chủ tự nhập PIN tại quầy |
| Mục đích | Hủy một bill đã thanh toán, chỉ trong ca đang mở |
| Hiện gì | Tóm tắt bill, ô lý do (bắt buộc), ô PIN chủ (4 đến 6 số, ẩn ký tự) |
| Kết quả bình thường | Đúng PIN: "Đã hủy bill". Sai PIN: "Sai PIN", cho nhập lại. Bị khóa: "PIN bị khóa tạm thời, thử lại sau" (mặc định sai 3 lần khóa 15 phút, chủ chỉnh được) |
| Lỗi | Bill chưa thanh toán; bill của ca cũ; thiếu lý do |

### 8. Nhập hàng

| Mục | Nội dung |
| --- | --- |
| Ai dùng | Nhân viên và chủ |
| Mục đích | Ghi nguyên liệu vừa nhập về trong ca |
| Hiện gì | Danh sách nguyên liệu để chọn; ô số lượng theo đơn vị gốc (ví dụ chai 1 lít nhập 1000 ml); ô tick "Nhập muộn"; ô ghi chú |
| Không được hiện | Lịch sử nhập và số tồn (chỉ chủ xem) |
| Thao tác | Lưu phiếu. Nhập nhầm thì nhờ chủ sửa; không có nút sửa hay xóa ở đây |
| Lỗi | Chưa mở ca |

### 9. Kiểm kê đầu ca và cuối ca (đếm mù)

| Mục | Nội dung |
| --- | --- |
| Ai dùng | Nhân viên và chủ |
| Mục đích | Nhập số đo thực tế của từng nguyên liệu lúc đầu ca và lúc cuối ca |
| Hiện gì | Tiêu đề rõ "Đầu ca" hoặc "Cuối ca". Danh sách nguyên liệu, loại quan trọng chữ đậm và đứng đầu. Mỗi dòng một ô nhập số và đơn vị. Chai hay túi mở dở: nhập thẳng số còn lại |
| **Không được hiện** | **Số dự kiến, số tồn của hệ thống, số đếm lần trước. Không hiện đúng/sai sau khi nhập** |
| Thao tác | Nhập số từng dòng và lưu. Đếm sai thì đếm lại, số lưu sau cùng được dùng |
| Lưu ý | Nguyên liệu chỉ kiểm theo tuần (đường, muối) không bắt buộc đếm lúc cuối ca |
| Lỗi | Chưa mở ca |

### 10. Ghi hao hụt

| Mục | Nội dung |
| --- | --- |
| Ai dùng | Nhân viên và chủ |
| Mục đích | Ghi nguyên liệu bị mất có lý do (đổ, làm sai, cho nhân viên, thử vị) để đối soát không tính nhầm |
| Hiện gì | Chọn nguyên liệu; ô số lượng (đơn vị gốc; trân châu tính gam khô); **chọn loại từ danh sách**, không gõ tự do; ô ghi chú |
| Danh sách loại mặc định | Đổ bỏ (quá giờ/hết hạn); Làm sai, đổ ly; Cho nhân viên dùng; Thử vị; Khác (ghi chú rõ). Chủ thêm bớt được, nên danh sách phải lấy từ app, không vẽ cứng |
| Lỗi | Loại "Khác" mà ghi chú dưới 5 ký tự; chưa mở ca |

### 11. Thu và chi tiền mặt ngoài bán hàng

| Mục | Nội dung |
| --- | --- |
| Ai dùng | Nhân viên và chủ |
| Mục đích | Ghi tiền bỏ thêm vào két hoặc lấy ra (mua đá, chủ rút tiền) để đối soát tiền đúng |
| Hiện gì | Hai lựa chọn Thu vào / Chi ra; ô số tiền; ô ghi chú |
| Quy tắc | Chi ra thì ghi chú bắt buộc (từ 3 ký tự). Thu vào thì không bắt buộc. Không cần PIN. Không phân loại chi tiết, chủ tự đọc ghi chú |
| Lỗi | Chưa ghi chú khi chi ra; số tiền không hợp lệ; chưa mở ca |

### 12. Đóng ca

| Mục | Nội dung |
| --- | --- |
| Ai dùng | Nhân viên và chủ |
| Mục đích | Kết thúc ca, ghi số tiền đếm được trong két |
| Hiện gì | Ô "Tiền đếm được" (đồng); danh sách việc còn thiếu nếu có (bill đang mở, nguyên liệu chưa đếm) |
| Không được hiện | Số tiền đáng ra có trong két, kết quả đối soát, doanh thu tổng. Sau khi đóng chỉ hiện "Đã đóng ca" |
| Thao tác | Nhập tiền đếm được, xác nhận đóng ca |
| Lỗi | Còn bill đang mở; chưa đếm đủ nguyên liệu cuối ca; máy khác vừa đóng ca |

## Màn hình của chủ quán

Chỉ chủ mới thấy các màn dưới đây (nhân viên đăng nhập thì menu không có các mục này). Màn quan trọng nhất là **Báo cáo ca**, vì đó là nơi chủ nhìn ra thất thoát.

### 13. Báo cáo ca

| Mục | Nội dung |
| --- | --- |
| Ai dùng | Chủ |
| Mục đích | Xem một ca có bất thường không, và bất thường ở đâu |
| Nguyên tắc vẽ | Đầu màn là kết luận một dòng (Xanh, Vàng, Đỏ), bên dưới mới đến chi tiết. Chủ phải biết được trong 3 giây ca này có cần xem kỹ không |
| Khối 1: Tổng quan | Trạng thái chung; số nguyên liệu đỏ, số nguyên liệu vàng; số nguyên liệu có cờ xu hướng; trạng thái tiền mặt; số cảnh báo hao hụt |
| Khối 2: Nguyên liệu | Mỗi nguyên liệu một dòng: tên, tồn đầu, nhập, tồn cuối, thực dùng, lý thuyết, chênh lệch (con số và %), hao hụt có lý do, chênh lệch sau điều chỉnh, quy ra số ly, ước tiền, trạng thái màu + chữ, cờ xu hướng. Loại quan trọng đứng trên, chữ đậm |
| Khối 3: Tiền mặt | Tiền đầu ca, bán tiền mặt, bán chuyển khoản, thu vào, chi ra, **đáng ra có**, tiền đếm được, chênh lệch, số bill hủy sau khi đã thu tiền (kèm số tiền), chênh lệch tiền đầu ca so với đóng ca trước |
| Khối 4: Hao hụt | Theo từng nguyên liệu và từng loại (đổ, cho nhân viên...), có cờ vàng khi hao hụt quá ngưỡng |
| Khối 5: Thu chi | Danh sách các khoản thu chi tiền mặt: giờ, thu hay chi, số tiền, ghi chú, người nhập |
| Khối 6: Nhắc việc | Thông báo nhỏ nếu có món bán mà chưa có công thức (khi đó đối soát bị thiếu) |
| Điều cần vẽ rõ | "Quy ra ly" và "ước tiền" chỉ là ước tính, ghi nhãn ước tính. Không cộng ước tiền của nhiều nguyên liệu lại thành một tổng (sẽ đếm trùng). Chênh lệch dương nghĩa là dùng nhiều hơn lý thuyết, âm là dùng ít hơn |
| Cờ xu hướng | Hiện khi một nguyên liệu lệch cùng chiều nhiều ca liên tiếp (mặc định 3 ca). Ghi số ca, ví dụ "3 ca liên tiếp lệch dương" |
| Lỗi | Ca không tồn tại; không phải chủ |

### 14. Danh sách ca

| Mục | Nội dung |
| --- | --- |
| Ai dùng | Chủ |
| Mục đích | Chọn ca để xem báo cáo |
| Hiện gì | Mỗi dòng một ca: ngày, giờ mở và đóng, người mở, trạng thái chung (Xanh, Vàng, Đỏ) để chủ lướt thấy ca nào cần xem |
| Thao tác | Chạm một ca để mở Báo cáo ca (màn 13) |

### 15. Nguyên liệu

| Mục | Nội dung |
| --- | --- |
| Ai dùng | Chủ |
| Mục đích | Quản lý danh mục nguyên liệu |
| Hiện gì | Danh sách nguyên liệu (tên, đơn vị, mức quan trọng, đang dùng hay đã ẩn) |
| Thông tin một nguyên liệu | Tên; đơn vị gốc chọn một trong ml, g, cái; mức quan trọng (Quan trọng hay Thường); chỉ kiểm theo tuần (có hay không); ngưỡng lệch riêng (để trống thì dùng mặc định); lệch tối thiểu để cảnh báo (đơn vị gốc, 0 là tắt) |
| Thao tác | Thêm, sửa, ẩn. Không có nút xóa |
| Lỗi | Tên trùng |

### 16. Thực đơn và công thức

| Mục | Nội dung |
| --- | --- |
| Ai dùng | Chủ |
| Mục đích | Tạo món, size, giá bán và công thức (mỗi size một công thức riêng) |
| Hiện gì | Danh sách món; mỗi món có các size và giá; mỗi size có các dòng công thức (nguyên liệu và định lượng); nhắc nếu size chưa có công thức |
| Thao tác | Thêm món, thêm size, đặt giá, thêm dòng công thức (chọn nguyên liệu từ danh sách, gõ tên thì gợi ý), sao chép công thức từ size khác, ẩn món hay size |
| **Quy tắc** | **Size đã từng bán thì công thức bị khóa** (không sửa, không xóa, không thêm dòng). Hiện rõ "Size này đã bán, không sửa được công thức. Hãy ẩn size và tạo size mới". Có nút "Tạo size mới từ size này" để sao chép |
| Lỗi | Sửa công thức của size đã bán; trùng tên size trong cùng món |

### 17. Khu và bàn

| Mục | Nội dung |
| --- | --- |
| Ai dùng | Chủ |
| Mục đích | Tự tạo sơ đồ quán: các khu (tầng 1, sân...) và bàn trong mỗi khu |
| Thao tác | Thêm, đổi tên, ẩn khu hay bàn. Không có kéo thả sơ đồ (ngoài phạm vi) |
| Lỗi | Tên khu trùng |

### 18. Sửa nhập nhầm (nhập hàng, hao hụt)

| Mục | Nội dung |
| --- | --- |
| Ai dùng | Chủ |
| Mục đích | Sửa số lượng một phiếu nhập hoặc một dòng hao hụt do nhân viên nhập nhầm |
| Hiện gì | Danh sách phiếu nhập và dòng hao hụt theo ca (người nhập, giờ, số lượng gốc, số lượng hiệu lực sau điều chỉnh, đã điều chỉnh mấy lần) |
| Thao tác | Chọn một dòng, nhập số lượng mới và lý do (bắt buộc). Dòng gốc vẫn còn, đây là dòng "điều chỉnh" |
| Lỗi | Thiếu lý do; số lượng không hợp lệ hoặc không đổi; không tìm thấy dòng |

### 19. Nhân viên

| Mục | Nội dung |
| --- | --- |
| Ai dùng | Chủ |
| Mục đích | Thêm người vào quán và đặt PIN cho chủ |
| Hiện gì | Danh sách nhân viên (tên, vai trò Chủ hay Nhân viên, đã đặt PIN chưa, đang làm hay đã ẩn) |
| Thao tác | Thêm người: nhập email tài khoản đã đăng ký, họ tên, vai trò. Đặt PIN 4 đến 6 số. Ẩn nhân viên nghỉ việc |
| Lỗi | Email chưa đăng ký tài khoản; người này đã là nhân viên; PIN sai định dạng; không được bỏ chủ cuối cùng |

### 20. Cài đặt ngưỡng và loại hao hụt

| Mục | Nội dung |
| --- | --- |
| Ai dùng | Chủ |
| Mục đích | Chỉnh các con số cảnh báo và danh sách loại hao hụt. Công thức đối soát không nằm ở đây, chủ chỉ chỉnh được con số |
| Thao tác | Sửa từng con số (bảng dưới). Thêm, đổi tên, ẩn loại hao hụt; đánh dấu loại nào bắt buộc ghi chú |

| Tên hiển thị | Mặc định | Đơn vị |
| --- | --- | --- |
| Nguyên liệu quan trọng: vàng khi lệch từ | 3 | % |
| Nguyên liệu quan trọng: đỏ khi lệch từ | 5 | % |
| Nguyên liệu thường: vàng khi lệch từ | 10 | % |
| Nguyên liệu thường: đỏ khi lệch từ | 15 | % |
| Hao hụt: cảnh báo khi vượt | 10 | % lượng lý thuyết |
| Tiền mặt: vàng khi lệch từ | 20.000 | đồng |
| Tiền mặt: đỏ khi lệch từ | 50.000 | đồng |
| Tiền đầu ca lệch so với đóng ca trước: cảnh báo từ | 1.000 | đồng |
| Đếm lại từ bao nhiêu lần thì đánh dấu | 2 | lần |
| Số ca liên tiếp lệch cùng chiều thì gắn cờ xu hướng (tối thiểu 2) | 3 | ca |
| Nhập sai PIN tối đa trước khi khóa | 3 | lần |
| Thời gian khóa PIN | 15 | phút |

### 21. Nhật ký thao tác

| Mục | Nội dung |
| --- | --- |
| Ai dùng | Chủ |
| Mục đích | Xem ai đã làm gì nhạy cảm (hủy bill, giảm giá, điều chỉnh, đổi cài đặt) |
| Hiện gì | Danh sách theo thời gian: giờ, người làm, việc gì, chi tiết ngắn (lý do, số tiền) |
| Thao tác | Lọc theo ngày và loại. Chỉ xem, không sửa hay xóa được |

## Thông báo lỗi hiển thị cho người dùng

Khi một thao tác bị từ chối, database trả về một mã chữ in hoa. App đổi mã đó thành câu tiếng Việt ngắn dưới đây. Người vẽ Figma dùng các câu này cho hộp thông báo; với lỗi do máy khác gây ra (như bàn đã có bill), màn hình tự làm mới sau khi hiện thông báo.

| Mã lỗi | Câu hiển thị |
| --- | --- |
| NOT_LOGGED_IN | Bạn chưa đăng nhập. Hãy đăng nhập lại. |
| NOT_STAFF | Tài khoản này chưa được thêm vào quán. Hãy nhờ chủ quán thêm. |
| OWNER_ONLY | Chỉ chủ quán mới làm được việc này. |
| NO_OPEN_SHIFT | Chưa có ca đang mở (hoặc ca vừa được đóng ở máy khác). Hãy mở ca trước. |
| SHIFT_ALREADY_OPEN | Đang có một ca mở rồi. Hãy vào ca đó để tiếp tục. |
| TABLE_REQUIRED | Hãy chọn bàn cho đơn ăn tại quán. |
| TABLE_HAS_OPEN_BILL | Bàn này vừa có bill mở từ máy khác. Đang tải lại. |
| BILL_NOT_OPEN | Bill này đã được thanh toán hoặc hủy. Đang tải lại. |
| BILL_EMPTY | Bill chưa có món nào. |
| ITEM_UNAVAILABLE | Món này đã ngừng bán. |
| REASON_REQUIRED | Hãy nhập lý do. |
| DISCOUNT_INVALID | Giảm giá không được âm và không được lớn hơn tổng tiền. |
| BILL_NOT_PAID | Bill này chưa thanh toán nên không dùng được chức năng này. |
| ONLY_CURRENT_SHIFT | Chỉ hủy được bill của ca đang mở. |
| OPEN_BILLS_REMAIN | Còn bill đang mở. Hãy thanh toán hoặc hủy hết rồi đóng ca. |
| MISSING_CLOSE_COUNTS | Chưa đếm hết nguyên liệu cuối ca. |
| WASTE_TYPE_INVALID | Loại hao hụt không hợp lệ. Hãy chọn từ danh sách. |
| NOTE_REQUIRED | Hãy ghi chú. Hao hụt loại Khác: từ 5 ký tự. Chi tiền mặt: từ 3 ký tự. |
| DIRECTION_INVALID | Hãy chọn Thu vào hoặc Chi ra. |
| AMOUNT_INVALID | Số tiền phải lớn hơn 0. |
| QTY_INVALID | Số lượng không hợp lệ. |
| NO_CHANGE | Số lượng mới giống số cũ, không có gì để sửa. |
| NOT_FOUND | Không tìm thấy dữ liệu này. |
| RECIPE_IN_USE | Size này đã bán nên không sửa được công thức. Hãy ẩn size và tạo size mới. |
| PIN_FORMAT | PIN gồm 4 đến 6 chữ số. |
| NAME_REQUIRED | Hãy nhập họ tên. |
| OWNER_EXISTS | Quán đã có chủ. |
| ALREADY_STAFF | Tài khoản này đã được thêm vào quán. |
| USER_NOT_FOUND | Chưa có tài khoản với email này. Người đó cần đăng ký trước. |
| ROLE_INVALID | Vai trò không hợp lệ. |
| LAST_OWNER | Không thể bỏ hoặc hạ quyền chủ cuối cùng. |
| WRONG_PIN (kết quả, không phải lỗi) | Sai PIN. Hãy nhập lại. |
| PIN_LOCKED (kết quả, không phải lỗi) | PIN bị khóa tạm thời do nhập sai nhiều lần. Thử lại sau. |

Một lỗi không có trong bảng (mất mạng, lỗi lạ) hiện câu chung "Có lỗi, hãy thử lại" và ghi lại mã để nhóm sửa. Trùng tên khi thêm nguyên liệu hay khu là lỗi dữ liệu riêng (không có mã chữ), app hiện "Tên này đã có".

## Dành cho người viết code: màn hình nối với database

Người vẽ Figma bỏ qua phần này. "Gọi hàm" là supabase.rpc('tên_hàm', params: {...}); "Đọc bảng" là supabase.from('tên_bảng').select(). Quyền đọc ghi được RLS kiểm tra ở database, nên app chỉ cần ẩn màn chủ với nhân viên cho đẹp, không phải để bảo mật.

| Màn | Gọi hàm | Đọc bảng |
| --- | --- | --- |
| 1. Đăng nhập | auth.signInWithPassword; my_profile(); claim_first_owner(p_full_name) |  |
| 2. Mở ca | open_shift(p_opening_cash) | shifts |
| 3. Sơ đồ bàn | open_bill(p_table, p_type, p_guests), p_type là dine_in hoặc take_away | areas, dining_tables, bills (status = open) |
| 4. Bill và gọi món | add_bill_line(p_bill, p_size, p_qty); void_bill_line(p_line, p_reason); set_bill_discount(p_bill, p_discount, p_reason); cancel_open_bill(p_bill, p_reason) | menu_items, menu_sizes (active), bill_lines |
| 5. Thanh toán | pay_bill(p_bill, p_method), p_method là cash hoặc transfer, trả về tổng tiền | bills |
| 6. Đơn mang đi | open_bill(null, 'take_away', null); mark_prep_done(p_bill) | bills (bill_type = take_away, prep_done_at is null, status khác cancelled) |
| 7. Hủy bill đã thu | cancel_paid_bill(p_bill, p_owner_pin, p_reason) trả chuỗi OK, WRONG_PIN hoặc PIN_LOCKED (không phải exception) | bills |
| 8. Nhập hàng | add_purchase(p_ingredient, p_qty, p_late, p_note) | ingredients |
| 9. Kiểm kê | submit_stock_count(p_ingredient, p_kind, p_qty), p_kind là open hoặc close | ingredients |
| 10. Hao hụt | add_waste(p_ingredient, p_qty, p_type, p_note) | waste_types (active), ingredients |
| 11. Thu chi | add_cash_movement(p_direction, p_amount, p_note), p_direction là in hoặc out |  |
| 12. Đóng ca | close_shift(p_closing_cash) |  |
| 13. Báo cáo ca | shift_report(p_shift) trả một JSON gồm shift, summary, ingredients, cash, waste, cash_movements, warnings. Trạng thái là ok, warn, alert hoặc no_data |  |
| 14. Danh sách ca | shift_report(p_shift) lấy summary.overall cho vài ca gần nhất | shifts |
| 15. Nguyên liệu | ghi trực tiếp bảng; ẩn bằng active = false | ingredients |
| 16. Thực đơn và công thức | ghi trực tiếp bảng; sai thì nhận RECIPE_IN_USE | menu_items, menu_sizes, recipe_lines |
| 17. Khu và bàn | ghi trực tiếp bảng | areas, dining_tables |
| 18. Sửa nhập nhầm | correct_purchase(p_purchase, p_new_qty, p_reason); correct_waste(p_waste, p_new_qty, p_reason) | v_purchases_effective, v_waste_detail |
| 19. Nhân viên | link_staff_account(p_email, p_full_name, p_role); set_staff_pin(p_staff, p_pin) | staff |
| 20. Cài đặt | sửa cột value_int của app_settings; ghi waste_types | app_settings, waste_types |
| 21. Nhật ký |  | audit_log |

Các mã lỗi nằm trong nội dung exception của Supabase (PostgrestException.message). Chi tiết từng hàm nằm trong các file 003 đến 009 của thư mục database.

## Cần chốt trước khi vẽ Figma

Sáu điểm dưới đây là lựa chọn của nhóm hoặc của chủ quán thật, nên chưa thể quyết thay họ. Các bản vẽ nháp có thể bắt đầu trước, chỉ phần liên quan cần chờ.

- ☐ **Đăng nhập bằng email và mật khẩu hay chọn tên rồi nhập PIN?** Database hiện dùng tài khoản email, PIN chỉ dành cho chủ xác nhận hủy bill. Tài liệu cũ của nhóm ghi "đăng nhập PIN", cần thống nhất.

- ☐ **Kiểm kê đầu ca có bắt buộc không?** Database không chặn mở ca khi chưa đếm đầu ca, chỉ đóng ca mới bắt buộc đếm cuối ca. Chủ quyết định app có nhắc bắt buộc hay không.

- ☐ **Nhân viên có được xem lại những gì mình đã nhập (nhập hàng, hao hụt) không?** Hiện database chỉ cho chủ đọc các bảng này, nên nhân viên chỉ thấy thông báo "Đã lưu". Muốn cho xem thì cần thêm một quy tắc quyền riêng.

- ☐ **Danh sách ca có hiện màu trạng thái cho bao nhiêu ca?** Mỗi ca phải tính đối soát riêng nên hơi nặng. Đề xuất: 10 ca gần nhất, các ca cũ hơn chỉ hiện khi mở.

- ☐ **Nhân viên có thấy kết quả đối soát sau khi đóng ca không?** Mặc định là không (chỉ chủ xem). Đây là chủ ý của thiết kế, để nhóm xác nhận lại.

- ☐ **Kích thước khung Figma.** Đề xuất điện thoại dọc 360 x 800 cho nhân viên; màn chủ (nhất là Báo cáo ca) cũng làm cho điện thoại trước.

Ngoài phạm vi (không vẽ): in hóa đơn, tiền thối, đặt bàn trước, gộp hay tách bill, kéo thả sơ đồ bàn, thuế và hóa đơn điện tử, chế độ offline.
