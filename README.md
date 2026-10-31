# Fore

Ứng dụng Flutter hỗ trợ quán đồ uống quản lý ca làm, bàn, hóa đơn, thực đơn, kho và đối soát.

## Chạy ứng dụng

1. Cài Flutter SDK và Android Studio hoặc Chrome.
2. Tạo `env.json` ở gốc repo với `SUPABASE_URL` và `SUPABASE_ANON_KEY`. App đọc cấu hình bằng Dart defines; file `.env` không được tự nạp. Không đưa khóa bí mật vào Git.
3. Cài dependencies và chạy ứng dụng:

```bash
flutter pub get
flutter run --dart-define-from-file=env.json
```

Để chạy bản web:

```bash
flutter run -d chrome --dart-define-from-file=env.json
```

## Kiểm tra

```bash
flutter analyze
flutter test
```

Hướng dẫn cài database Supabase nằm trong [`HUONG_DAN_NHIEU_QUAN.md`](HUONG_DAN_NHIEU_QUAN.md). Schema được chia thành bốn nhóm SQL trong `database/`; chỉ chạy `database/00_reset_schema.sql` khi chủ động chấp nhận xóa dữ liệu nghiệp vụ trong schema `public`. Lịch sử kiểm tra và phần còn thiếu nằm trong [`docs/audit.md`](docs/audit.md). Cấu hình mẫu Supabase nằm trong `.env.example`; không đưa khóa thật vào Git.

Kiến trúc thư mục và quy tắc phân lớp Dart được ghi trong [`docs/kien-truc-flutter.md`](docs/kien-truc-flutter.md).
