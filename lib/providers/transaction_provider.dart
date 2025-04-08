import 'package:flutter/foundation.dart';
import '../database/transaction_database.dart';
import '../models/transaction.dart';

class TransactionProvider extends ChangeNotifier {
  List<Transactions> _transactions = [];

  List<Transactions> get transactions => _transactions;

  double get totalIncome => _transactions
      .where((t) => !t.isExpense)
      .fold(0, (sum, transaction) => sum + transaction.amount);

  double get totalExpense => _transactions
      .where((t) => t.isExpense)
      .fold(0, (sum, transaction) => sum + transaction.amount);

  double get balance => totalIncome - totalExpense;

  TransactionProvider() {
    refreshTransactions();
  }

  Future refreshTransactions() async {
    _transactions = await TransactionDatabase.instance.readAllTransactions();
    notifyListeners();
  }

  Future addTransaction(Transactions transaction) async {
    await TransactionDatabase.instance.create(transaction);
    refreshTransactions();
  }

  Future updateTransaction(Transactions transaction) async {
    await TransactionDatabase.instance.update(transaction);
    refreshTransactions();
  }

  Future deleteTransaction(int id) async {
    await TransactionDatabase.instance.delete(id);
    refreshTransactions();
  }
}