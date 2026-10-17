-- NGUY HIỂM: XÓA TOÀN BỘ bảng, view, hàm do Fore tạo trong schema public (để chạy lại 001 từ đầu).
-- CHỈ dùng trên project Supabase THỬ. KHÔNG chạy trên database có dữ liệu thật của quán.
-- Không đụng tới schema auth (tài khoản đăng nhập vẫn còn).
drop schema public cascade;
create schema public;
grant usage on schema public to postgres, anon, authenticated, service_role;
grant all on schema public to postgres, service_role;
create extension if not exists pgcrypto with schema extensions;
