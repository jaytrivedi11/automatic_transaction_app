import 'package:flutter/foundation.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/transaction.dart';
import '../database/transaction_database.dart';
import 'package:telephony/telephony.dart' as tele_phonye;

class SmsParserService {
  final SmsQuery _query = SmsQuery();
  List<SmsMessage> _messages = [];
  final tele_phonye.Telephony telephony = tele_phonye.Telephony.instance;

  // Request SMS permission
  Future<bool> requestSmsPermission() async {
    final status = await Permission.sms.request();

    // Also request notification permission for background service
    await Permission.notification.request();

    return status.isGranted;
  }

  // Fetch all SMS messages
  Future<List<SmsMessage>> getAllSms() async {
    final permission = await requestSmsPermission();
    if (!permission) {
      return [];
    }

    _messages = await _query.getAllSms;
    return _messages;
  }

  // Parse SMS for transactions from today
  Future<List<Transactions>> parseTransactionsFromSms() async {
    try {
      List<Transactions> parsedTransactions = [];
      final messages = await getAllSms();

      // Get today's date to compare
      DateTime today = DateTime.now();
      String formattedDate = DateFormat('yyyy-MM-dd').format(today); // Format as 'YYYY-MM-DD'

      for (var message in messages) {
        // Check if the message is from today
        DateTime messageDate = message.date ?? DateTime.now();
        String messageDateString = DateFormat('yyyy-MM-dd').format(messageDate);

        // Only parse if the message is from today
        if (messageDateString == formattedDate) {
          final transaction = parseMessageToTransaction(message);
          if (transaction != null) {
            parsedTransactions.add(transaction);
            await TransactionDatabase.instance.create(transaction);
          }
        }
      }

      return parsedTransactions;
    } catch (e) {
      debugPrint('Error parsing SMS: $e');
      return [];
    }
  }

  // Initialize the background service to listen for SMS
  Future<void> initSmsListenerService() async {
    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'sms_parser_channel', // id
      'SMS Transaction Parser', // title
      description: 'Listens for financial SMS messages', // description
      importance: Importance.high,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'sms_parser_channel',
        initialNotificationTitle: 'SMS Transaction Parser',
        initialNotificationContent: 'Running in background',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    // Register SMS listener using telephony package
    await registerSmsListener();
  }

  // Register SMS listener using the telephony package
  Future<void> registerSmsListener() async {
    final bool? result = await telephony.requestPhoneAndSmsPermissions;

    if (result != null && result) {
      telephony.listenIncomingSms(
        onNewMessage: (tele_phonye.SmsMessage message) {
          _processIncomingSms(message);
        },
        onBackgroundMessage: backgroundMessageHandler,
      );
      debugPrint('SMS listener registered successfully');
    } else {
      debugPrint('SMS permission denied');
    }
  }

  // Process incoming SMS messages
  void _processIncomingSms(tele_phonye.SmsMessage message) async {
    // We need to process the telephony SmsMessage directly
    // Rather than trying to convert it to flutter_sms_inbox.SmsMessage
    final transaction = _parseTelephonySmsToTransaction(message);
    if (transaction != null) {
      await TransactionDatabase.instance.create(transaction);
      debugPrint('Transaction added from incoming SMS: ${transaction.title}');
    }
  }

  // Parse telephony SmsMessage to transaction
  Transactions? _parseTelephonySmsToTransaction(tele_phonye.SmsMessage message) {
    final String body = message.body ?? '';
    final String sender = message.address ?? '';

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
      date: DateTime.now(), // Use current time as telephony message doesn't have date
      category: category,
      isExpense: isExpense,
      source: 'auto',
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

// Background handler for SMS messages (outside the class)
@pragma('vm:entry-point')
void backgroundMessageHandler(tele_phonye.SmsMessage message) async {
  // Create a instance just for processing this message
  final smsParser = SmsParserService();

  // Process the message directly with a new method that handles telephony.SmsMessage
  final transaction = smsParser._parseTelephonySmsToTransaction(message);
  if (transaction != null) {
    await TransactionDatabase.instance.create(transaction);
  }
}

// Background service main function
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // This function will be called when the service is started

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Keep the service alive
  debugPrint('Background service started');
}

// iOS background processing
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}