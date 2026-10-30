#!/usr/bin/env bash
# Kiểm tra máy móc các luật bất biến của Fore.
[ -d lib ] || exit 0
fail=0
if grep -rniE "gian lận|trộm" lib; then echo "LỖI: dùng từ cấm (gian lận/trộm)"; fail=1; fi
if grep -rnE "Icons\.delete|'Xóa'|\"Xóa\"|\.delete\(\)" lib; then echo "LỖI: có nút/lệnh xóa dữ liệu"; fail=1; fi
if [ -d lib/features/stock_count ] && [ ! -f test/blind_count_test.dart ]; then
  echo "LỖI: thiếu test/blind_count_test.dart cho màn đếm mù"; fail=1
fi
exit $fail
