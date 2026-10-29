import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/errors/app_failure.dart';
import 'package:fore/features/inventory/application/cash_controller.dart';
import 'package:fore/features/inventory/application/purchase_controller.dart';
import 'package:fore/features/inventory/application/waste_controller.dart';
import 'package:fore/features/inventory/domain/inventory_models.dart';

import '../support/fakes.dart';

const milk = IngredientOption(
    id: 'milk', name: 'Sữa', unit: 'ml', important: true, group: null);
const cups = IngredientOption(
    id: 'cups', name: 'Ly', unit: 'piece', important: false, group: null);
const expired =
    WasteTypeOption(code: 'expired', label: 'Đổ bỏ', requiresNote: false);
const other = WasteTypeOption(code: 'other', label: 'Khác', requiresNote: true);

void main() {
  late FakeInventoryRepository repo;

  setUp(() {
    repo = FakeInventoryRepository()
      ..ingredientOptions = [milk, cups]
      ..wasteTypeOptions = [expired, other];
  });

  group('nhập hàng', () {
    late PurchaseController c;
    setUp(() async {
      c = PurchaseController(repo);
      await c.load();
    });

    test('chưa chọn gì thì không gửi được', () {
      expect(c.canSubmit, isFalse);
      c.select(milk);
      expect(c.canSubmit, isFalse); // chưa có số lượng
      c.setQuantityText('500');
      expect(c.canSubmit, isTrue);
    });

    test('chọn nguyên liệu thì đơn vị về đơn vị gốc', () {
      c.select(milk);
      c.setUnit(unitChoices('ml')[1]);
      c.select(cups);
      expect(c.unitChoice!.label, equals('cái'));
    });

    test('nhập 1,5 lít sữa gửi 1500 ml', () async {
      c.select(milk);
      c.setUnit(unitChoices('ml')[1]);
      c.setQuantityText('1,5');
      c.setNote('  hàng mới về  ');
      c.setLate(true);
      expect(await c.submit(), isTrue);
      expect(
          repo.calls, contains('addPurchase:milk:1500:true:  hàng mới về  '));
    });

    test('gửi xong thì xóa form', () async {
      c.select(milk);
      c.setQuantityText('1000');
      await c.submit();
      expect(c.selected, isNull);
      expect(c.quantityText, isEmpty);
      expect(c.late, isFalse);
    });

    test('lỗi thì giữ nguyên form để sửa và thử lại', () async {
      c.select(milk);
      c.setQuantityText('1000');
      repo.failNext('addPurchase', const DatabaseFailure('NO_OPEN_SHIFT'));
      await expectLater(c.submit(), throwsA(isA<DatabaseFailure>()));
      expect(c.selected, equals(milk));
      expect(c.quantityText, equals('1000'));
    });

    test('số lượng không hợp lệ: bị chặn ở máy', () async {
      c.select(milk);
      c.setQuantityText('0');
      await expectLater(
          c.submit(),
          throwsA(isA<DatabaseFailure>()
              .having((e) => e.code, 'code', 'QTY_INVALID')));
      expect(repo.count('addPurchase'), equals(0));
    });
  });

  group('hao hụt', () {
    late WasteController c;
    setUp(() async {
      c = WasteController(repo);
      await c.load();
    });

    test('tải cả nguyên liệu và loại hao hụt từ database', () {
      expect(c.ingredients, hasLength(2));
      expect(c.types.map((t) => t.code).toList(), equals(['expired', 'other']));
    });

    test('loại thường: không cần ghi chú', () {
      c.selectIngredient(milk);
      c.selectType(expired);
      c.setQuantityText('200');
      expect(c.noteRequired, isFalse);
      expect(c.canSubmit, isTrue);
    });

    test('loại "Khác": ghi chú từ 5 ký tự mới gửi được (đã cắt khoảng trắng)',
        () {
      c.selectIngredient(milk);
      c.selectType(other);
      c.setQuantityText('200');
      expect(c.canSubmit, isFalse);
      c.setNote('    ab  ');
      expect(c.canSubmit, isFalse);
      c.setNote('đổ nhầm');
      expect(c.canSubmit, isTrue);
    });

    test('gửi đúng tham số rồi xóa form', () async {
      c.selectIngredient(milk);
      c.selectType(expired);
      c.setQuantityText('2');
      c.setUnit(unitChoices('ml')[1]);
      expect(await c.submit(), isTrue);
      expect(repo.calls, contains('addWaste:milk:2000:expired:'));
      expect(c.ingredient, isNull);
    });

    test('thiếu ghi chú ở loại bắt buộc: bị chặn ở máy', () async {
      c.selectIngredient(milk);
      c.selectType(other);
      c.setQuantityText('5');
      await expectLater(
          c.submit(),
          throwsA(isA<DatabaseFailure>()
              .having((e) => e.code, 'code', 'NOTE_REQUIRED')));
      expect(repo.count('addWaste'), equals(0));
    });
  });

  group('thu chi tiền mặt', () {
    late CashController c;
    setUp(() => c = CashController(repo));

    test('mặc định là "Chi ra"', () => expect(c.incoming, isFalse));

    test('chi ra bắt buộc ghi chú từ 3 ký tự', () {
      c.setAmount(50000);
      expect(c.canSubmit, isFalse);
      c.setNote('đá');
      expect(c.canSubmit, isFalse);
      c.setNote('mua đá');
      expect(c.canSubmit, isTrue);
    });

    test('thu vào không cần ghi chú', () {
      c.setIncoming(true);
      c.setAmount(100000);
      expect(c.canSubmit, isTrue);
    });

    test('số tiền: phải > 0 và không quá trần', () {
      c.setIncoming(true);
      c.setAmount(0);
      expect(c.canSubmit, isFalse);
      c.setAmount(null);
      expect(c.canSubmit, isFalse);
      c.setAmount(CashController.maxAmount + 1);
      expect(c.canSubmit, isFalse);
      c.setAmount(CashController.maxAmount);
      expect(c.canSubmit, isTrue);
    });

    test('gửi đúng hướng và số tiền, rồi xóa form', () async {
      c.setAmount(50000);
      c.setNote('mua đá');
      expect(await c.submit(), isTrue);
      expect(repo.calls, contains('addMovement:out:50000:mua đá'));
      expect(c.amount, isNull);
    });

    test('chi ra thiếu ghi chú: bị chặn', () async {
      c.setAmount(50000);
      await expectLater(
          c.submit(),
          throwsA(isA<DatabaseFailure>()
              .having((e) => e.code, 'code', 'NOTE_REQUIRED')));
    });
  });
}
