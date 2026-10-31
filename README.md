# Fore

Ứng dụng Flutter hỗ trợ quán đồ uống quản lý ca làm, bàn, hóa đơn, thực đơn, kho và đối soát.

## Chạy ứng dụng

1. Cài Flutter SDK và Android Studio hoặc Chrome.
2. Tạo cấu hình môi trường cục bộ theo `.env.example` hoặc `env.json` mẫu. Không đưa khóa bí mật vào Git.
3. Cài dependencies và chạy ứng dụng:

```bash
flutter pub get
flutter run
```

Để chạy bản web:

```bash
flutter run -d chrome
```

## Kiểm tra

```bash
flutter analyze
flutter test
```

Đặc tả nghiệp vụ hiện tại nằm trong [`SPEC.md`](SPEC.md). Cấu hình Supabase và hướng dẫn cơ sở dữ liệu nằm trong `.env.example` và thư mục `database/`.
