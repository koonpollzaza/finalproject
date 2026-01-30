import 'package:flutter/foundation.dart';

class CartItem {
  final String storeId;
  final String menuId;
  final String name;
  final double price;
  final String imageUrl;
  int qty;

  CartItem({
    required this.storeId,
    required this.menuId,
    required this.name,
    required this.price,
    required this.imageUrl,
    this.qty = 1,
  });
}

class CartService {
  CartService._();
  static final CartService instance = CartService._();

  final ValueNotifier<List<CartItem>> items = ValueNotifier<List<CartItem>>([]);

  void addItem(CartItem item) {
    final list = List<CartItem>.from(items.value);
    final idx = list.indexWhere((e) => e.menuId == item.menuId);
    if (idx >= 0) {
      list[idx].qty += item.qty;
    } else {
      list.add(item);
    }
    items.value = list;
  }

  void removeAt(int index) {
    final list = List<CartItem>.from(items.value);
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      items.value = list;
    }
  }

  void clear() => items.value = [];

  double get total =>
      items.value.fold(0.0, (sum, e) => sum + (e.price * e.qty));
}
