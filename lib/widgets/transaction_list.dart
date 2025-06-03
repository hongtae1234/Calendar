import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/transaction_service.dart';
import 'transaction_list_item.dart';

class TransactionList extends StatefulWidget {
  final DateTime selectedMonth;
  final VoidCallback onTransactionsChanged;

  const TransactionList({
    super.key,
    required this.selectedMonth,
    required this.onTransactionsChanged,
  });

  @override
  State<TransactionList> createState() => _TransactionListState();
}

class _TransactionListState extends State<TransactionList> {
  final _transactionService = TransactionService();
  List<Transaction> _transactions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  @override
  void didUpdateWidget(TransactionList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMonth != widget.selectedMonth) {
      _loadTransactions();
    }
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final transactions = await _transactionService.getTransactionsForMonth(
        widget.selectedMonth,
      );
      setState(() {
        _transactions = transactions;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteTransaction(Transaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('거래 내역 삭제'),
        content: const Text('이 거래 내역을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _transactionService.deleteTransaction(transaction.id);
      _loadTransactions();
      widget.onTransactionsChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_transactions.isEmpty) {
      return const Center(
        child: Text('거래 내역이 없습니다.'),
      );
    }

    // 날짜별로 거래 내역 그룹화
    final groupedTransactions = <DateTime, List<Transaction>>{};
    for (final transaction in _transactions) {
      final date = DateTime(
        transaction.date.year,
        transaction.date.month,
        transaction.date.day,
      );
      groupedTransactions.putIfAbsent(date, () => []);
      groupedTransactions[date]!.add(transaction);
    }

    // 날짜 기준으로 정렬
    final sortedDates = groupedTransactions.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final transactions = groupedTransactions[date]!;
        final dateFormat = DateFormat('M월 d일 (E)', 'ko_KR');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                dateFormat.format(date),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...transactions.map((transaction) => Dismissible(
              key: Key(transaction.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                color: Colors.red,
                child: const Icon(
                  Icons.delete,
                  color: Colors.white,
                ),
              ),
              onDismissed: (direction) {
                _deleteTransaction(transaction);
              },
              child: TransactionListItem(
                transaction: transaction,
              ),
            )),
            const Divider(),
          ],
        );
      },
    );
  }
} 