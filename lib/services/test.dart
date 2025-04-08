// import 'package:flutter/foundation.dart';
// import 'package:flutter_sms_inbox/flutter_sms_inbox.dart' as sms_inbox;
// import 'package:telephony/telephony.dart' as telephony;
// import 'package:intl/intl.dart';
// import 'package:permission_handler/permission_handler.dart';
// import '../models/transaction.dart';
// import '../database/transaction_database.dart';
//
// class SmsParserService {
//   final sms_inbox.SmsQuery _query = sms_inbox.SmsQuery();
//   List<sms_inbox.SmsMessage> _messages = [];
//   // Telephony instance for listening to SMS
//   final telephony.Telephony telephonyInstance = telephony.Telephony.instance;
//
//   // Constructor to initialize SMS listener
//   SmsParserService() {
//     initSmsListener();
//   }
//
//   // Initialize SMS listener
//   Future<void> initSmsListener() async {
//     final bool? result = await telephonyInstance.requestPhoneAndSmsPermissions;
//
//     if (result != null && result) {
//       telephonyInstance.listenIncomingSms(
//         onNewMessage: onSmsReceived,
//         onBackgroundMessage: onBackgroundSmsReceived,
//       );
//       debugPrint('SMS listener initialized successfully');
//     } else {
//       debugPrint('Failed to get SMS permission for listener');
//     }
//   }
//
//   // Handle SMS received in foreground
//   void onSmsReceived(telephony.SmsMessage message) async {
//     debugPrint('New SMS received: ${message.body}');
//     // Convert telephony.SmsMessage to equivalent format for processing
//     final convertedMessage = sms_inbox.SmsMessage.fromJson({
//       'address': message.address,
//       'body': message.body,
//       'date': message.date != null ? message.date.toString() : DateTime.now().millisecondsSinceEpoch.toString(),
//       'read': message.read ?? false,
//       '_id': message.id ?? '0',
//       'sender': message.address,
//     });
//     // Process the message
//     await processNewMessage(convertedMessage);
//   }
//
//   // Process newly received message
//   Future<void> processNewMessage(sms_inbox.SmsMessage message) async {
//     final transaction = parseMessageToTransaction(message);
//     if (transaction != null) {
//       await TransactionDatabase.instance.create(transaction);
//       debugPrint('New transaction added: ${transaction.title} - ${transaction.amount}');
//     }
//   }
//
//   // Request SMS permission
//   Future<bool> requestSmsPermission() async {
//     final status = await Permission.sms.request();
//     return status.isGranted;
//   }
//
//   // Fetch all SMS messages
//   Future<List<sms_inbox.SmsMessage>> getAllSms() async {
//     final permission = await requestSmsPermission();
//     if (!permission) {
//       return [];
//     }
//
//     _messages = await _query.getAllSms;
//     return _messages;
//   }
//
//   // Parse SMS for transactions
//   Future<List<Transactions>> parseTransactionsFromSms() async {
//     try {
//       List<Transactions> parsedTransactions = [];
//       final messages = await getAllSms();
//
//       // Get today's date to compare
//       DateTime today = DateTime.now();
//       String formattedDate = DateFormat('yyyy-MM-dd').format(today); // Format as 'YYYY-MM-DD'
//
//       for (var message in messages) {
//         // Check if the message is from today
//         DateTime messageDate = message.date ?? DateTime.now();
//         String messageDateString = DateFormat('yyyy-MM-dd').format(messageDate);
//
//         // Only parse if the message is from today
//         if (messageDateString == formattedDate) {
//           final transaction = parseMessageToTransaction(message);
//           if (transaction != null) {
//             parsedTransactions.add(transaction);
//             await TransactionDatabase.instance.create(transaction);
//           }
//         }
//       }
//
//       return parsedTransactions;
//     } catch (e) {
//       debugPrint('Error parsing SMS: $e');
//       return [];
//     }
//   }
//
//   // Logic to parse message to transaction
//   Transactions? parseMessageToTransaction(sms_inbox.SmsMessage message) {
//     final String body = message.body ?? '';
//     final String sender = message.sender ?? '';
//
//     // Check if the message is from a bank or payment service
//     if (!isFinancialMessage(sender, body)) {
//       return null;
//     }
//
//     // Parse amount
//     final double? amount = extractAmount(body);
//     if (amount == null) {
//       return null;
//     }
//
//     // Determine if it's an expense or income
//     final bool isExpense = determineTransactionType(body);
//
//     // Extract title/description
//     final String title = extractDescription(body, sender);
//
//     // Determine category
//     final String category = determineCategory(body, title);
//
//     return Transactions(
//       title: title,
//       amount: amount,
//       date: message.date ?? DateTime.now(),
//       category: category,
//       isExpense: isExpense,
//       source: 'auto',
//     );
//   }
//
//   bool isFinancialMessage(String sender, String body) {
//     // Common financial message senders and keywords
//     List<String> financialSenders = [
//       'HDFC', 'SBI', 'ICICI', 'AXIS', 'HSBC', 'Citibank', 'BOA', 'Chase',
//       'PayPal', 'Venmo', 'PayTM', 'PhonePe', 'GooglePay', 'GPay', 'UPI',
//       'Bank', 'Credit', 'Account'
//     ];
//
//     List<String> financialKeywords = [
//       'debited', 'credited', 'transaction', 'spent', 'received',
//       'payment', 'transfer', 'balance', 'paid', 'deposited',
//       'withdraw', 'purchase', 'sent', 'account', 'debit', 'credit'
//     ];
//
//     // Check if the sender contains any financial institution name
//     if (financialSenders.any((bank) =>
//         sender.toLowerCase().contains(bank.toLowerCase()))) {
//       return true;
//     }
//
//     // Check if the body contains financial keywords
//     if (financialKeywords.any((keyword) =>
//         body.toLowerCase().contains(keyword.toLowerCase()))) {
//       return true;
//     }
//
//     return false;
//   }
//
//   double? extractAmount(String body) {
//     // Look for currency symbols or INR/USD followed by numbers
//     RegExp amountRegex = RegExp(r'(?:Rs\.?|INR|₹|\$|USD)\s?(\d+(:?\,\d+)*(:?\.\d+)?)');
//     var match = amountRegex.firstMatch(body);
//
//     if (match != null) {
//       String amountStr = match.group(1) ?? '';
//       // Remove commas
//       amountStr = amountStr.replaceAll(',', '');
//       return double.tryParse(amountStr);
//     }
//
//     // Try to find numbers preceded by words like "amount", "rs", etc.
//     RegExp wordAmountRegex = RegExp(
//         r'(?:amount|amt|rs|inr|usd)\.?\s?(\d+(:?\,\d+)*(:?\.\d+)?)',
//         caseSensitive: false);
//     match = wordAmountRegex.firstMatch(body);
//
//     if (match != null) {
//       String amountStr = match.group(1) ?? '';
//       amountStr = amountStr.replaceAll(',', '');
//       return double.tryParse(amountStr);
//     }
//
//     return null;
//   }
//
//   bool determineTransactionType(String body) {
//     List<String> expenseKeywords = [
//       'debited', 'spent', 'paid', 'purchase', 'payment', 'debit', 'sent',
//       'withdraw', 'transferred'
//     ];
//
//     List<String> incomeKeywords = [
//       'credited', 'received', 'deposited', 'credit', 'income', 'refund',
//       'cashback', 'reward'
//     ];
//
//     // Default to expense if unclear
//     bool isExpense = true;
//
//     for (var keyword in expenseKeywords) {
//       if (body.toLowerCase().contains(keyword.toLowerCase())) {
//         isExpense = true;
//         break;
//       }
//     }
//
//     for (var keyword in incomeKeywords) {
//       if (body.toLowerCase().contains(keyword.toLowerCase())) {
//         isExpense = false;
//         break;
//       }
//     }
//
//     return isExpense;
//   }
//
//   String extractDescription(String body, String sender) {
//     // Try to find merchant/vendor name
//     RegExp merchantRegex = RegExp(r'(?:at|to|from)\s+([A-Za-z0-9\s&]+)(?:on|for|via|using)',
//         caseSensitive: false);
//     var match = merchantRegex.firstMatch(body);
//
//     if (match != null) {
//       return match.group(1)?.trim() ?? 'Unknown';
//     }
//
//     // If no merchant found, return a default with the sender
//     return 'Transaction via ${sender.trim()}';
//   }
//
//   String determineCategory(String body, String title) {
//     Map<String, List<String>> categoryKeywords = {
//       'Food': ['restaurant', 'food', 'dining', 'cafe', 'meal', 'lunch', 'dinner', 'breakfast'],
//       'Shopping': ['shop', 'store', 'mart', 'market', 'purchase', 'buy', 'mall'],
//       'Transport': ['uber', 'ola', 'taxi', 'cab', 'auto', 'transport', 'travel', 'fuel', 'gas', 'petrol'],
//       'Bills': ['bill', 'recharge', 'electricity', 'water', 'gas', 'utility', 'phone', 'mobile'],
//       'Entertainment': ['movie', 'cinema', 'theatre', 'show', 'event', 'concert', 'netflix', 'amazon prime'],
//       'Health': ['medical', 'doctor', 'hospital', 'pharmacy', 'medicine', 'healthcare'],
//       'Education': ['school', 'college', 'university', 'tuition', 'course', 'class', 'education'],
//       'Salary': ['salary', 'income', 'payday'],
//       'Transfer': ['transfer', 'sent to', 'received from']
//     };
//
//     // Check title and body for category keywords
//     String lowerBody = body.toLowerCase();
//     String lowerTitle = title.toLowerCase();
//
//     for (var category in categoryKeywords.keys) {
//       for (var keyword in categoryKeywords[category]!) {
//         if (lowerBody.contains(keyword) || lowerTitle.contains(keyword)) {
//           return category;
//         }
//       }
//     }
//
//     // Default category
//     return 'Others';
//   }
// }
//
// // Background message handler - must be a top-level function
// @pragma('vm:entry-point')
// void onBackgroundSmsReceived(telephony.SmsMessage message) async {
//   // Note: This can't directly use class methods as it's a top-level function
//   // You may need to implement simplified processing here or use a background service pattern
//   debugPrint('SMS received in background: ${message.body}');
//
//   // For simple cases, you could re-implement basic parsing logic here
//   // Or use a method channel to communicate with your service
//   // This depends on your app architecture
// }