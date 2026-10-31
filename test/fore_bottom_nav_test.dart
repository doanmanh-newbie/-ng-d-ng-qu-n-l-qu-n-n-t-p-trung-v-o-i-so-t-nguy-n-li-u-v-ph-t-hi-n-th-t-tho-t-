import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/widgets/fore_bottom_nav.dart';

Widget _host({required List<int> selected, bool disableAnimations = false}) =>
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: disableAnimations,
        ),
        child: child!,
      ),
      home: Scaffold(
        bottomNavigationBar: ForeBottomNav(
          items: const [
            NavItem(label: 'Tổng quan', icon: 'grid'),
            NavItem(label: 'Kho', icon: 'package'),
            NavItem(label: 'Đóng ca', icon: 'lock', enabled: false),
          ],
          selected: 0,
          onSelect: selected.add,
        ),
      ),
    );

void main() {
  testWidgets('chọn tab đang hoạt động gọi callback đúng chỉ số',
      (tester) async {
    final selected = <int>[];
    await tester.pumpWidget(_host(selected: selected));

    await tester.tap(find.text('Kho'));
    await tester.pumpAndSettle();

    expect(selected, [1]);
  });

  testWidgets('tab bị khóa không gọi callback', (tester) async {
    final selected = <int>[];
    await tester.pumpWidget(_host(selected: selected));

    await tester.tap(find.text('Đóng ca'));
    await tester.pump();

    expect(selected, isEmpty);
    expect(find.bySemanticsLabel('Đóng ca'), findsOneWidget);
  });

  testWidgets('thanh điều hướng tôn trọng cài đặt giảm chuyển động',
      (tester) async {
    await tester.pumpWidget(_host(selected: [], disableAnimations: true));

    final transitions = tester.widgetList<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    expect(transitions, isNotEmpty);
    expect(
        transitions.every((transition) => transition.duration == Duration.zero),
        isTrue);
  });
}
