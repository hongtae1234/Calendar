import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/transaction_service.dart';

class AddTransactionButton extends StatelessWidget {
  final VoidCallback onTransactionAdded;

  const AddTransactionButton({
    super.key,
    required this.onTransactionAdded,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (context) => AddTransactionSheet(
            onTransactionAdded: onTransactionAdded,
          ),
        );
      },
      child: const Icon(Icons.add),
    );
  }
}

class AddTransactionSheet extends StatefulWidget {
  final VoidCallback onTransactionAdded;

  const AddTransactionSheet({
    super.key,
    required this.onTransactionAdded,
  });

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  TransactionType _type = TransactionType.expense;
  TransactionCategory _category = TransactionCategory.food;
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final transaction = Transaction(
        title: _titleController.text,
        amount: int.parse(_amountController.text.replaceAll(',', '')),
        date: _selectedDate,
        type: _type,
        category: _category,
        note: _noteController.text.isEmpty ? null : _noteController.text,
      );

      await TransactionService().addTransaction(transaction);
      widget.onTransactionAdded();

      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat('#,###');

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<TransactionType>(
              segments: TransactionType.values
                  .map((type) => ButtonSegment<TransactionType>(
                        value: type,
                        label: Text(type.label),
                        icon: Icon(type.icon),
                      ))
                  .toList(),
              selected: {_type},
              onSelectionChanged: (Set<TransactionType> newSelection) {
                setState(() {
                  _type = newSelection.first;
                  _category = _type == TransactionType.income
                      ? TransactionCategory.salary
                      : TransactionCategory.food;
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TransactionCategory>(
              value: _category,
              items: (_type == TransactionType.income
                      ? TransactionCategory.incomeCategories()
                      : TransactionCategory.expenseCategories())
                  .map((category) => DropdownMenuItem(
                        value: category,
                        child: Row(
                          children: [
                            Icon(category.icon, color: category.color),
                            const SizedBox(width: 8),
                            Text(category.label),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (TransactionCategory? value) {
                if (value != null) {
                  setState(() => _category = value);
                }
              },
              decoration: const InputDecoration(
                labelText: '카테고리',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '제목',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '제목을 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: '금액',
                border: OutlineInputBorder(),
                suffixText: '원',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '금액을 입력해주세요';
                }
                if (int.tryParse(value.replaceAll(',', '')) == null) {
                  return '올바른 금액을 입력해주세요';
                }
                return null;
              },
              onChanged: (value) {
                if (value.isNotEmpty) {
                  final number = int.tryParse(value.replaceAll(',', ''));
                  if (number != null) {
                    final formatted = numberFormat.format(number);
                    if (formatted != value) {
                      _amountController.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(
                          offset: formatted.length,
                        ),
                      );
                    }
                  }
                }
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                DateFormat('yyyy년 M월 d일').format(_selectedDate),
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _selectDate,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: '메모',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submitForm,
              child: const Text('저장'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
} 