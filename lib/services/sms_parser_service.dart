import 'package:flutter/foundation.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';
import '../database/transaction_database.dart';

class SmsParserService {
  final SmsQuery _query = SmsQuery();
  List<SmsMessage> _messages = [];
  final String _lastOpenTimeKey = 'last_app_open_time';
  final String _isFirstOpenKey = 'is_first_app_open';

  // Request SMS permission
  Future<bool> requestSmsPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  // Save current timestamp as last opened time
  Future<void> saveOpenTime() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(_lastOpenTimeKey, now);
    await prefs.setBool(_isFirstOpenKey, false);
  }

  // Check if this is first app open
  Future<bool> isFirstOpen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isFirstOpenKey) ?? true;
  }

  // Get last app open time
  Future<DateTime?> getLastOpenTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastOpenTimeKey);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  // Fetch SMS messages based on app open status
  Future<List<SmsMessage>> getRelevantSms() async {
    final permission = await requestSmsPermission();
    if (!permission) {
      return [];
    }

    // Get all SMS messages
    _messages = await _query.getAllSms;

    // Check if this is first app open
    final firstOpen = await isFirstOpen();

    if (firstOpen) {
      // First time open: Get last 7 transactions
      debugPrint('First app open - fetching last 7 financial messages');
      return getLastNFinancialMessages(7);
    } else {
      // Subsequent open: Get messages since last open
      final lastOpenTime = await getLastOpenTime();
      if (lastOpenTime == null) {
        // Fallback if somehow we have no lastOpenTime but it's not first open
        return getLastNFinancialMessages(7);
      }

      debugPrint('Fetching messages since last open: ${lastOpenTime.toString()}');
      return getMessagesSinceTime(lastOpenTime);
    }
  }

  // Get the last N financial messages
  List<SmsMessage> getLastNFinancialMessages(int count) {
    // Filter financial messages
    final financialMessages = _messages.where((message) =>
        isFinancialMessage(message.sender ?? '', message.body ?? '')
    ).toList();

    // Sort by date (newest first)
    financialMessages.sort((a, b) =>
        (b.date ?? DateTime.now()).compareTo(a.date ?? DateTime.now())
    );

    // Return the last N messages (or all if less than N)
    return financialMessages.take(count).toList();
  }

  // Get messages since a specific time
  List<SmsMessage> getMessagesSinceTime(DateTime sinceTime) {
    return _messages.where((message) =>
    message.date != null &&
        message.date!.isAfter(sinceTime) &&
        isFinancialMessage(message.sender ?? '', message.body ?? '')
    ).toList();
  }

  // Parse SMS for transactions
  Future<List<Transactions>> parseTransactionsFromSms() async {
    try {
      List<Transactions> parsedTransactions = [];
      final messages = await getRelevantSms();

      // Get existing transactions to check for duplicates
      final existingTransactions = await TransactionDatabase.instance.readAllTransactions();

      for (var message in messages) {
        final transaction = parseMessageToTransaction(message);
        if (transaction != null) {
          // Check if this transaction already exists in the database
          if (!isDuplicate(transaction, existingTransactions)) {
            parsedTransactions.add(transaction);
            await TransactionDatabase.instance.create(transaction);
          } else {
            debugPrint('Skipping duplicate transaction: ${transaction.title} - ${transaction.amount}');
          }
        }
      }

      // Save current time as last open time
      await saveOpenTime();

      return parsedTransactions;
    } catch (e) {
      debugPrint('Error parsing SMS: $e');
      return [];
    }
  }

  // Check if a transaction is a duplicate
  bool isDuplicate(Transactions newTransaction, List<Transactions> existingTransactions) {
    return existingTransactions.any((existing) =>
    // Check if same amount
    existing.amount == newTransaction.amount &&
        // Check if same date (comparing only year, month, day)
        existing.date.year == newTransaction.date.year &&
        existing.date.month == newTransaction.date.month &&
        existing.date.day == newTransaction.date.day &&
        // Check if same title
        existing.title == newTransaction.title &&
        // Check if same transaction type (expense/income)
        existing.isExpense == newTransaction.isExpense
    );
  }

  // Logic to parse message to transaction
  Transactions? parseMessageToTransaction(SmsMessage message) {
    final String body = message.body ?? '';
    final String sender = message.sender ?? '';

    // Check if the message is from a bank or payment service
    if (!isFinancialMessage(sender, body)) {
      return null;
    }

    // Parse amount
    final double? amount = extractAmount(body);
    if (amount == null) {
      return null;
    }

    // Determine if it's an expense or income
    final bool isExpense = determineTransactionType(body);

    // Extract title/description
    final String title = extractDescription(body, sender);

    // Determine category
    final String category = determineCategory(body, title);

    return Transactions(
      title: title,
      amount: amount,
      date: message.date ?? DateTime.now(),
      category: category,
      isExpense: isExpense,
      source: 'auto',
    );
  }

  bool isFinancialMessage(String sender, String body) {
    // Common financial message senders and keywords
    List<String> financialSenders = [
      'HDFC', 'SBI', 'ICICI', 'AXIS', 'HSBC', 'Citibank', 'BOA', 'Chase',
      'PayPal', 'Venmo', 'PayTM', 'PhonePe', 'GooglePay', 'GPay', 'UPI',
      'Bank', 'Credit', 'Account'
    ];

    List<String> financialKeywords = [
      'debited', 'credited', 'transaction', 'spent', 'received',
      'payment', 'transfer', 'balance', 'paid', 'deposited',
      'withdraw', 'purchase', 'sent', 'account', 'debit', 'credit'
    ];

    // Check if the sender contains any financial institution name
    if (financialSenders.any((bank) =>
        sender.toLowerCase().contains(bank.toLowerCase()))) {
      return true;
    }

    // Check if the body contains financial keywords
    if (financialKeywords.any((keyword) =>
        body.toLowerCase().contains(keyword.toLowerCase()))) {
      return true;
    }

    return false;
  }

  double? extractAmount(String body) {
    // Look for currency symbols or INR/USD followed by numbers
    RegExp amountRegex = RegExp(r'(?:Rs\.?|INR|₹|\$|USD)\s?(\d+(:?\,\d+)*(:?\.\d+)?)');
    var match = amountRegex.firstMatch(body);

    if (match != null) {
      String amountStr = match.group(1) ?? '';
      // Remove commas
      amountStr = amountStr.replaceAll(',', '');
      return double.tryParse(amountStr);
    }

    // Try to find numbers preceded by words like "amount", "rs", etc.
    RegExp wordAmountRegex = RegExp(
        r'(?:amount|amt|rs|inr|usd)\.?\s?(\d+(:?\,\d+)*(:?\.\d+)?)',
        caseSensitive: false);
    match = wordAmountRegex.firstMatch(body);

    if (match != null) {
      String amountStr = match.group(1) ?? '';
      amountStr = amountStr.replaceAll(',', '');
      return double.tryParse(amountStr);
    }

    return null;
  }

  bool determineTransactionType(String body) {
    List<String> expenseKeywords = [
      'debited', 'spent', 'paid', 'purchase', 'payment', 'debit', 'sent',
      'withdraw', 'transferred'
    ];

    List<String> incomeKeywords = [
      'credited', 'received', 'deposited', 'credit', 'income', 'refund',
      'cashback', 'reward'
    ];

    // Default to expense if unclear
    bool isExpense = true;

    for (var keyword in expenseKeywords) {
      if (body.toLowerCase().contains(keyword.toLowerCase())) {
        isExpense = true;
        break;
      }
    }

    for (var keyword in incomeKeywords) {
      if (body.toLowerCase().contains(keyword.toLowerCase())) {
        isExpense = false;
        break;
      }
    }

    return isExpense;
  }

  String extractDescription(String body, String sender) {
    // Try to find merchant/vendor name
    RegExp merchantRegex = RegExp(r'(?:at|to|from)\s+([A-Za-z0-9\s&]+)(?:on|for|via|using)',
        caseSensitive: false);
    var match = merchantRegex.firstMatch(body);

    if (match != null) {
      return match.group(1)?.trim() ?? 'Unknown';
    }

    // If no merchant found, return a default with the sender
    return 'Transaction via ${sender.trim()}';
  }

  String determineCategory(String body, String title) {
    Map<String, List<String>> categoryKeywords = {
      'Food': ['restaurant', 'food', 'dining', 'cafe', 'meal', 'lunch', 'dinner', 'breakfast'],
      'Shopping': ['shop', 'store', 'mart', 'market', 'purchase', 'buy', 'mall'],
      'Transport': ['uber', 'ola', 'taxi', 'cab', 'auto', 'transport', 'travel', 'fuel', 'gas', 'petrol'],
      'Bills': ['bill', 'recharge', 'electricity', 'water', 'gas', 'utility', 'phone', 'mobile'],
      'Entertainment': ['movie', 'cinema', 'theatre', 'show', 'event', 'concert', 'netflix', 'amazon prime'],
      'Health': ['medical', 'doctor', 'hospital', 'pharmacy', 'medicine', 'healthcare'],
      'Education': ['school', 'college', 'university', 'tuition', 'course', 'class', 'education'],
      'Salary': ['salary', 'income', 'payday'],
      'Transfer': ['transfer', 'sent to', 'received from']
    };

    // Check title and body for category keywords
    String lowerBody = body.toLowerCase();
    String lowerTitle = title.toLowerCase();

    for (var category in categoryKeywords.keys) {
      for (var keyword in categoryKeywords[category]!) {
        if (lowerBody.contains(keyword) || lowerTitle.contains(keyword)) {
          return category;
        }
      }
    }

    // Default category
    return 'Others';
  }
}