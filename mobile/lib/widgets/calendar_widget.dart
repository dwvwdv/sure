import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../providers/accounts_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/auth_provider.dart';
import '../screens/calendar_screen.dart';

/// A compact calendar widget for the dashboard home screen.
/// Shows the current month with transaction indicators and a monthly total.
/// Tapping "View Full Calendar" navigates to the full CalendarScreen.
class CalendarWidget extends StatefulWidget {
  const CalendarWidget({super.key});

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  DateTime _currentMonth = DateTime.now();
  Map<String, double> _dailyChanges = {};
  bool _isLoading = false;
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTransactions();
    });
  }

  Future<void> _loadTransactions() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    final authProvider = context.read<AuthProvider>();
    final accountsProvider = context.read<AccountsProvider>();
    final transactionsProvider = context.read<TransactionsProvider>();

    final accessToken = await authProvider.getValidAccessToken();
    if (accessToken == null) {
      setState(() => _isLoading = false);
      return;
    }

    // Use the first asset account for the dashboard calendar summary
    final assetAccounts = accountsProvider.accounts.where((a) => a.isAsset).toList();
    if (assetAccounts.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    final account = assetAccounts.first;
    await transactionsProvider.fetchTransactions(
      accessToken: accessToken,
      accountId: account.id,
      forceSync: false,
    );

    _computeDailyChanges(transactionsProvider.transactions, isAsset: account.isAsset);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _computeDailyChanges(List<Transaction> transactions, {required bool isAsset}) {
    final changes = <String, double>{};

    for (final tx in transactions) {
      try {
        final date = DateTime.parse(tx.date);
        final key = DateFormat('yyyy-MM-dd').format(date);

        String trimmed = tx.amount.trim().replaceAll('\u2212', '-');
        final isNeg = trimmed.startsWith('-') || trimmed.endsWith('-');
        final numStr = trimmed.replaceAll(RegExp(r'[^\d.\-]'), '').replaceAll('-', '');
        double amount = double.tryParse(numStr) ?? 0.0;
        if (isNeg) amount = -amount;
        if (isAsset) amount = -amount;

        changes[key] = (changes[key] ?? 0.0) + amount;
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _dailyChanges = changes;
      });
    }
  }

  void _goToPreviousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _goToNextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  double _monthlyTotal() {
    final prefix = DateFormat('yyyy-MM').format(_currentMonth);
    return _dailyChanges.entries
        .where((e) => e.key.startsWith(prefix))
        .fold(0.0, (sum, e) => sum + e.value);
  }

  String _formatAmount(double amount) {
    final sign = amount >= 0 ? '+' : '';
    return '$sign${NumberFormat('#,##0.##').format(amount)}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_outlined, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Calendar',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  // Monthly total badge
                  if (!_isLoading && _dailyChanges.isNotEmpty) ...[
                    _MonthlyBadge(total: _monthlyTotal()),
                    const SizedBox(width: 8),
                  ],
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          // Collapsible body
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildBody(colorScheme),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    return Column(
      children: [
        Divider(height: 1, color: colorScheme.outlineVariant),

        // Month navigation row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: _goToPreviousMonth,
                visualDensity: VisualDensity.compact,
              ),
              Text(
                DateFormat('MMMM yyyy').format(_currentMonth),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: _goToNextMonth,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),

        // Calendar grid or loading
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: _isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _buildCalendarGrid(colorScheme),
        ),

        // Footer: "View Full Calendar" link
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CalendarScreen()),
            );
          },
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'View Full Calendar',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward,
                  size: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(ColorScheme colorScheme) {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final startOffset = firstDay.weekday % 7; // 0 = Sunday

    final today = DateTime.now();

    return Column(
      children: [
        // Weekday header
        Row(
          children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
              .map((d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),

        // Day cells
        ...List.generate((daysInMonth + startOffset + 6) ~/ 7, (week) {
          return Row(
            children: List.generate(7, (dow) {
              final dayNum = week * 7 + dow - startOffset + 1;
              if (dayNum < 1 || dayNum > daysInMonth) {
                return const Expanded(child: SizedBox(height: 40));
              }

              final date = DateTime(_currentMonth.year, _currentMonth.month, dayNum);
              final key = DateFormat('yyyy-MM-dd').format(date);
              final change = _dailyChanges[key];
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;

              return Expanded(child: _DayCell(
                day: dayNum,
                change: change,
                isToday: isToday,
                colorScheme: colorScheme,
                formatAmount: _formatAmount,
              ));
            }),
          );
        }),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ──────────────────────────────────────────────────────────────────────────────

class _MonthlyBadge extends StatelessWidget {
  final double total;
  const _MonthlyBadge({required this.total});

  @override
  Widget build(BuildContext context) {
    final isPositive = total >= 0;
    final color = isPositive ? Colors.green.shade700 : Colors.red.shade700;
    final bg = isPositive
        ? Colors.green.withValues(alpha: 0.12)
        : Colors.red.withValues(alpha: 0.12);
    final sign = isPositive ? '+' : '';
    final label = '$sign${NumberFormat('#,##0.##').format(total)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final double? change;
  final bool isToday;
  final ColorScheme colorScheme;
  final String Function(double) formatAmount;

  const _DayCell({
    required this.day,
    required this.change,
    required this.isToday,
    required this.colorScheme,
    required this.formatAmount,
  });

  @override
  Widget build(BuildContext context) {
    Color? bgColor;
    Color dotColor = Colors.transparent;

    if (change != null && change != 0.0) {
      if (change! > 0) {
        bgColor = Colors.green.withValues(alpha: 0.15);
        dotColor = Colors.green.shade600;
      } else {
        bgColor = Colors.red.withValues(alpha: 0.15);
        dotColor = Colors.red.shade600;
      }
    }

    return Container(
      height: 40,
      margin: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: bgColor ?? Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: isToday
            ? Border.all(color: colorScheme.primary, width: 2)
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            day.toString(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              color: isToday ? colorScheme.primary : colorScheme.onSurface,
            ),
          ),
          if (change != null && change != 0.0) ...[
            const SizedBox(height: 1),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
