# Fore

Ứng dụng quản lý quán bán, tập trung vào **đối soát nguyên liệu và phát hiện thất thoát**.
Quán nước (trà sữa, cà phê) trước, sau đó mở rộng sang phở, cơm.

> Môn: Lập trình thiết bị di động · Công nghệ: Flutter (Dart) + Supabase (PostgreSQL)

## Vấn đề giải quyết
Chủ quán khó biết nguyên liệu hao hụt có đúng với số ly đã bán hay không. Fore so sánh:
- **Thực dùng** = tồn đầu + nhập − tồn cuối (nhân viên đếm mù)
- **Lý thuyết** = Σ (số bán × định lượng công thức)
- **Chênh lệch** = thực dùng − lý thuyết → quy ra số ly và doanh thu ước tính

## Cấu trúc
```
lib/          mã Dart (core/ dùng chung, features/ theo chức năng)
test/         kiểm thử
database/     sd supabase SQL: bảng, ràng buộc, hàm đối soát, dữ liệu thử
docs/         tài liệu, báo cáo tuần, biên bản họp
```

## Chạy dự án
1. Cài Flutter, chạy `flutter doctor`.
2. Lần đầu, tạo phần nền Android: `flutter create --project-name fore --platforms=android .`
   (nếu `lib/main.dart` bị ghi đè: `git checkout lib/main.dart`)
3. `flutter pub get`
4. Lấy `SUPABASE_URL` và `SUPABASE_ANON_KEY` từ nhóm trưởng (xem `.env.example`).
5. Chạy:
   ```
   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
   ```
6. Database: chạy lần lượt các file trong `supabase/` trên SQL Editor của Supabase.

## Tiến độ
Xem tab **Projects** (bảng việc), **Milestones** (8 tuần) và thư mục `docs/weekly/`.
