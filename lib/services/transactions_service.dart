import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/transaction.dart';
import 'api_config.dart';

class TransactionsService {
  /// Get all transactions for an account
  Future<Map<String, dynamic>> getTransactions({
    required String accessToken,
    String? accountId,
  }) async {
    var url = '${ApiConfig.baseUrl}/api/v1/transactions';
    if (accountId != null) {
      url += '?account_id=$accountId';
    }

    final uri = Uri.parse(url);

    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        final transactionsList = (responseData['transactions'] as List?)
            ?.map((json) => Transaction.fromJson(json))
            .toList() ?? [];

        return {
          'success': true,
          'transactions': transactionsList,
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'unauthorized',
          'message': 'Session expired. Please login again.',
        };
      } else {
        final responseData = jsonDecode(response.body);
        return {
          'success': false,
          'error': responseData['error'] ?? 'Failed to fetch transactions',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Create a new transaction
  Future<Map<String, dynamic>> createTransaction({
    required String accessToken,
    required String accountId,
    required String name,
    required String date,
    double amount = 0,
    String? currency,
    String nature = 'expense',
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/transactions');

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'transaction': {
            'account_id': accountId,
            'name': name,
            'date': date,
            'amount': amount,
            if (currency != null) 'currency': currency,
            'nature': nature,
          },
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'transaction': Transaction.fromJson(responseData['transaction']),
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'unauthorized',
          'message': 'Session expired. Please login again.',
        };
      } else {
        final responseData = jsonDecode(response.body);
        return {
          'success': false,
          'error': responseData['error'] ?? 'Failed to create transaction',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Update an existing transaction
  Future<Map<String, dynamic>> updateTransaction({
    required String accessToken,
    required String transactionId,
    String? name,
    String? date,
    double? amount,
    String? currency,
    String? nature,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/transactions/$transactionId');

    final transactionData = <String, dynamic>{};
    if (name != null) transactionData['name'] = name;
    if (date != null) transactionData['date'] = date;
    if (amount != null) transactionData['amount'] = amount;
    if (currency != null) transactionData['currency'] = currency;
    if (nature != null) transactionData['nature'] = nature;

    try {
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'transaction': transactionData,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'transaction': Transaction.fromJson(responseData['transaction']),
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'unauthorized',
          'message': 'Session expired. Please login again.',
        };
      } else {
        final responseData = jsonDecode(response.body);
        return {
          'success': false,
          'error': responseData['error'] ?? 'Failed to update transaction',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Delete a single transaction
  Future<Map<String, dynamic>> deleteTransaction({
    required String accessToken,
    required String transactionId,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/transactions/$transactionId');

    try {
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return {
          'success': true,
          'message': 'Transaction deleted successfully',
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'unauthorized',
          'message': 'Session expired. Please login again.',
        };
      } else {
        final responseData = jsonDecode(response.body);
        return {
          'success': false,
          'error': responseData['error'] ?? 'Failed to delete transaction',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Delete multiple transactions
  Future<Map<String, dynamic>> deleteTransactions({
    required String accessToken,
    required List<String> transactionIds,
  }) async {
    int successCount = 0;
    int failureCount = 0;
    final errors = <String>[];

    for (final id in transactionIds) {
      final result = await deleteTransaction(
        accessToken: accessToken,
        transactionId: id,
      );

      if (result['success'] == true) {
        successCount++;
      } else {
        failureCount++;
        errors.add('Transaction $id: ${result['error']}');
      }
    }

    return {
      'success': failureCount == 0,
      'successCount': successCount,
      'failureCount': failureCount,
      'errors': errors,
      'message': failureCount == 0
          ? 'All transactions deleted successfully'
          : 'Some transactions failed to delete',
    };
  }
}
