import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../services/sms_parser_service.dart';
import '../services/notification_parser_service.dart';
import '../widgets/balance_card.dart';
import '../widgets/transaction_list.dart';
import 'add_transaction_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SmsParserService _smsParserService = SmsParserService();
  // final NotificationParserService _notificationParserService = NotificationParserService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _setupServices();
  }

  Future<void> _setupServices() async {
    // await _notificationParserService.initNotificationListener();
  }

  Future<void> _refreshTransactions() async {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    await provider.refreshTransactions();
  }

  Future<void> _parseSmsTransactions() async {
    setState(() {
      _isLoading = true;
    });

    await _smsParserService.parseTransactionsFromSms();
    await _refreshTransactions();

    setState(() {
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SMS transactions processed')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        actions: [
          IconButton(
            icon: Icon(_isLoading ? Icons.sync : Icons.message),
            onPressed: _isLoading ? null : _parseSmsTransactions,
            tooltip: 'Parse SMS Transactions',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshTransactions,
        child: Column(
          children: [
            // Balance Card
            Consumer<TransactionProvider>(
              builder: (context, provider, _) => BalanceCard(
                balance: provider.balance,
                income: provider.totalIncome,
                expense: provider.totalExpense,
              ),
            ),

            // Transactions List
            const Expanded(
              child: TransactionList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddTransactionScreen()),
          );
        },
        child: const Icon(Icons.add),
        tooltip: 'Add Transaction',
      ),
    );
  }
}