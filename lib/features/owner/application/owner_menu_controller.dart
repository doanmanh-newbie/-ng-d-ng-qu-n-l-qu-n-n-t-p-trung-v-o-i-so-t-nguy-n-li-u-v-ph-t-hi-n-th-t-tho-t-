import 'package:flutter/foundation.dart';

import '../domain/owner_menu_repository.dart';

/// Owns the state and commands for menu configuration.
class OwnerMenuController extends ChangeNotifier {
  OwnerMenuController(this._repository);

  final OwnerMenuRepository _repository;

  List<Map<String, dynamic>> items = const [];
  List<Map<String, dynamic>> activeIngredients = const [];
  bool loading = true;
  bool changed = false;
  Object? failure;

  Future<void> load({bool quiet = false}) async {
    if (!quiet || items.isEmpty) {
      loading = true;
      notifyListeners();
    }
    try {
      final snapshot = await _repository.load();
      items = snapshot.items;
      activeIngredients = snapshot.activeIngredients;
      failure = null;
    } catch (error) {
      failure = error;
    }
    loading = false;
    notifyListeners();
  }

  Future<void> createItem({
    required String name,
    required String? groupName,
    required String firstSize,
    required int firstPrice,
  }) =>
      _save(() => _repository.createItem(
            name: name,
            groupName: groupName,
            firstSize: firstSize,
            firstPrice: firstPrice,
          ));

  Future<void> updateItem({
    required String id,
    required String name,
    required String? groupName,
  }) =>
      _save(() => _repository.updateItem(
            id: id,
            name: name,
            groupName: groupName,
          ));

  Future<void> createSize({
    required String itemId,
    required String name,
    required int price,
  }) =>
      _save(() => _repository.createSize(
            itemId: itemId,
            name: name,
            price: price,
          ));

  Future<void> updateSize({
    required String id,
    required String name,
    required int price,
  }) =>
      _save(() => _repository.updateSize(id: id, name: name, price: price));

  Future<void> setActive({
    required OwnerMenuEntity entity,
    required String id,
    required bool active,
  }) =>
      _save(() => _repository.setActive(
            entity: entity,
            id: id,
            active: active,
          ));

  Future<void> createRecipeLine({
    required String sizeId,
    required String ingredientId,
    required int quantity,
  }) =>
      _save(() => _repository.createRecipeLine(
            sizeId: sizeId,
            ingredientId: ingredientId,
            quantity: quantity,
          ));

  Future<void> updateRecipeLine({required String id, required int quantity}) =>
      _save(() => _repository.updateRecipeLine(id: id, quantity: quantity));

  Future<void> removeRecipeLine(String id) =>
      _save(() => _repository.removeRecipeLine(id));

  Future<void> _save(Future<void> Function() action) async {
    await action();
    changed = true;
    await load(quiet: true);
  }
}
