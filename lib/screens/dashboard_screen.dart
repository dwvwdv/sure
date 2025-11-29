import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/accounts_provider.dart';
import '../widgets/account_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _assetsExpanded = true;
  bool _liabilitiesExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final accountsProvider = Provider.of<AccountsProvider>(context, listen: false);
    
    final accessToken = await authProvider.getValidAccessToken();
    if (accessToken == null) {
      // Token is invalid, redirect to login
      await authProvider.logout();
      return;
    }

    await accountsProvider.fetchAccounts(accessToken: accessToken);
    
    // Check if unauthorized
    if (accountsProvider.errorMessage == 'unauthorized') {
      await authProvider.logout();
    }
  }

  Future<void> _handleRefresh() async {
    await _loadAccounts();
  }

  String _formatCurrencyTotals(Map<String, double> totals) {
    if (totals.isEmpty) return '';

    final List<String> formatted = [];
    totals.forEach((currency, amount) {
      final symbol = _getCurrencySymbol(currency);
      final formattedAmount = amount.toStringAsFixed(
        amount.abs() < 1 && amount != 0 ? 4 : 0,
      );
      formatted.add('$currency$symbol${formattedAmount.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      )}');
    });

    return formatted.join('、');
  }

  String _getCurrencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'USD':
        return '\$';
      case 'TWD':
        return '\$';
      case 'BTC':
        return '₿';
      case 'ETH':
        return 'Ξ';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'JPY':
        return '¥';
      case 'CNY':
        return '¥';
      default:
        return ' ';
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final accountsProvider = Provider.of<AccountsProvider>(context, listen: false);
      
      accountsProvider.clearAccounts();
      await authProvider.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _handleRefresh,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: Consumer2<AuthProvider, AccountsProvider>(
        builder: (context, authProvider, accountsProvider, _) {
          // Show loading state
          if (accountsProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Show error state
          if (accountsProvider.errorMessage != null && 
              accountsProvider.errorMessage != 'unauthorized') {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load accounts',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      accountsProvider.errorMessage!,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _handleRefresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Show empty state
          if (accountsProvider.accounts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 64,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No accounts yet',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add accounts in the web app to see them here.',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _handleRefresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Show accounts list
          return RefreshIndicator(
            onRefresh: _handleRefresh,
            child: CustomScrollView(
              slivers: [
                // Welcome header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome${authProvider.user != null ? ', ${authProvider.user!.displayName}' : ''}',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Here\'s your financial overview',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),

                // Summary cards
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        if (accountsProvider.assetAccounts.isNotEmpty)
                          _SummaryCard(
                            title: 'Assets',
                            totals: _formatCurrencyTotals(
                              accountsProvider.assetTotalsByCurrency,
                            ),
                            color: Colors.green,
                          ),
                        if (accountsProvider.liabilityAccounts.isNotEmpty)
                          _SummaryCard(
                            title: 'Liabilities',
                            totals: _formatCurrencyTotals(
                              accountsProvider.liabilityTotalsByCurrency,
                            ),
                            color: Colors.red,
                          ),
                      ],
                    ),
                  ),
                ),

                // Assets section
                if (accountsProvider.assetAccounts.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _CollapsibleSectionHeader(
                      title: 'Assets',
                      count: accountsProvider.assetAccounts.length,
                      color: Colors.green,
                      isExpanded: _assetsExpanded,
                      onToggle: () {
                        setState(() {
                          _assetsExpanded = !_assetsExpanded;
                        });
                      },
                    ),
                  ),
                  if (_assetsExpanded)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return AccountCard(
                              account: accountsProvider.assetAccounts[index],
                            );
                          },
                          childCount: accountsProvider.assetAccounts.length,
                        ),
                      ),
                    ),
                ],

                // Liabilities section
                if (accountsProvider.liabilityAccounts.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _CollapsibleSectionHeader(
                      title: 'Liabilities',
                      count: accountsProvider.liabilityAccounts.length,
                      color: Colors.red,
                      isExpanded: _liabilitiesExpanded,
                      onToggle: () {
                        setState(() {
                          _liabilitiesExpanded = !_liabilitiesExpanded;
                        });
                      },
                    ),
                  ),
                  if (_liabilitiesExpanded)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return AccountCard(
                              account: accountsProvider.liabilityAccounts[index],
                            );
                          },
                          childCount: accountsProvider.liabilityAccounts.length,
                        ),
                      ),
                    ),
                ],

                // Uncategorized accounts
                ..._buildUncategorizedSection(accountsProvider),

                // Bottom padding
                const SliverToBoxAdapter(
                  child: SizedBox(height: 24),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildUncategorizedSection(AccountsProvider accountsProvider) {
    final uncategorized = accountsProvider.accounts
        .where((a) => !a.isAsset && !a.isLiability)
        .toList();

    if (uncategorized.isEmpty) {
      return [];
    }

    return [
      SliverToBoxAdapter(
        child: _SectionHeader(
          title: 'Other Accounts',
          count: uncategorized.length,
          color: Colors.grey,
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              return AccountCard(account: uncategorized[index]);
            },
            childCount: uncategorized.length,
          ),
        ),
      ),
    ];
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String totals;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.totals,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  totals,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CollapsibleSectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _CollapsibleSectionHeader({
    required this.title,
    required this.count,
    required this.color,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const Spacer(),
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}
