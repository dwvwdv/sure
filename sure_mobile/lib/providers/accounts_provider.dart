import 'package:flutter/foundation.dart';
import '../models/account.dart';
import '../services/accounts_service.dart';

class AccountsProvider with ChangeNotifier {
  final AccountsService _accountsService = AccountsService();
  
  List<Account> _accounts = [];
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _pagination;

  List<Account> get accounts => _accounts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get pagination => _pagination;

  List<Account> get assetAccounts => 
      _accounts.where((a) => a.isAsset).toList();
  
  List<Account> get liabilityAccounts => 
      _accounts.where((a) => a.isLiability).toList();

  Future<bool> fetchAccounts({
    required String accessToken,
    int page = 1,
    int perPage = 25,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _accountsService.getAccounts(
        accessToken: accessToken,
        page: page,
        perPage: perPage,
      );

      if (result['success'] == true) {
        _accounts = result['accounts'] as List<Account>;
        _pagination = result['pagination'] as Map<String, dynamic>?;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['error'] as String? ?? 'Failed to fetch accounts';
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

  void clearAccounts() {
    _accounts = [];
    _pagination = null;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
