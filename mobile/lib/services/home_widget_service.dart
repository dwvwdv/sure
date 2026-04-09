import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../models/account.dart';
import '../models/transaction.dart';

/// Service responsible for updating the home screen calendar widget
/// with the latest financial data from the app.
///
/// SharedPrefs schema (read by CalendarWidgetProvider):
///   widget_account_list  → "Name:id|Name2:id2"
///   widget_currency      → "TWD"
///   widget_days_{accountId}_{YYYY-MM} → "01:-110|04:-30|15:820"
class HomeWidgetService {
  static const String _appGroupId = 'group.am.sure.mobile';
  static const String _androidWidgetName = 'CalendarWidgetProvider';
  static const String _iOSWidgetName = 'CalendarWidget';

  static HomeWidgetService? _instance;
  HomeWidgetService._();
  static HomeWidgetService get instance => _instance ??= HomeWidgetService._();

  Future<void> initialize() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  /// Update widget with account list (for navigation) and currency.
  /// Call this after accounts are fetched.
  Future<void> updateAccounts({required List<Account> accounts}) async {
    if (accounts.isEmpty) return;
    try {
      // Build "Name:id|Name2:id2" list (all accounts for cycling)
      final accountList = accounts
          .map((a) => '${a.name}:${a.id}')
          .join('|');

      final primaryCurrency = accounts.firstWhere(
        (a) => a.isAsset,
        orElse: () => accounts.first,
      ).currency;

      await HomeWidget.saveWidgetData<String>('widget_account_list', accountList);
      await HomeWidget.saveWidgetData<String>('widget_currency', primaryCurrency);

      await _triggerUpdate();
    } catch (_) {}
  }

  /// Update widget with daily transaction amounts for a specific account + month.
  /// Call this after transactions are fetched for an account.
  Future<void> updateTransactions({
    required String accountId,
    required List<Transaction> transactions,
    required bool isAsset,
  }) async {
    if (transactions.isEmpty) return;
    try {
      // Group transactions by month, then by day
      final monthMap = <String, Map<int, double>>{};

      for (final tx in transactions) {
        try {
          final date = DateTime.parse(tx.date);
          final monthKey = DateFormat('yyyy-MM').format(date);
          final day = date.day;

          // Parse amount (mirrors CalendarScreen._calculateDailyChanges logic)
          String trimmed = tx.amount.trim().replaceAll('\u2212', '-');
          final hasNeg = trimmed.startsWith('-') || trimmed.endsWith('-');
          final numeric = trimmed.replaceAll(RegExp(r'[^\d.\-]'), '');
          double amount = double.tryParse(numeric.replaceAll('-', '')) ?? 0.0;
          if (hasNeg) amount = -amount;
          if (isAsset) amount = -amount; // flip sign for asset/liability accounts

          monthMap.putIfAbsent(monthKey, () => {});
          monthMap[monthKey]![day] = (monthMap[monthKey]![day] ?? 0.0) + amount;
        } catch (_) {}
      }

      // Save each month's data: "01:-110|04:-30|15:820"
      for (final entry in monthMap.entries) {
        final monthKey = entry.key;
        final daysData = entry.value.entries
            .map((e) => '${e.key.toString().padLeft(2, '0')}:${e.value}')
            .join('|');
        await HomeWidget.saveWidgetData<String>(
          'widget_days_${accountId}_$monthKey',
          daysData,
        );
      }

      await _triggerUpdate();
    } catch (_) {}
  }

  Future<void> _triggerUpdate() async {
    await HomeWidget.updateWidget(
      androidName: _androidWidgetName,
      iOSName: _iOSWidgetName,
      qualifiedAndroidName: 'am.sure.mobile.$_androidWidgetName',
    );
  }
}
