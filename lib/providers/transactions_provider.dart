import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import '../services/transactions_service.dart';

class TransactionsProvider with ChangeNotifier {
  final TransactionsService _transactionsService = TransactionsService();

  List<Transaction> _transactions = [];
  bool _isLoading = false;
  String? _errorMessage;
  final Set<String> _selectedTransactionIds = {};

  List<Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Set<String> get selectedTransactionIds => _selectedTransactionIds;
  bool get hasSelection => _selectedTransactionIds.isNotEmpty;
  int get selectedCount => _selectedTransactionIds.length;

  /// Toggle selection for a transaction
  void toggleSelection(String transactionId) {
    if (_selectedTransactionIds.contains(transactionId)) {
      _selectedTransactionIds.remove(transactionId);
    } else {
      _selectedTransactionIds.add(transactionId);
    }
    notifyListeners();
  }

  /// Select all transactions
  void selectAll() {
    _selectedTransactionIds.clear();
    _selectedTransactionIds.addAll(_transactions.map((t) => t.id));
    notifyListeners();
  }

  /// Clear all selections
  void clearSelection() {
    _selectedTransactionIds.clear();
    notifyListeners();
  }

  /// Check if a transaction is selected
  bool isSelected(String transactionId) {
    return _selectedTransactionIds.contains(transactionId);
  }

  /// Fetch transactions for an account
  Future<bool> fetchTransactions({
    required String accessToken,
    String? accountId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _transactionsService.getTransactions(
        accessToken: accessToken,
        accountId: accountId,
      );

      if (result['success'] == true) {
        _transactions = result['transactions'] as List<Transaction>;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['error'] as String? ?? 'Failed to fetch transactions';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Connection error. Please check your internet connection.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Delete a single transaction
  Future<bool> deleteTransaction({
    required String accessToken,
    required String transactionId,
  }) async {
    try {
      final result = await _transactionsService.deleteTransaction(
        accessToken: accessToken,
        transactionId: transactionId,
      );

      if (result['success'] == true) {
        _transactions.removeWhere((t) => t.id == transactionId);
        _selectedTransactionIds.remove(transactionId);
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['error'] as String? ?? 'Failed to delete transaction';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Connection error. Please check your internet connection.';
      notifyListeners();
      return false;
    }
  }

  /// Delete multiple selected transactions
  Future<Map<String, dynamic>> deleteSelectedTransactions({
    required String accessToken,
  }) async {
    if (_selectedTransactionIds.isEmpty) {
      return {
        'success': false,
        'message': 'No transactions selected',
      };
    }

    try {
      final result = await _transactionsService.deleteTransactions(
        accessToken: accessToken,
        transactionIds: _selectedTransactionIds.toList(),
      );

      if (result['success'] == true) {
        // Remove deleted transactions from the list
        _transactions.removeWhere((t) => _selectedTransactionIds.contains(t.id));
        _selectedTransactionIds.clear();
        notifyListeners();
      } else {
        _errorMessage = result['message'] as String? ?? 'Failed to delete transactions';
        notifyListeners();
      }

      return result;
    } catch (e) {
      _errorMessage = 'Connection error. Please check your internet connection.';
      notifyListeners();
      return {
        'success': false,
        'message': 'Connection error',
      };
    }
  }

  void clearTransactions() {
    _transactions = [];
    _selectedTransactionIds.clear();
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
