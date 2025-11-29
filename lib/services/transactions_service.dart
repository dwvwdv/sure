import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/transaction.dart';
import 'api_config.dart';

class TransactionsService {
  Future<Map<String, dynamic>> createTransaction({
    required String accessToken,
    required String accountId,
    required String name,
    required String date,
    required String amount,
    required String currency,
    required String nature,
    String? notes,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/transactions');

    final body = {
      'transaction': {
        'account_id': accountId,
        'name': name,
        'date': date,
        'amount': amount,
        'currency': currency,
        'nature': nature,
        if (notes != null) 'notes': notes,
      }
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(body),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'transaction': Transaction.fromJson(responseData),
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'unauthorized',
        };
      } else {
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
}
