import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Durable keys for cash declarations whose first response may have been lost.
/// Pending requests are isolated by backend and courier; different declarations
/// retain distinct keys, and only acknowledged requests are removed.
class HandoverIntentStore {
  HandoverIntentStore(this.preferences);

  final SharedPreferences preferences;

  String _storageKey(String server, String courierId) =>
      'pending_handover_v1:${jsonEncode([server.trim().replaceFirst(RegExp(r"/+$"), ""), courierId])}';

  List<Map<String, dynamic>> _read(String key) {
    final stored = preferences.getString(key);
    if (stored == null) return [];
    final decoded = jsonDecode(stored) as List;
    return decoded
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
  }

  Future<String> prepare({
    required String server,
    required String courierId,
    required num amount,
    required String method,
    String? receipt,
  }) async {
    if (courierId.isEmpty ||
        courierId == 'null' ||
        !amount.isFinite ||
        amount <= 0) {
      throw StateError('Invalid handover identity or amount');
    }
    final storageKey = _storageKey(server, courierId);
    final intents = _read(storageKey);
    final payload = jsonEncode({
      'amount': amount.toStringAsFixed(2),
      'method': method,
      'receipt': receipt ?? '',
    });
    for (final intent in intents) {
      if (intent['payload'] == payload) return intent['key'] as String;
    }
    final random = Random.secure();
    final key =
        'ho-${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
    intents.add({'key': key, 'payload': payload});
    if (!await preferences.setString(storageKey, jsonEncode(intents))) {
      throw StateError('Could not persist handover intent');
    }
    return key;
  }

  Future<void> acknowledge({
    required String server,
    required String courierId,
    required String key,
  }) async {
    final storageKey = _storageKey(server, courierId);
    final intents = _read(storageKey)
      ..removeWhere((intent) => intent['key'] == key);
    if (!await preferences.setString(storageKey, jsonEncode(intents))) {
      throw StateError('Could not acknowledge handover intent');
    }
  }
}
