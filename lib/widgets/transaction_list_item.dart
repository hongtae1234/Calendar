import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';

class TransactionListItem extends StatelessWidget {
  final Transaction transaction;

  const TransactionListItem({
    super.key,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat('#,###');
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: transaction.category.color.withOpacity(0.2),
          child: Icon(
            transaction.category.icon,
            color: transaction.category.color,
          ),
        ),
        title: Text(
          transaction.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${transaction.category.label} • ${dateFormat.format(transaction.date)}',
        ),
        trailing: Text(
          '${transaction.type == TransactionType.expense ? "-" : "+"}'
          '${numberFormat.format(transaction.amount)}원',
          style: TextStyle(
            color: transaction.type.color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
} 