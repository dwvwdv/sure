class Transaction {
  final String id;
  final String accountId;
  final String name;
  final String date;
  final double amount;
  final String currency;
  final String nature; // 'expense' or 'income'

  Transaction({
    required this.id,
    required this.accountId,
    required this.name,
    required this.date,
    required this.amount,
    required this.currency,
    required this.nature,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'].toString(),
      accountId: json['account_id'].toString(),
      name: json['name'] as String,
      date: json['date'] as String,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'USD',
      nature: json['nature'] as String? ?? 'expense',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'name': name,
      'date': date,
      'amount': amount,
      'currency': currency,
      'nature': nature,
    };
  }

  bool get isExpense => nature == 'expense';
  bool get isIncome => nature == 'income';

  String get formattedAmount {
    final symbol = _getCurrencySymbol();
    final sign = isExpense ? '-' : '+';
    return '$sign$symbol${amount.toStringAsFixed(2)}';
  }

  String _getCurrencySymbol() {
    switch (currency.toUpperCase()) {
      case 'USD':
        return '\$';
      case 'TWD':
        return '\$';
      case 'AUD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'JPY':
        return '¥';
      case 'CNY':
        return '¥';
      default:
        return '';
    }
  }
}
