import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';

class AddTransactionScreen extends StatefulWidget {
  final Transactions? transaction;

  const AddTransactionScreen({Key? key, this.transaction}) : super(key: key);

  @override
  _AddTransactionScreenState createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'Others';
  bool _isExpense = true;

  List<String> categories = [
    'Food', 'Shopping', 'Transport', 'Bills', 'Entertainment',
    'Health', 'Education', 'Salary', 'Transfer', 'Others'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      _titleController.text = widget.transaction!.title;
      _amountController.text = widget.transaction!.amount.toString();
      _selectedDate = widget.transaction!.date;
      _selectedCategory = widget.transaction!.category;
      _isExpense = widget.transaction!.isExpense;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final transaction = Transactions(
        id: widget.transaction?.id,
        title: _titleController.text,
        amount: double.parse(_amountController.text),
        date: _selectedDate,
        category: _selectedCategory,
        isExpense: _isExpense,
      );

      final provider = Provider.of<TransactionProvider>(context, listen: false);

      if (widget.transaction == null) {
        provider.addTransaction(transaction);
      } else {
        provider.updateTransaction(transaction);
      }

      Navigator.of(context).pop();
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(
              widget.transaction == null ? 'Add Transaction' : 'Edit Transaction'
          ),
        ),
        body: Padding(
        padding: const EdgeInsets.all(16.0),
    child: Form(
    key: _formKey,
    child: ListView(
    children: [
    // Transaction Type Switch
    Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
    const Text('Income'),
   Switch(
      value: _isExpense,
      onChanged: (value) {
        setState(() {
          _isExpense = value;
        });
      },
      activeColor: Colors.red,
      inactiveThumbColor: Colors.green,
    ),
      const Text('Expense'),
      ],
    ),
      const SizedBox(height: 20),

      // Title Field
      TextFormField(
        controller: _titleController,
        decoration: const InputDecoration(
          labelText: 'Title',
          border: OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter a title';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),

      // Amount Field
      TextFormField(
        controller: _amountController,
        decoration: const InputDecoration(
          labelText: 'Amount',
          border: OutlineInputBorder(),
          prefixText: '₹ ',
        ),
        keyboardType: TextInputType.number,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter an amount';
          }
          if (double.tryParse(value) == null) {
            return 'Please enter a valid number';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),

      // Date Picker
      ListTile(
        title: const Text('Date'),
        subtitle: Text(
          DateFormat('MMM dd, yyyy').format(_selectedDate),
          style: const TextStyle(fontSize: 16),
        ),
        trailing: const Icon(Icons.calendar_today),
        onTap: () => _selectDate(context),
      ),
      const SizedBox(height: 16),

      // Category Dropdown
      DropdownButtonFormField<String>(
        decoration: const InputDecoration(
          labelText: 'Category',
          border: OutlineInputBorder(),
        ),
        value: _selectedCategory,
        items: categories.map((category) {
          return DropdownMenuItem(
            value: category,
            child: Text(category),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedCategory = value!;
          });
        },
      ),
      const SizedBox(height: 32),

      // Submit Button
      ElevatedButton(
        onPressed: _submitForm,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(
          widget.transaction == null ? 'Add Transaction' : 'Update Transaction',
          style: const TextStyle(fontSize: 16),
        ),
      ),
    ],
    ),
    ),
        ),
    );
  }
}