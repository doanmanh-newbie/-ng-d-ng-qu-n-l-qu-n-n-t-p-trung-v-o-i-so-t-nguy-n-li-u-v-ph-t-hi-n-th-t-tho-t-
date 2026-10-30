#!/usr/bin/env bash
# Kiểm tra máy móc các luật bất biến của Fore.
[ -d lib ] || exit 0
fail=0
if grep -rniE "gian lận|trộm" lib; then echo "LỖI: dùng từ cấm (gian lận/trộm)"; fail=1; fi
# Xóa dữ liệu thật: lệnh .delete( hoặc nút chữ "Xóa". Icon thùng rác và tooltip (ví dụ xóa ô tìm kiếm) không tính.
if grep -rnE "\.delete\(|Text\((const )?['\"]Xóa|label: *['\"]Xóa" lib; then echo "LỖI: có nút/lệnh xóa dữ liệu"; fail=1; fi
exit $fail
