import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../models/account.dart';

/// Service responsible for updating the home screen calendar widget
/// with the latest financial data from the app.
class HomeWidgetService {
  static const String _appGroupId = 'group.am.sure.mobile';
  static const String _androidWidgetName = 'CalendarWidgetProvider';
  static const String _iOSWidgetName = 'CalendarWidget';

  static const String _keyDate = 'widget_date';
  static const String _keyMonth = 'widget_month';
  static const String _keyNetWorth = 'widget_net_worth';
  static const String _keyNetWorthLabel = 'widget_net_worth_label';
  static const String _keyUpdatedAt = 'widget_updated_at';

  static HomeWidgetService? _instance;
  HomeWidgetService._();
  static HomeWidgetService get instance => _instance ??= HomeWidgetService._();

  Future<void> initialize() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  /// Update the home screen widget with the latest account data.
  Future<void> updateWidget({required List<Account> accounts}) async {
    try {
      final now = DateTime.now();
      final dateFormatter = DateFormat('d');
      final monthFormatter = DateFormat('MMMM yyyy');
      final updatedFormatter = DateFormat('HH:mm');

      // Calculate net worth (assets - liabilities)
      double totalAssets = 0;
      double totalLiabilities = 0;
      String primaryCurrency = 'USD';

      for (final account in accounts) {
        if (account.isAsset) {
          totalAssets += account.balanceAsDouble;
          primaryCurrency = account.currency;
        } else if (account.isLiability) {
          totalLiabilities += account.balanceAsDouble;
        }
      }

      final netWorth = totalAssets - totalLiabilities;
      final netWorthFormatted = _formatAmount(netWorth, primaryCurrency);

      // Save data for the widget
      await HomeWidget.saveWidgetData<String>(_keyDate, dateFormatter.format(now));
      await HomeWidget.saveWidgetData<String>(_keyMonth, monthFormatter.format(now));
      await HomeWidget.saveWidgetData<String>(_keyNetWorth, netWorthFormatted);
      await HomeWidget.saveWidgetData<String>(_keyNetWorthLabel, 'Net Worth');
      await HomeWidget.saveWidgetData<String>(
        _keyUpdatedAt,
        'Updated ${updatedFormatter.format(now)}',
      );

      // Trigger native widget refresh
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        iOSName: _iOSWidgetName,
        qualifiedAndroidName: 'am.sure.mobile.$_androidWidgetName',
      );
    } catch (e) {
      // Widget update is non-critical; ignore errors silently
    }
  }

  String _formatAmount(double amount, String currency) {
    final symbol = _currencySymbol(currency);
    final formatted = NumberFormat('#,##0.00').format(amount.abs());
    final sign = amount < 0 ? '-' : '';
    return '$sign$symbol$formatted';
  }

  String _currencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'USD':
      case 'TWD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'JPY':
      case 'CNY':
        return '¥';
      case 'BTC':
        return '₿';
      default:
        return '$currency ';
    }
  }
}
