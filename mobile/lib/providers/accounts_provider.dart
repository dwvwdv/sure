import 'package:flutter/foundation.dart';
import '../models/account.dart';
import '../services/accounts_service.dart';
import '../services/database_helper.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';

class AccountsProvider with ChangeNotifier {
  final AccountsService _accountsService = AccountsService();
  final DatabaseHelper _db = DatabaseHelper();
  final ConnectivityService _connectivityService = ConnectivityService();
  final SyncService _syncService = SyncService();

  List<Account> _accounts = [];
  bool _isLoading = false;
  bool _isInitializing = true;
  bool _isSyncing = false;
  String? _errorMessage;
  Map<String, dynamic>? _pagination;

  List<Account> get accounts => _accounts;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  bool get isSyncing => _isSyncing;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get pagination => _pagination;
  bool get isOnline => _connectivityService.isConnected;

  List<Account> get assetAccounts {
    final assets = _accounts.where((a) => a.isAsset).toList();
    _sortAccounts(assets);
    return assets;
  }

  List<Account> get liabilityAccounts {
    final liabilities = _accounts.where((a) => a.isLiability).toList();
    _sortAccounts(liabilities);
    return liabilities;
  }

  Map<String, double> get assetTotalsByCurrency {
    final totals = <String, double>{};
    for (var account in _accounts.where((a) => a.isAsset)) {
      totals[account.currency] = (totals[account.currency] ?? 0.0) + account.balanceAsDouble;
    }
    return totals;
  }

  Map<String, double> get liabilityTotalsByCurrency {
    final totals = <String, double>{};
    for (var account in _accounts.where((a) => a.isLiability)) {
      totals[account.currency] = (totals[account.currency] ?? 0.0) + account.balanceAsDouble;
    }
    return totals;
  }

  void _sortAccounts(List<Account> accounts) {
    accounts.sort((a, b) {
      int typeComparison = a.accountType.compareTo(b.accountType);
      if (typeComparison != 0) return typeComparison;

      int currencyComparison = a.currency.compareTo(b.currency);
      if (currencyComparison != 0) return currencyComparison;

      int balanceComparison = b.balanceAsDouble.compareTo(a.balanceAsDouble);
      if (balanceComparison != 0) return balanceComparison;

      return a.name.compareTo(b.name);
    });
  }

  // Load accounts from local database (offline-first)
  Future<void> loadAccountsFromLocal() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _accounts = await _db.getAccounts();
      _isLoading = false;
      _isInitializing = false;
      notifyListeners();
      debugPrint('Loaded ${_accounts.length} accounts from local database');
    } catch (e) {
      _errorMessage = 'Failed to load accounts from local storage';
      _isLoading = false;
      _isInitializing = false;
      notifyListeners();
      debugPrint('Error loading accounts from local: $e');
    }
  }

  // Fetch accounts with offline-first strategy
  Future<bool> fetchAccounts({
    required String accessToken,
    int page = 1,
    int perPage = 25,
    bool forceSync = false,
  }) async {
    // First, load from local database
    if (!forceSync && _accounts.isEmpty) {
      await loadAccountsFromLocal();
    }

    // If offline, return local data
    if (!_connectivityService.isConnected) {
      if (_accounts.isEmpty) {
        _errorMessage = 'No internet connection and no cached data';
        notifyListeners();
      }
      return _accounts.isNotEmpty;
    }

    // If online, sync with server in background
    if (forceSync || _accounts.isEmpty) {
      return await syncAccountsFromServer(accessToken: accessToken);
    }

    return true;
  }

  // Sync accounts from server and update local database
  Future<bool> syncAccountsFromServer({
    required String accessToken,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _accountsService.getAccounts(
        accessToken: accessToken,
      );

      if (result['success'] == true && result.containsKey('accounts')) {
        final serverAccounts = (result['accounts'] as List<dynamic>?)?.cast<Account>() ?? [];

        // Save to local database
        await _db.insertAccounts(serverAccounts);

        // Update in-memory list
        _accounts = serverAccounts;
        _pagination = result['pagination'] as Map<String, dynamic>?;
        _isLoading = false;
        _isInitializing = false;
        notifyListeners();

        debugPrint('Synced ${_accounts.length} accounts from server');
        return true;
      } else {
        _errorMessage = result['error'] as String? ?? 'Failed to fetch accounts';
        _isLoading = false;
        _isInitializing = false;
        notifyListeners();

        // Still return true if we have local data
        return _accounts.isNotEmpty;
      }
    } catch (e) {
      _errorMessage = 'Connection error. Using cached data.';
      _isLoading = false;
      _isInitializing = false;
      notifyListeners();
      debugPrint('Error syncing accounts: $e');

      // Return true if we have local data
      return _accounts.isNotEmpty;
    }
  }

  // Full sync (accounts + transactions)
  Future<bool> performFullSync({
    required String accessToken,
    int daysToSync = 7,
  }) async {
    if (_isSyncing) return false;

    _isSyncing = true;
    notifyListeners();

    final result = await _syncService.fullSync(
      accessToken: accessToken,
      daysToSync: daysToSync,
    );

    _isSyncing = false;

    if (result['success'] == true) {
      // Reload accounts from local database
      await loadAccountsFromLocal();
      return true;
    } else {
      _errorMessage = result['error'] as String?;
      notifyListeners();
      return false;
    }
  }

  void clearAccounts() {
    _accounts = [];
    _pagination = null;
    _errorMessage = null;
    _isInitializing = true;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivityService.dispose();
    super.dispose();
  }
}
