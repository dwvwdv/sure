import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import '../services/transactions_service.dart';
import '../services/database_helper.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';

class TransactionsProvider with ChangeNotifier {
  final TransactionsService _transactionsService = TransactionsService();
  final DatabaseHelper _db = DatabaseHelper();
  final ConnectivityService _connectivityService = ConnectivityService();
  final SyncService _syncService = SyncService();

  List<Transaction> _transactions = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _error;

  List<Transaction> get transactions => UnmodifiableListView(_transactions);
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get error => _error;
  bool get isOnline => _connectivityService.isConnected;

  int get pendingTransactionsCount {
    return _transactions.where((t) => t.isPending).length;
  }

  // Load transactions from local database (offline-first)
  Future<void> loadTransactionsFromLocal({
    String? accountId,
    int? limitDays = 7,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final transactionMaps = await _db.getTransactions(
        accountId: accountId,
        limitDays: limitDays,
      );

      _transactions = transactionMaps.map((map) => Transaction.fromJson(map)).toList();
      _isLoading = false;
      notifyListeners();

      debugPrint('Loaded ${_transactions.length} transactions from local database');
    } catch (e) {
      _error = 'Failed to load transactions from local storage';
      _isLoading = false;
      notifyListeners();
      debugPrint('Error loading transactions from local: $e');
    }
  }

  // Fetch transactions with offline-first strategy
  Future<void> fetchTransactions({
    required String accessToken,
    String? accountId,
    bool forceSync = false,
  }) async {
    // First, load from local database
    if (!forceSync) {
      await loadTransactionsFromLocal(accountId: accountId);
    }

    // If offline, return local data
    if (!_connectivityService.isConnected) {
      if (_transactions.isEmpty) {
        _error = 'No internet connection and no cached data';
        notifyListeners();
      }
      return;
    }

    // If online and forceSync requested, sync with server
    if (forceSync) {
      await syncTransactionsFromServer(
        accessToken: accessToken,
        accountId: accountId,
      );
    }
  }

  // Sync transactions from server and update local database
  Future<void> syncTransactionsFromServer({
    required String accessToken,
    String? accountId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _transactionsService.getTransactions(
        accessToken: accessToken,
        accountId: accountId,
      );

      if (result['success'] == true && result.containsKey('transactions')) {
        final serverTransactions = (result['transactions'] as List<dynamic>?)?.cast<Transaction>() ?? [];

        // Save to local database
        if (serverTransactions.isNotEmpty) {
          await _db.insertTransactions(serverTransactions);
        }

        // Reload from local database to include both synced and pending transactions
        await loadTransactionsFromLocal(accountId: accountId);

        debugPrint('Synced ${serverTransactions.length} transactions from server');
      } else {
        _error = result['error'] as String? ?? 'Failed to fetch transactions';
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      _error = 'Connection error. Using cached data.';
      _isLoading = false;
      notifyListeners();
      debugPrint('Error syncing transactions: $e');
    }
  }

  // Create transaction with offline support
  Future<bool> createTransaction({
    required String accessToken,
    required String accountId,
    required String name,
    required String date,
    required String amount,
    required String currency,
    required String nature,
    String? notes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_connectivityService.isConnected) {
        // Online: Create on server
        final result = await _transactionsService.createTransaction(
          accessToken: accessToken,
          accountId: accountId,
          name: name,
          date: date,
          amount: amount,
          currency: currency,
          nature: nature,
          notes: notes,
        );

        if (result['success'] == true) {
          final transaction = result['transaction'] as Transaction;

          // Save to local database with synced status
          await _db.insertTransaction(transaction, syncStatus: 'synced');

          // Reload transactions
          await loadTransactionsFromLocal(accountId: accountId);

          _isLoading = false;
          notifyListeners();
          debugPrint('Transaction created online and saved locally');
          return true;
        } else {
          _error = result['error'] as String?;
          _isLoading = false;
          notifyListeners();
          return false;
        }
      } else {
        // Offline: Create locally with pending status
        final transaction = Transaction(
          accountId: accountId,
          name: name,
          date: date,
          amount: amount,
          currency: currency,
          nature: nature,
          notes: notes,
          syncStatus: 'pending',
        );

        await _db.insertTransaction(transaction, syncStatus: 'pending');

        // Reload transactions to show the new pending transaction
        await loadTransactionsFromLocal(accountId: accountId);

        _isLoading = false;
        notifyListeners();
        debugPrint('Transaction created offline (pending sync)');
        return true;
      }
    } catch (e) {
      _error = 'Failed to create transaction: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      debugPrint('Error creating transaction: $e');
      return false;
    }
  }

  // Sync pending transactions to server
  Future<bool> syncPendingTransactions({
    required String accessToken,
  }) async {
    if (!_connectivityService.isConnected) {
      _error = 'No internet connection';
      notifyListeners();
      return false;
    }

    _isSyncing = true;
    notifyListeners();

    final result = await _syncService.syncToServer(accessToken: accessToken);

    _isSyncing = false;

    if (result['success'] == true) {
      // Reload transactions from local database
      await loadTransactionsFromLocal();

      final uploadedCount = result['uploaded_count'] ?? 0;
      debugPrint('Synced $uploadedCount pending transactions to server');
      notifyListeners();
      return true;
    } else {
      _error = result['error'] as String?;
      notifyListeners();
      return false;
    }
  }

  // Delete transaction (only works online, since we support offline create only)
  Future<bool> deleteTransaction({
    required String accessToken,
    required String transactionId,
  }) async {
    if (!_connectivityService.isConnected) {
      _error = 'Cannot delete transactions while offline';
      notifyListeners();
      return false;
    }

    final result = await _transactionsService.deleteTransaction(
      accessToken: accessToken,
      transactionId: transactionId,
    );

    if (result['success'] == true) {
      // Delete from local database
      await _db.deleteTransaction(transactionId);

      // Remove from in-memory list
      _transactions.removeWhere((t) => t.id == transactionId);
      notifyListeners();
      return true;
    } else {
      _error = result['error'] as String? ?? 'Failed to delete transaction';
      notifyListeners();
      return false;
    }
  }

  // Delete multiple transactions (only works online)
  Future<bool> deleteMultipleTransactions({
    required String accessToken,
    required List<String> transactionIds,
  }) async {
    if (!_connectivityService.isConnected) {
      _error = 'Cannot delete transactions while offline';
      notifyListeners();
      return false;
    }

    final result = await _transactionsService.deleteMultipleTransactions(
      accessToken: accessToken,
      transactionIds: transactionIds,
    );

    if (result['success'] == true) {
      // Delete from local database
      for (final id in transactionIds) {
        await _db.deleteTransaction(id);
      }

      // Remove from in-memory list
      _transactions.removeWhere((t) => transactionIds.contains(t.id));
      notifyListeners();
      return true;
    } else {
      _error = result['error'] as String? ?? 'Failed to delete transactions';
      notifyListeners();
      return false;
    }
  }

  void clearTransactions() {
    _transactions = [];
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivityService.dispose();
    super.dispose();
  }
}
