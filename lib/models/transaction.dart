import 'package:flutter/material.dart';

enum TransactionType {
  income('수입', Icons.arrow_upward, Colors.green),
  expense('지출', Icons.arrow_downward, Colors.red);

  final String label;
  final IconData icon;
  final Color color;
  const TransactionType(this.label, this.icon, this.color);
}

enum TransactionCategory {
  // 수입 카테고리
  salary('월급', Icons.work, Colors.blue),
  bonus('보너스', Icons.card_giftcard, Colors.purple),
  interest('이자', Icons.account_balance, Colors.teal),
  other_income('기타 수입', Icons.add_circle, Colors.green),

  // 지출 카테고리
  food('식비', Icons.restaurant, Colors.orange),
  transportation('교통비', Icons.directions_bus, Colors.blue),
  shopping('쇼핑', Icons.shopping_bag, Colors.pink),
  entertainment('여가', Icons.movie, Colors.purple),
  health('의료/건강', Icons.local_hospital, Colors.red),
  housing('주거/통신', Icons.home, Colors.brown),
  education('교육', Icons.school, Colors.indigo),
  other_expense('기타 지출', Icons.remove_circle, Colors.grey);

  final String label;
  final IconData icon;
  final Color color;
  const TransactionCategory(this.label, this.icon, this.color);

  static List<TransactionCategory> incomeCategories() {
    return [salary, bonus, interest, other_income];
  }

  static List<TransactionCategory> expenseCategories() {
    return [
      food,
      transportation,
      shopping,
      entertainment,
      health,
      housing,
      education,
      other_expense
    ];
  }
}

class Transaction {
  final String id;
  final String title;
  final int amount;
  final DateTime date;
  final TransactionType type;
  final TransactionCategory category;
  String? note;

  Transaction({
    String? id,
    required this.title,
    required this.amount,
    required this.date,
    required this.type,
    required this.category,
    this.note,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'type': type.name,
      'category': category.name,
      'note': note,
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      title: json['title'],
      amount: json['amount'],
      date: DateTime.parse(json['date']),
      type: TransactionType.values.firstWhere(
        (e) => e.name == json['type'],
      ),
      category: TransactionCategory.values.firstWhere(
        (e) => e.name == json['category'],
      ),
      note: json['note'],
    );
  }
} 