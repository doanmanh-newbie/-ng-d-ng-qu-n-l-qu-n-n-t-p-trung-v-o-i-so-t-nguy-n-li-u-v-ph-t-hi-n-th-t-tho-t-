import '../../../core/application/action_notifier.dart';
import '../../../core/application/load_phase.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/inventory_models.dart';
import '../domain/inventory_repository.dart';

/// Phiếu nhập hàng: chọn nguyên liệu, nhập số lượng (có thể nhập theo lít / kg), ghi chú.
/// Không hiện lịch sử nhập hay số tồn (chỉ chủ xem).
class PurchaseController extends ActionNotifier {
  PurchaseController(this._repo);

  final InventoryRepository _repo;

  LoadPhase phase = LoadPhase.loading;
  List<IngredientOption> ingredients = const [];
  AppFailure? failure;

  IngredientOption? selected;
  UnitChoice? unitChoice;
  String quantityText = '';
  bool late = false;
  String note = '';

  Future<void> load() async {
    if (ingredients.isEmpty) {
      phase = LoadPhase.loading;
      notify();
    }
    try {
      ingredients = await _repo.ingredients();
      failure = null;
      phase = LoadPhase.ready;
    } on AppFailure catch (f) {
      failure = f;
      phase = ingredients.isEmpty ? LoadPhase.error : LoadPhase.ready;
    }
    notify();
  }

  void select(IngredientOption option) {
    selected = option;
    unitChoice = unitChoices(option.unit).first; // luôn bắt đầu bằng đơn vị gốc
    notify();
  }

  void setUnit(UnitChoice choice) {
    unitChoice = choice;
    notify();
  }

  void setQuantityText(String text) {
    quantityText = text;
    notify();
  }

  void setLate(bool value) {
    late = value;
    notify();
  }

  void setNote(String value) {
    note = value;
    notify();
  }

  /// Số lượng theo đơn vị gốc; `null` nếu chưa hợp lệ.
  int? get quantity {
    final choice = unitChoice;
    return choice == null ? null : quantityInBase(quantityText, choice);
  }

  bool get canSubmit => selected != null && quantity != null && !busy;

  void reset() {
    selected = null;
    unitChoice = null;
    quantityText = '';
    late = false;
    note = '';
    notify();
  }

  Future<bool> submit() async {
    final option = selected;
    final qty = quantity;
    if (option == null) throw const DatabaseFailure('NOT_FOUND');
    if (qty == null) throw const DatabaseFailure('QTY_INVALID');
    final done = await runAction<bool>(() async {
      await _repo.addPurchase(
          ingredientId: option.id, qty: qty, late: late, note: note);
      return true;
    });
    if (done ?? false) reset();
    return done ?? false;
  }
}
