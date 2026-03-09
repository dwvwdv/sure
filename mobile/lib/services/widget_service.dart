import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import 'log_service.dart';

/// Service responsible for updating home screen widget data.
/// Shares transaction data with native Android/iOS widgets via SharedPreferences.
class WidgetService {
  static const String _appGroupId = 'group.am.sure.mobile.widget';
  static const String _androidWidgetName = 'CalendarWidgetProvider';
  static const String _iOSWidgetName = 'SureCalendarWidget';

  static final LogService _log = LogService.instance;

  /// Initialize home widget configuration.
  static Future<void> initialize() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  /// Update the calendar widget with transaction data for the current month.
  static Future<void> updateCalendarWidget({
    required List<Transaction> transactions,
    String? accountName,
    String? currency,
  }) async {
    try {
      final now = DateTime.now();
      final yearMonth = DateFormat('yyyy-MM').format(now);
      final year = now.year;
      final month = now.month;

      // Calculate daily totals for the current month
      final dailyTotals = <String, double>{};
      double monthlyTotal = 0.0;

      for (var transaction in transactions) {
        try {
          final date = DateTime.parse(transaction.date);
          final dateKey = DateFormat('yyyy-MM-dd').format(date);

          if (!dateKey.startsWith(yearMonth)) continue;

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
          monthlyTotal += amount;
        } catch (e) {
          _log.error('WidgetService',
              'Failed to parse transaction: ${transaction.date}, error: $e');
        }
      }

      // Store data for native widgets
      await HomeWidget.saveWidgetData('widget_year', year);
      await HomeWidget.saveWidgetData('widget_month', month);
      await HomeWidget.saveWidgetData(
          'widget_account_name', accountName ?? 'All Accounts');
      await HomeWidget.saveWidgetData('widget_currency', currency ?? '');
      await HomeWidget.saveWidgetData(
          'widget_monthly_total', monthlyTotal.toStringAsFixed(2));
      await HomeWidget.saveWidgetData(
          'widget_daily_totals', jsonEncode(dailyTotals));
      await HomeWidget.saveWidgetData(
          'widget_last_updated', DateTime.now().toIso8601String());

      // Trigger widget update on both platforms
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        iOSName: _iOSWidgetName,
      );

      _log.info('WidgetService',
          'Calendar widget updated: ${dailyTotals.length} days, total: $monthlyTotal');
    } catch (e) {
      _log.error('WidgetService', 'Failed to update calendar widget: $e');
    }
  }

  /// Clear widget data (e.g., on logout).
  static Future<void> clearWidgetData() async {
    try {
      await HomeWidget.saveWidgetData('widget_year', null);
      await HomeWidget.saveWidgetData('widget_month', null);
      await HomeWidget.saveWidgetData('widget_account_name', null);
      await HomeWidget.saveWidgetData('widget_currency', null);
      await HomeWidget.saveWidgetData('widget_monthly_total', null);
      await HomeWidget.saveWidgetData('widget_daily_totals', null);
      await HomeWidget.saveWidgetData('widget_last_updated', null);

      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        iOSName: _iOSWidgetName,
      );

      _log.info('WidgetService', 'Widget data cleared');
    } catch (e) {
      _log.error('WidgetService', 'Failed to clear widget data: $e');
    }
  }
}
