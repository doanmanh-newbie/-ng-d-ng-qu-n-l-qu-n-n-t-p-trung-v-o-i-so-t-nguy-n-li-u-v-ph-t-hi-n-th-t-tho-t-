import 'owner_menu_models.dart';

/// Data-access contract for the owner's menu editor.
abstract interface class OwnerMenuRepository {
  Future<OwnerMenuSnapshot> load();

  Future<void> createItem({
    required String name,
    required String? groupName,
    required String firstSize,
    required int firstPrice,
  });

  Future<void> updateItem({
    required String id,
    required String name,
    required String? groupName,
  });

  Future<void> createSize({
    required String itemId,
    required String name,
    required int price,
  });

  Future<void> updateSize({
    required String id,
    required String name,
    required int price,
  });

  Future<void> setActive({
    required OwnerMenuEntity entity,
    required String id,
    required bool active,
  });

  Future<void> createRecipeLine({
    required String sizeId,
    required String ingredientId,
    required int quantity,
  });

  Future<void> updateRecipeLine({required String id, required int quantity});

  Future<void> removeRecipeLine(String id);
}

enum OwnerMenuEntity { item, size }
