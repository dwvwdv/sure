import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/account.dart';
import '../providers/auth_provider.dart';
import '../providers/transactions_provider.dart';
import 'transaction_form_screen.dart';

class TransactionsScreen extends StatefulWidget {
  final Account account;

  const TransactionsScreen({
    super.key,
    required this.account,
  });

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final transactionsProvider = Provider.of<TransactionsProvider>(context, listen: false);

    final accessToken = await authProvider.getValidAccessToken();
    if (accessToken == null) {
      await authProvider.logout();
      return;
    }

    await transactionsProvider.fetchTransactions(
      accessToken: accessToken,
      accountId: widget.account.id,
    );

    if (transactionsProvider.errorMessage == 'unauthorized') {
      await authProvider.logout();
    }
  }

  Future<void> _handleRefresh() async {
    await _loadTransactions();
  }

  Future<void> _handleDeleteSelected() async {
    final transactionsProvider = Provider.of<TransactionsProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transactions'),
        content: Text(
          'Are you sure you want to delete ${transactionsProvider.selectedCount} transaction(s)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final accessToken = await authProvider.getValidAccessToken();
      if (accessToken == null) {
        await authProvider.logout();
        return;
      }

      final result = await transactionsProvider.deleteSelectedTransactions(
        accessToken: accessToken,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Transactions deleted'),
            backgroundColor: result['success'] == true ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleDeleteSingle(String transactionId, String transactionName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text('Are you sure you want to delete "$transactionName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final transactionsProvider = Provider.of<TransactionsProvider>(context, listen: false);

      final accessToken = await authProvider.getValidAccessToken();
      if (accessToken == null) {
        await authProvider.logout();
        return;
      }

      final success = await transactionsProvider.deleteTransaction(
        accessToken: accessToken,
        transactionId: transactionId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Transaction deleted' : 'Failed to delete transaction'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account.name),
        actions: [
          Consumer<TransactionsProvider>(
            builder: (context, provider, _) {
              if (provider.hasSelection) {
                return Row(
                  children: [
                    if (provider.selectedCount < provider.transactions.length)
                      IconButton(
                        icon: const Icon(Icons.select_all),
                        onPressed: provider.selectAll,
                        tooltip: 'Select All',
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: _handleDeleteSelected,
                      tooltip: 'Delete Selected',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: provider.clearSelection,
                      tooltip: 'Clear Selection',
                    ),
                  ],
                );
              }
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _handleRefresh,
                tooltip: 'Refresh',
              );
            },
          ),
        ],
      ),
      body: Consumer<TransactionsProvider>(
        builder: (context, transactionsProvider, _) {
          // Show loading state
          if (transactionsProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Show error state
          if (transactionsProvider.errorMessage != null &&
              transactionsProvider.errorMessage != 'unauthorized') {
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
                      'Failed to load transactions',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      transactionsProvider.errorMessage!,
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
          if (transactionsProvider.transactions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 64,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No transactions yet',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This account has no transaction history.',
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

          // Show transactions list
          return RefreshIndicator(
            onRefresh: _handleRefresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: transactionsProvider.transactions.length,
              itemBuilder: (context, index) {
                final transaction = transactionsProvider.transactions[index];
                final isSelected = transactionsProvider.isSelected(transaction.id);

                return Dismissible(
                  key: Key(transaction.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  confirmDismiss: (direction) async {
                    await _handleDeleteSingle(transaction.id, transaction.name);
                    return false; // We handle deletion manually
                  },
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: isSelected ? 4 : 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isSelected
                          ? BorderSide(color: colorScheme.primary, width: 2)
                          : BorderSide.none,
                    ),
                    child: InkWell(
                      onTap: () => transactionsProvider.toggleSelection(transaction.id),
                      onLongPress: () => transactionsProvider.toggleSelection(transaction.id),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Selection indicator
                            if (transactionsProvider.hasSelection)
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Icon(
                                  isSelected
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: isSelected
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant,
                                ),
                              ),

                            // Transaction icon
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: transaction.isExpense
                                    ? Colors.red.withOpacity(0.1)
                                    : Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                transaction.isExpense
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                color: transaction.isExpense ? Colors.red : Colors.green,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Transaction info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    transaction.name,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    transaction.date,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),

                            // Amount
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  transaction.formattedAmount,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: transaction.isExpense ? Colors.red : Colors.green,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  transaction.currency,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _handleCreateTransaction(),
        tooltip: 'Add Transaction',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _handleCreateTransaction() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TransactionFormScreen(account: widget.account),
    );

    // Refresh transactions if one was created successfully
    if (result == true && mounted) {
      await _handleRefresh();
    }
  }

  @override
  void dispose() {
    // Clear selections and transactions when leaving the screen
    Provider.of<TransactionsProvider>(context, listen: false).clearTransactions();
    super.dispose();
  }
}
