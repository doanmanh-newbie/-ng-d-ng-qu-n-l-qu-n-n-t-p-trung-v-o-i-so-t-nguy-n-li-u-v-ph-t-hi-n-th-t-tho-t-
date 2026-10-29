import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/features/shell/presentation/fore_bottom_nav.dart';

Widget _host({
  required bool shiftOpen,
  required List<ShellTab> selected,
  required List<ShellTab> locked,
}) {
  return MaterialApp(
    home: Scaffold(
      bottomNavigationBar: ForeBottomNav(
        current: ShellTab.home,
        shiftOpen: shiftOpen,
        onSelect: selected.add,
        onLockedTap: locked.add,
      ),
    ),
  );
}

void main() {
  testWidgets('chưa mở ca: bấm Kho báo tab bị khóa, không chuyển tab',
      (tester) async {
    final selected = <ShellTab>[];
    final locked = <ShellTab>[];
    await tester.pumpWidget(
      _host(shiftOpen: false, selected: selected, locked: locked),
    );

    await tester.tap(find.text('Kho'));
    await tester.pump();

    expect(locked, [ShellTab.stock]);
    expect(selected, isEmpty);
  });

  testWidgets('chưa mở ca: Trang chủ và Thêm vẫn bấm được', (tester) async {
    final selected = <ShellTab>[];
    final locked = <ShellTab>[];
    await tester.pumpWidget(
      _host(shiftOpen: false, selected: selected, locked: locked),
    );

    await tester.tap(find.text('Thêm'));
    await tester.pump();

    expect(selected, [ShellTab.more]);
    expect(locked, isEmpty);
  });

  testWidgets('đã mở ca: mọi tab bấm được', (tester) async {
    final selected = <ShellTab>[];
    final locked = <ShellTab>[];
    await tester.pumpWidget(
      _host(shiftOpen: true, selected: selected, locked: locked),
    );

    for (final tab in ShellTab.values) {
      await tester.tap(find.text(tab.label));
      await tester.pump();
    }

    expect(selected, ShellTab.values);
    expect(locked, isEmpty);
  });
}
