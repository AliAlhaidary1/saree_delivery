import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sareemart_delivery/core/app_controller.dart';
import 'package:sareemart_delivery/core/json_util.dart';
import 'package:sareemart_delivery/core/panel_api.dart';
import 'package:sareemart_delivery/features/screens.dart';

class HandoverApi extends PanelApi {
  HandoverApi() : super(baseUrl: 'https://test.invalid');
  final keys = <String>[];
  bool succeed = false;

  @override
  Future<ApiResult> collectionSettlement() async => ApiResult({'status': 1, 'data': <String, dynamic>{}});

  @override
  Future<ApiResult> collectionHandover({required num amount, required String idempotencyKey, String collectionMethod = 'cash', String? receiptImage}) async {
    keys.add(idempotencyKey);
    return ApiResult({'status': succeed ? 1 : 0, 'message': 'Response lost'});
  }
}

void main() {
  testWidgets('wallet reconstruction retries uncertain declaration with the same key', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = HandoverApi();
    app.api = api;
    app.apiUrl = 'https://test.invalid';
    app.token = 'test-session';
    app.user = {'delivery_boy': {'id': 7}};
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      app.token = null;
      app.user = null;
    });

    Future<void> submit() async {
      await tester.enterText(find.byType(TextField).first, '50');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('إعلان التوريد'));
      await tester.tap(find.text('إعلان التوريد'));
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(const MaterialApp(home: WalletScreen()));
    await tester.pumpAndSettle();
    await submit();
    expect(api.keys, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
    final prefs = await SharedPreferences.getInstance();
    final persisted = {for (final key in prefs.getKeys()) key: prefs.get(key)!};
    SharedPreferences.setMockInitialValues(persisted);
    await tester.pumpWidget(const MaterialApp(home: WalletScreen()));
    await tester.pumpAndSettle();
    api.succeed = true;
    await submit();
    expect(api.keys, hasLength(2));
    expect(api.keys[1], api.keys[0]);
    await submit();
    expect(api.keys, hasLength(3));
    expect(api.keys[2], isNot(api.keys[1]));
  });
}
