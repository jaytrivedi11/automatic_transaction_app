class Transactions {
  final int? id;
  final String title;
  final double amount;
  final DateTime date;
  final String category;
  final bool isExpense;
  final String? source; // 'manual' or 'auto'

  Transactions({
    this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    required this.isExpense,
    this.source = 'manual',
  });

  Transactions copy({
    int? id,
    String? title,
    double? amount,
    DateTime? date,
    String? category,
    bool? isExpense,
    String? source,
  }) =>
      Transactions(
        id: id ?? this.id,
        title: title ?? this.title,
        amount: amount ?? this.amount,
        date: date ?? this.date,
        category: category ?? this.category,
        isExpense: isExpense ?? this.isExpense,
        source: source ?? this.source,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'amount': amount,
    'date': date.toIso8601String(),
    'category': category,
    'isExpense': isExpense ? 1 : 0,
    'source': source,
  };

  static Transactions fromJson(Map<String, dynamic> json) => Transactions(
    id: json['id'] as int?,
    title: json['title'] as String,
    amount: json['amount'] as double,
    date: DateTime.parse(json['date'] as String),
    category: json['category'] as String,
    isExpense: json['isExpense'] == 1,
    source: json['source'] as String?,
  );
}