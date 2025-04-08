import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'database/transaction_database.dart';
import 'models/transaction.dart';
import 'providers/transaction_provider.dart';
import 'screens/home_screen.dart';
import 'services/sm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TransactionDatabase.instance.database;
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SMS background service
  await
  SmsServiceInitializer.initializeServices();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => TransactionProvider(),
      child: MaterialApp(
        title: 'Expense Tracker',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}