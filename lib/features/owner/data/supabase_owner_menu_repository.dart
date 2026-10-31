import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/owner_menu_models.dart';
import '../domain/owner_menu_repository.dart';

/// Supabase implementation for owner menu configuration.
class SupabaseOwnerMenuRepository implements OwnerMenuRepository {
  SupabaseOwnerMenuRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<OwnerMenuSnapshot> load() async {
    final results = await Future.wait<dynamic>([
      _client
          .from('menu_items')
          .select('id,name,group_name,active')
          .order('name'),
      _client
          .from('menu_sizes')
          .select('id,item_id,size_name,price,active')
          .order('size_name'),
      _client.from('recipe_lines').select('id,size_id,ingredient_id,qty'),
      _client.from('ingredients').select('id,name,unit,active').order('name'),
    ]);

    final sizes = _rows(results[1]);
    final lines = _rows(results[2]);
    final ingredientRows = _rows(results[3]);
    final ingredientsById = {
      for (final ingredient in ingredientRows)
        '${ingredient['id']}': ingredient,
    };

    for (final line in lines) {
      line['ingredients'] = ingredientsById['${line['ingredient_id']}'];
    }
    for (final size in sizes) {
      size['recipe_lines'] =
          lines.where((line) => line['size_id'] == size['id']).toList();
    }

    final items = _rows(results[0]);
    for (final item in items) {
      item['menu_sizes'] =
          sizes.where((size) => size['item_id'] == item['id']).toList();
    }

    return OwnerMenuSnapshot(
      items: items,
      activeIngredients: ingredientRows
          .where((ingredient) => ingredient['active'] == true)
          .toList(),
    );
  }

  @override
  Future<void> createItem({
    required String name,
    required String? groupName,
    required String firstSize,
    required int firstPrice,
  }) async {
    final item = await _client
        .from('menu_items')
        .insert({'name': name, 'group_name': groupName})
        .select('id')
        .single();
    await _client.from('menu_sizes').insert({
      'item_id': item['id'],
      'size_name': firstSize,
      'price': firstPrice,
    });
  }

  @override
  Future<void> updateItem({
    required String id,
    required String name,
    required String? groupName,
  }) async {
    await _client.from('menu_items').update({
      'name': name,
      'group_name': groupName,
    }).eq('id', id);
  }

  @override
  Future<void> createSize({
    required String itemId,
    required String name,
    required int price,
  }) async {
    await _client.from('menu_sizes').insert({
      'item_id': itemId,
      'size_name': name,
      'price': price,
    });
  }

  @override
  Future<void> updateSize({
    required String id,
    required String name,
    required int price,
  }) async {
    await _client.from('menu_sizes').update({
      'size_name': name,
      'price': price,
    }).eq('id', id);
  }

  @override
  Future<void> setActive({
    required OwnerMenuEntity entity,
    required String id,
    required bool active,
  }) async {
    final table = switch (entity) {
      OwnerMenuEntity.item => 'menu_items',
      OwnerMenuEntity.size => 'menu_sizes',
    };
    await _client.from(table).update({'active': active}).eq('id', id);
  }

  @override
  Future<void> createRecipeLine({
    required String sizeId,
    required String ingredientId,
    required int quantity,
  }) async {
    await _client.from('recipe_lines').insert({
      'size_id': sizeId,
      'ingredient_id': ingredientId,
      'qty': quantity,
    });
  }

  @override
  Future<void> updateRecipeLine(
      {required String id, required int quantity}) async {
    await _client.from('recipe_lines').update({'qty': quantity}).eq('id', id);
  }

  @override
  Future<void> removeRecipeLine(String id) async {
    await _client.from('recipe_lines').delete().eq('id', id);
  }

  List<Map<String, dynamic>> _rows(dynamic value) => (value as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList();
}
