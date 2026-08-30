class Category {
  final int id;
  final String name;

  /// Null for a top-level category. Set for a subcategory, e.g.
  /// "Fridge Repair" pointing at "Appliance Repair" (migration 020).
  final int? parentCategoryId;

  const Category({required this.id, required this.name, this.parentCategoryId});

  factory Category.fromMap(Map<String, dynamic> map) => Category(
        id: map['id'] as int,
        name: map['name'] as String,
        parentCategoryId: map['parent_category_id'] as int?,
      );

  bool get isTopLevel => parentCategoryId == null;
}
