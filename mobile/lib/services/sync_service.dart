import 'package:flutter/foundation.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import 'database_helper.dart';
import 'accounts_service.dart';
import 'transactions_service.dart';
import 'connectivity_service.dart';

class SyncService {
  final DatabaseHelper _db = DatabaseHelper();
  final AccountsService _accountsService = AccountsService();
  final TransactionsService _transactionsService = TransactionsService();
  final ConnectivityService _connectivityService = ConnectivityService();

  static const int defaultDaysToKeep = 7;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  // Sync all data from server to local database
  Future<Map<String, dynamic>> syncFromServer({
    required String accessToken,
    int daysToSync = defaultDaysToKeep,
  }) async {
    if (_isSyncing) {
      return {
        'success': false,
        'error': 'Sync already in progress',
      };
    }

    if (!_connectivityService.isConnected) {
      return {
        'success': false,
        'error': 'No internet connection',
      };
    }

    _isSyncing = true;
    debugPrint('Starting sync from server (last $daysToSync days)...');

    try {
      // 1. Fetch and save accounts
      final accountsResult = await _accountsService.getAccounts(
        accessToken: accessToken,
      );

      if (accountsResult['success'] != true) {
        _isSyncing = false;
        return accountsResult;
      }

      final accounts = accountsResult['accounts'] as List<Account>;
      await _db.insertAccounts(accounts);
      debugPrint('Synced ${accounts.length} accounts');

      // 2. Fetch and save transactions for each account
      int totalTransactions = 0;
      for (final account in accounts) {
        final transactionsResult = await _transactionsService.getTransactions(
          accessToken: accessToken,
          accountId: account.id,
        );

        if (transactionsResult['success'] == true) {
          final transactions = transactionsResult['transactions'] as List<Transaction>;

          // Filter transactions by date range
          final cutoffDate = DateTime.now().subtract(Duration(days: daysToSync));
          final recentTransactions = transactions.where((t) {
            try {
              final transactionDate = DateTime.parse(t.date);
              return transactionDate.isAfter(cutoffDate);
            } catch (e) {
              return true; // Keep if date parsing fails
            }
          }).toList();

          await _db.insertTransactions(recentTransactions);
          totalTransactions += recentTransactions.length;
          debugPrint('Synced ${recentTransactions.length} transactions for account ${account.name}');
        }
      }

      // 3. Cleanup old transactions
      await _db.cleanupOldTransactions(daysToSync);

      _isSyncing = false;
      debugPrint('Sync completed: ${accounts.length} accounts, $totalTransactions transactions');

      return {
        'success': true,
        'accounts_count': accounts.length,
        'transactions_count': totalTransactions,
      };
    } catch (e, stackTrace) {
      _isSyncing = false;
      debugPrint('Sync error: $e\n$stackTrace');
      return {
        'success': false,
        'error': 'Sync failed: ${e.toString()}',
      };
    }
  }

  // Upload pending (offline-created) transactions to server
  Future<Map<String, dynamic>> syncToServer({
    required String accessToken,
  }) async {
    if (!_connectivityService.isConnected) {
      return {
        'success': false,
        'error': 'No internet connection',
      };
    }

    debugPrint('Starting sync to server (uploading pending transactions)...');

    try {
      final pendingTransactions = await _db.getPendingTransactions();

      if (pendingTransactions.isEmpty) {
        debugPrint('No pending transactions to sync');
        return {
          'success': true,
          'uploaded_count': 0,
        };
      }

      int successCount = 0;
      int failedCount = 0;

      for (final transactionData in pendingTransactions) {
        final localId = transactionData['id'] as String;
        final transaction = Transaction.fromJson(transactionData);

        try {
          final result = await _transactionsService.createTransaction(
            accessToken: accessToken,
            accountId: transaction.accountId,
            name: transaction.name,
            date: transaction.date,
            amount: transaction.amount,
            currency: transaction.currency,
            nature: transaction.nature,
            notes: transaction.notes,
          );

          if (result['success'] == true) {
            final createdTransaction = result['transaction'] as Transaction;
            await _db.updateTransactionSyncStatus(
              localId,
              createdTransaction.id!,
              'synced',
            );
            successCount++;
            debugPrint('Uploaded transaction: ${transaction.name}');
          } else {
            failedCount++;
            debugPrint('Failed to upload transaction: ${transaction.name}');
          }
        } catch (e) {
          failedCount++;
          debugPrint('Error uploading transaction: $e');
        }
      }

      debugPrint('Sync to server completed: $successCount uploaded, $failedCount failed');

      return {
        'success': true,
        'uploaded_count': successCount,
        'failed_count': failedCount,
      };
    } catch (e, stackTrace) {
      debugPrint('Sync to server error: $e\n$stackTrace');
      return {
        'success': false,
        'error': 'Upload failed: ${e.toString()}',
      };
    }
  }

  // Full bidirectional sync
  Future<Map<String, dynamic>> fullSync({
    required String accessToken,
    int daysToSync = defaultDaysToKeep,
  }) async {
    if (_isSyncing) {
      return {
        'success': false,
        'error': 'Sync already in progress',
      };
    }

    if (!_connectivityService.isConnected) {
      return {
        'success': false,
        'error': 'No internet connection',
      };
    }

    debugPrint('Starting full bidirectional sync...');

    // 1. First upload pending transactions
    final uploadResult = await syncToServer(accessToken: accessToken);

    // 2. Then download latest data from server
    final downloadResult = await syncFromServer(
      accessToken: accessToken,
      daysToSync: daysToSync,
    );

    return {
      'success': downloadResult['success'] == true,
      'upload': uploadResult,
      'download': downloadResult,
    };
  }

  // Initial sync on first login
  Future<Map<String, dynamic>> initialSync({
    required String accessToken,
    int daysToSync = defaultDaysToKeep,
  }) async {
    debugPrint('Starting initial sync...');

    // Clear existing data first
    await _db.clearAllData();

    // Download data from server
    return await syncFromServer(
      accessToken: accessToken,
      daysToSync: daysToSync,
    );
  }

  void dispose() {
    _connectivityService.dispose();
  }
}
