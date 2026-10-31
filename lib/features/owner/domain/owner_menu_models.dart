/// Loaded data used by the owner menu management screen.
///
/// Maps retain the field names returned by PostgREST so this read model remains
/// aligned with the existing menu tables and recipe-line editor.
class OwnerMenuSnapshot {
  const OwnerMenuSnapshot({
    required this.items,
    required this.activeIngredients,
  });

  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> activeIngredients;
}
