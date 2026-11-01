import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sareemart_delivery/core/handover_intent_store.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'ambiguous response retries and reconstructed store reuse the durable key',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final first = await HandoverIntentStore(prefs).prepare(
        server: 'https://test.invalid/',
        courierId: '7',
        amount: 250,
        method: 'cash',
      );
      // Simulate a fresh preferences instance loading only persisted values,
      // without retaining the original store or preferences singleton.
      final persisted = {for (final key in prefs.getKeys()) key: prefs.get(key)!};
      SharedPreferences.setMockInitialValues(persisted);
      final restoredPreferences = await SharedPreferences.getInstance();
      final retried = await HandoverIntentStore(restoredPreferences).prepare(
        server: 'https://test.invalid',
        courierId: '7',
        amount: 250.0,
        method: 'cash',
      );
      expect(retried, first);
      expect(first, matches(RegExp(r'^ho-[a-f0-9]{32}$')));
    },
  );

  test('couriers and backends never share pending keys', () async {
    final store = HandoverIntentStore(await SharedPreferences.getInstance());
    Future<String> key(String server, String courier) => store.prepare(
      server: server,
      courierId: courier,
      amount: 50,
      method: 'cash',
    );
    final a = await key('https://a.invalid', '1');
    expect(await key('https://a.invalid', '2'), isNot(a));
    expect(await key('https://b.invalid', '1'), isNot(a));
    expect(await key('https://a.invalid', '1'), a);
  });

  test(
    'edited payload retains the earlier uncertain intent for later retry',
    () async {
      final store = HandoverIntentStore(await SharedPreferences.getInstance());
      Future<String> key(num amount, String method, [String? receipt]) =>
          store.prepare(
            server: 'https://test.invalid',
            courierId: '7',
            amount: amount,
            method: method,
            receipt: receipt,
          );
      final a = await key(50, 'cash');
      expect(await key(60, 'cash'), isNot(a));
      expect(
        await key(50, 'transfer', 'data:image/png;base64,receipt'),
        isNot(a),
      );
      expect(await key(50, 'cash'), a);
    },
  );

  test(
    'acknowledgement permits a new identical legitimate declaration',
    () async {
      final store = HandoverIntentStore(await SharedPreferences.getInstance());
      Future<String> key() => store.prepare(
        server: 'https://test.invalid',
        courierId: '7',
        amount: 50,
        method: 'cash',
      );
      final first = await key();
      await store.acknowledge(
        server: 'https://test.invalid',
        courierId: '7',
        key: first,
      );
      expect(await key(), isNot(first));
    },
  );

  test(
    'missing identity and non-finite amounts cannot create intents',
    () async {
      final store = HandoverIntentStore(await SharedPreferences.getInstance());
      for (final value in [double.nan, double.infinity, 0, -1]) {
        await expectLater(
          store.prepare(
            server: 'https://test.invalid',
            courierId: '7',
            amount: value,
            method: 'cash',
          ),
          throwsStateError,
        );
      }
      await expectLater(
        store.prepare(
          server: 'https://test.invalid',
          courierId: 'null',
          amount: 50,
          method: 'cash',
        ),
        throwsStateError,
      );
    },
  );
}
