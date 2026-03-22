import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import 'log_service.dart';

/// Service responsible for updating home screen widget data.
/// Shares transaction and account data with the native Android widget
/// via SharedPreferences so users can interact with the widget on
/// their home screen (switch accounts, navigate months).
class WidgetService {
  static const String _appGroupId = 'group.am.sure.mobile.widget';
  static const String _androidWidgetName = 'CalendarWidgetProvider';

  static final LogService _log = LogService.instance;

  static Future<void> initialize() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  /// Store the account list so the widget can cycle through accounts.
  static Future<void> updateAccountList(List<Account> accounts) async {
    try {
      final accountList = accounts
          .map((a) => {
                'id': a.id,
                'name': a.name,
                'currency': a.currency,
                'classification': a.classification ?? '',
              })
          .toList();

      await HomeWidget.saveWidgetData(
          'widget_accounts', jsonEncode(accountList));
      await HomeWidget.saveWidgetData(
          'widget_account_count', accounts.length);

      await HomeWidget.updateWidget(androidName: _androidWidgetName);

      _log.info(
          'WidgetService', 'Account list updated: ${accounts.length} accounts');
    } catch (e) {
      _log.error('WidgetService', 'Failed to update account list: $e');
    }
  }

  /// Update the calendar widget with transaction data for a specific account.
  /// Stores daily totals keyed by account ID so switching accounts on the
  /// widget can display each account's data independently.
  static Future<void> updateCalendarWidget({
    required List<Transaction> transactions,
    required String accountId,
    String? accountName,
    String? currency,
  }) async {
    try {
      // Calculate daily totals for ALL dates (widget filters by month)
      final dailyTotals = <String, double>{};

      for (var transaction in transactions) {
        try {
          final date = DateTime.parse(transaction.date);
          final dateKey = DateFormat('yyyy-MM-dd').format(date);

          String trimmedAmount = transaction.amount.trim();
          trimmedAmount = trimmedAmount.replaceAll('\u2212', '-');
          bool hasNegativeSign =
              trimmedAmount.startsWith('-') || trimmedAmount.endsWith('-');

          String numericString =
              trimmedAmount.replaceAll(RegExp(r'[^\d.\-]'), '');
          double amount =
              double.tryParse(numericString.replaceAll('-', '')) ?? 0.0;

          if (hasNegativeSign) {
            amount = -amount;
          }

          // Flip sign for accounting convention
          amount = -amount;

          dailyTotals[dateKey] = (dailyTotals[dateKey] ?? 0.0) + amount;
        } catch (e) {
          _log.error('WidgetService',
              'Failed to parse transaction: ${transaction.date}, error: $e');
        }
      }

      // Read existing per-account data map, update this account's entry
      final existingJson =
          await HomeWidget.getWidgetData<String>('widget_all_daily_totals');
      Map<String, dynamic> allAccountTotals = {};
      if (existingJson != null) {
        try {
          allAccountTotals =
              Map<String, dynamic>.from(jsonDecode(existingJson));
        } catch (_) {}
      }

      allAccountTotals[accountId] = dailyTotals;

      await HomeWidget.saveWidgetData(
          'widget_all_daily_totals', jsonEncode(allAccountTotals));
      await HomeWidget.saveWidgetData(
          'widget_last_updated', DateTime.now().toIso8601String());

      await HomeWidget.updateWidget(androidName: _androidWidgetName);

      _log.info('WidgetService',
          'Calendar widget updated: ${dailyTotals.length} days for account $accountId ($accountName)');
    } catch (e) {
      _log.error('WidgetService', 'Failed to update calendar widget: $e');
    }
  }

  /// Clear widget data (e.g., on logout).
  static Future<void> clearWidgetData() async {
    try {
      await HomeWidget.saveWidgetData('widget_accounts', null);
      await HomeWidget.saveWidgetData('widget_account_count', null);
      await HomeWidget.saveWidgetData('widget_all_daily_totals', null);
      await HomeWidget.saveWidgetData('widget_last_updated', null);
      await HomeWidget.saveWidgetData('widget_selected_account_index', null);
      await HomeWidget.saveWidgetData('widget_view_year', null);
      await HomeWidget.saveWidgetData('widget_view_month', null);

      await HomeWidget.updateWidget(androidName: _androidWidgetName);

      _log.info('WidgetService', 'Widget data cleared');
    } catch (e) {
      _log.error('WidgetService', 'Failed to clear widget data: $e');
    }
  }
}
