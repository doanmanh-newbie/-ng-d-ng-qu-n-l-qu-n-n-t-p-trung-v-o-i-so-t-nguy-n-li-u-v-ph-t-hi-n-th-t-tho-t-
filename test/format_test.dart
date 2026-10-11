import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/format.dart';

void main() {
  test('định dạng tiền', () {
    expect(formatVnd(583000), '583.000đ');
    expect(formatVnd(35000), '35.000đ');
    expect(formatVnd(0), '0đ');
  });
}
