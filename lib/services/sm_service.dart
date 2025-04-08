import 'package:flutter/material.dart';
import '../services/sms_parser_service.dart';

class SmsServiceInitializer {
  static Future<void> initializeServices() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize the SMS parser service
    final smsParserService = SmsParserService();
    await smsParserService.requestSmsPermission();

    // Initialize background service for SMS listening
    await smsParserService.initSmsListenerService();

    debugPrint('SMS service initialized successfully');
  }
}