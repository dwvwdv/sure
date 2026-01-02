import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import '../models/account.dart';
import '../models/transaction.dart' as models;

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'sure_offline.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create accounts table
    await db.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        balance TEXT NOT NULL,
        currency TEXT NOT NULL,
        classification TEXT,
        account_type TEXT NOT NULL,
        last_synced_at INTEGER
      )
    ''');

    // Create transactions table
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL,
        name TEXT NOT NULL,
        date TEXT NOT NULL,
        amount TEXT NOT NULL,
        currency TEXT NOT NULL,
        nature TEXT NOT NULL,
        notes TEXT,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        local_id TEXT,
        created_at INTEGER,
        FOREIGN KEY (account_id) REFERENCES accounts (id)
      )
    ''');

    // Create index for faster queries
    await db.execute('''
      CREATE INDEX idx_transactions_account_id ON transactions(account_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_transactions_date ON transactions(date DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_transactions_sync_status ON transactions(sync_status)
    ''');
  }

  // ==================== Account Operations ====================

  Future<void> insertAccount(Account account) async {
    final db = await database;
    await db.insert(
      'accounts',
      {
        'id': account.id,
        'name': account.name,
        'balance': account.balance,
        'currency': account.currency,
        'classification': account.classification,
        'account_type': account.accountType,
        'last_synced_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertAccounts(List<Account> accounts) async {
    final db = await database;
    final batch = db.batch();

    for (final account in accounts) {
      batch.insert(
        'accounts',
        {
          'id': account.id,
          'name': account.name,
          'balance': account.balance,
          'currency': account.currency,
          'classification': account.classification,
          'account_type': account.accountType,
          'last_synced_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<List<Account>> getAccounts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('accounts');

    return List.generate(maps.length, (i) {
      return Account.fromJson({
        'id': maps[i]['id'],
        'name': maps[i]['name'],
        'balance': maps[i]['balance'],
        'currency': maps[i]['currency'],
        'classification': maps[i]['classification'],
        'account_type': maps[i]['account_type'],
      });
    });
  }

  Future<void> deleteAllAccounts() async {
    final db = await database;
    await db.delete('accounts');
  }

  // ==================== Transaction Operations ====================

  Future<void> insertTransaction(models.Transaction transaction, {String syncStatus = 'synced'}) async {
    final db = await database;

    final transactionId = transaction.id ?? _generateLocalId();

    await db.insert(
      'transactions',
      {
        'id': transactionId,
        'account_id': transaction.accountId,
        'name': transaction.name,
        'date': transaction.date,
        'amount': transaction.amount,
        'currency': transaction.currency,
        'nature': transaction.nature,
        'notes': transaction.notes,
        'sync_status': syncStatus,
        'local_id': transaction.id == null ? transactionId : null,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertTransactions(List<models.Transaction> transactions) async {
    final db = await database;
    final batch = db.batch();

    for (final transaction in transactions) {
      batch.insert(
        'transactions',
        {
          'id': transaction.id!,
          'account_id': transaction.accountId,
          'name': transaction.name,
          'date': transaction.date,
          'amount': transaction.amount,
          'currency': transaction.currency,
          'nature': transaction.nature,
          'notes': transaction.notes,
          'sync_status': 'synced',
          'local_id': null,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getTransactions({
    String? accountId,
    int? limitDays,
  }) async {
    final db = await database;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (accountId != null) {
      whereClause = 'account_id = ?';
      whereArgs.add(accountId);
    }

    if (limitDays != null) {
      final cutoffDate = DateTime.now().subtract(Duration(days: limitDays));
      final cutoffDateStr = cutoffDate.toIso8601String().split('T')[0];

      if (whereClause.isNotEmpty) {
        whereClause += ' AND ';
      }
      whereClause += 'date >= ?';
      whereArgs.add(cutoffDateStr);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'date DESC, created_at DESC',
    );

    return maps;
  }

  Future<List<Map<String, dynamic>>> getPendingTransactions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'sync_status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at ASC',
    );

    return maps;
  }

  Future<void> updateTransactionSyncStatus(String localId, String serverId, String syncStatus) async {
    final db = await database;
    await db.update(
      'transactions',
      {
        'id': serverId,
        'sync_status': syncStatus,
        'local_id': null,
      },
      where: 'id = ? OR local_id = ?',
      whereArgs: [localId, localId],
    );
  }

  Future<void> deleteTransaction(String transactionId) async {
    final db = await database;
    await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [transactionId],
    );
  }

  Future<void> deleteTransactionsByAccount(String accountId) async {
    final db = await database;
    await db.delete(
      'transactions',
      where: 'account_id = ?',
      whereArgs: [accountId],
    );
  }

  Future<void> deleteAllTransactions() async {
    final db = await database;
    await db.delete('transactions');
  }

  // ==================== Cleanup Operations ====================

  Future<void> cleanupOldTransactions(int daysToKeep) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
    final cutoffDateStr = cutoffDate.toIso8601String().split('T')[0];

    // Only delete synced transactions that are older than cutoff
    await db.delete(
      'transactions',
      where: 'date < ? AND sync_status = ?',
      whereArgs: [cutoffDateStr, 'synced'],
    );

    debugPrint('Cleaned up transactions older than $cutoffDateStr');
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('transactions');
    await db.delete('accounts');
    debugPrint('All local data cleared');
  }

  // ==================== Helper Methods ====================

  String _generateLocalId() {
    return 'local_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
