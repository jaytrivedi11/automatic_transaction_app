import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';
import '../screens/add_transaction_screen.dart';

class TransactionList extends StatelessWidget {
  const TransactionList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
        final transactions = provider.transactions;

        if (transactions.isEmpty) {
          return const Center(
            child: Text(
              'No transactions yet. Add one or import from SMS!',
              style: TextStyle(fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final transaction = transactions[index];
            return TransactionCard(transaction: transaction);
          },
        );
      },
    );
  }
}

class TransactionCard extends StatelessWidget {
  final Transactions transaction;

  const TransactionCard({Key? key, required this.transaction}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final DateFormat formatter = DateFormat('MMM dd, yyyy');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: transaction.isExpense ? Colors.red[100] : Colors.green[100],
          child: Icon(
            getCategoryIcon(transaction.category),
            color: transaction.isExpense ? Colors.red : Colors.green,
          ),
        ),
        title: Text(
          transaction.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${transaction.category} • ${formatter.format(transaction.date)}${transaction.source == 'auto' ? ' • Auto' : ''}',
        ),
        trailing: Text(
          '${transaction.isExpense ? '-' : '+'} ₹${transaction.amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: transaction.isExpense ? Colors.red : Colors.green,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        onTap: () {
          // Open edit transaction screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddTransactionScreen(transaction: transaction),
            ),
          );
        },
        onLongPress: () {
          // Show delete confirmation
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete Transaction'),
              content: const Text('Are you sure you want to delete this transaction?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Provider.of<TransactionProvider>(context, listen: false)
                        .deleteTransaction(transaction.id!);
                    Navigator.of(ctx).pop();
                  },
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  IconData getCategoryIcon(String category) {
    switch (category) {
      case 'Food':
        return Icons.restaurant;
      case 'Shopping':
        return Icons.shopping_bag;
      case 'Transport':
        return Icons.directions_car;
      case 'Bills':
        return Icons.receipt;
      case 'Entertainment':
        return Icons.movie;
      case 'Health':
        return Icons.medical_services;
      case 'Education':
        return Icons.school;
      case 'Salary':
        return Icons.attach_money;
      case 'Transfer':
        return Icons.swap_horiz;
      default:
        return Icons.category;
    }
  }
}