import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../core/app_controller.dart';
import '../core/json_util.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';

// ===========================================================================
// مهام أخدمني — طبق الأصل DeliveryBoyAkhdimniPurchaseController + AkhdimniPurchase.vue
// القائمة: الأقدم أولاً افتراضياً (FIFO) مع زر تبديل الأحدث/الأقدم.
// التفاصيل: منتج + سعر فقط، المتجر اختياري، تجهيز تلقائي، إيصال، أزرار متسلسلة.
// ===========================================================================

String akhStatusLabel(String? s) {
  switch (s) {
    case 'pending':
      return 'بانتظار';
    case 'assigned':
      return 'تم الإسناد';
    case 'picked_up':
      return 'تم الاستلام';
    case 'out_for_delivery':
      return 'خارج للتوصيل';
    case 'delivered':
      return 'تم التوصيل';
    case 'cancelled':
      return 'ملغي';
    default:
      return s ?? '';
  }
}

Color akhStatusColor(String? s) {
  switch (s) {
    case 'delivered':
      return AppColors.success;
    case 'cancelled':
      return Colors.red;
    case 'picked_up':
    case 'out_for_delivery':
      return Colors.blue;
    case 'assigned':
      return Colors.teal;
    default:
      return Colors.amber;
  }
}

// توحيد الاسم لمنع التكرار — نفس منطق الباكند normalizeItemName.
String akhNormName(String s) {
  var n = s.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  n = n.replaceAll(RegExp(r'[أإآ]'), 'ا').replaceAll('ة', 'ه').replaceAll('ى', 'ي');
  return n;
}

class AkhOrdersScreen extends StatefulWidget {
  const AkhOrdersScreen({super.key});
  @override
  State<AkhOrdersScreen> createState() => _AkhOrdersScreenState();
}

class _AkhOrdersScreenState extends State<AkhOrdersScreen> {
  bool loading = false;
  List<Map<String, dynamic>> orders = [];
  String sort = 'oldest';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    final res = await app.api.akhOrders(sort: sort);
    if (!mounted) return;
    setState(() => loading = false);
    if (!res.ok) {
      toast(context, res.message.isEmpty ? 'تعذر التحميل' : res.message);
      return;
    }
    setState(() => orders = J.maps(res.raw['data']));
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.orange,
      onRefresh: load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const Text('مهام أخدمني',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('الأقدم أولاً'),
                  selected: sort == 'oldest',
                  onSelected: (_) {
                    setState(() => sort = 'oldest');
                    load();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('الأحدث أولاً'),
                  selected: sort == 'newest',
                  onSelected: (_) {
                    setState(() => sort = 'newest');
                    load();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (orders.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.greyBorder),
              ),
              child: const Center(child: Text('لا توجد مهام مسندة إليك.')),
            )
          else
            ...orders.map((o) {
              final st = J.str(o['active_status']);
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppColors.orange, width: 1),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.push('/akhdimni/${o['id']}'),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '#${o['id']} — ${J.str(o['dropoff_name'], '—')}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 15),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: akhStatusColor(st).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                akhStatusLabel(st),
                                style: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        if (J.str(o['dropoff_address']).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(J.str(o['dropoff_address']),
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.greyText)),
                          ),
                        if (J.str(o['description']).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              J.str(o['description']),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'الإجمالي: ${J.d(o['final_total']).toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.red),
                            ),
                            Text('فتح ←',
                                style: TextStyle(
                                    color: AppColors.orange,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class AkhOrderDetailScreen extends StatefulWidget {
  const AkhOrderDetailScreen({super.key, required this.id});
  final String id;
  @override
  State<AkhOrderDetailScreen> createState() => _AkhOrderDetailScreenState();
}

class _AkhOrderDetailScreenState extends State<AkhOrderDetailScreen> {
  bool loading = true;
  bool busy = false;
  bool splitting = false;
  Map<String, dynamic> order = {};
  final quickName = TextEditingController();
  final quickPrice = TextEditingController();

  List<Map<String, dynamic>> get items =>
      J.maps(order['purchase_items']);
  bool get isPurchaseRequired => J.flag(order['is_purchase_required']);
  String get activeStatus => J.str(order['active_status']);

  double get itemsTotal {
    var t = 0.0;
    for (final it in items) {
      t += J.d(it['unit_price']) * (J.d(it['quantity'], 1) == 0 ? 1 : J.d(it['quantity'], 1));
    }
    return t;
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    quickName.dispose();
    quickPrice.dispose();
    super.dispose();
  }

  void syncTotalsLocal() {
    final t = itemsTotal;
    setState(() {
      order['purchase_amount'] = t;
      order['final_total'] =
          ((J.d(order['delivery_charge']) + t) * 100).round() / 100;
    });
  }

  bool isDuplicate(String name, [dynamic excludeId]) {
    final n = akhNormName(name);
    if (n.isEmpty) return false;
    return items.any((it) =>
        it['id'] != excludeId && akhNormName(J.str(it['name'])) == n);
  }

  Future<void> load() async {
    setState(() => loading = true);
    final res = await app.api.akhOrder(widget.id);
    if (!mounted) return;
    setState(() => loading = false);
    if (!res.ok) {
      toast(context, res.message.isEmpty ? 'تعذر التحميل' : res.message);
      return;
    }
    setState(() => order = J.map(res.raw['data']));
  }

  Future<void> autoSplit() async {
    setState(() => splitting = true);
    final res = await app.api.akhAutoSplit(id: widget.id);
    if (!mounted) return;
    setState(() => splitting = false);
    if (!res.ok) {
      toast(context, res.message.isEmpty ? 'تعذر التجهيز' : res.message);
      return;
    }
    final data = J.map(res.raw['data']);
    if (data.isNotEmpty) setState(() => order = data);
    toast(context,
        res.message.isEmpty ? 'تم تجهيز المنتجات — أدخل السعر' : res.message);
  }

  Future<void> quickAdd() async {
    final name = quickName.text.trim();
    if (name.isEmpty) {
      toast(context, 'أدخل اسم المنتج');
      return;
    }
    if (isDuplicate(name)) {
      toast(context, 'هذا المنتج موجود مسبقاً — عدّل سعره');
      return;
    }
    final price = double.tryParse(quickPrice.text.trim());
    if (price == null || price < 0) {
      toast(context, 'أدخل سعراً صحيحاً');
      return;
    }
    setState(() => busy = true);
    final res = await app.api.akhAddItem(
        id: widget.id, name: name, unitPrice: price);
    if (!mounted) return;
    setState(() => busy = false);
    if (!res.ok) {
      toast(context, res.message.isEmpty ? 'تعذر الإضافة' : res.message);
      return;
    }
    final saved = J.map(res.raw['data']);
    if (saved.isNotEmpty) {
      setState(() {
        order['purchase_items'] = [...items, saved];
        quickName.clear();
        quickPrice.clear();
      });
      syncTotalsLocal();
    }
  }

  Future<void> savePrice(Map<String, dynamic> it, String value) async {
    final price = double.tryParse(value.trim());
    if (price == null || price < 0) {
      toast(context, 'سعر غير صحيح');
      return;
    }
    final res = await app.api.akhUpdateItem(
      id: widget.id,
      itemId: it['id'],
      unitPrice: price,
      quantity: J.d(it['quantity'], 1),
    );
    if (!mounted) return;
    if (!res.ok) {
      toast(context, res.message.isEmpty ? 'تعذر الحفظ' : res.message);
      return;
    }
    final saved = J.map(res.raw['data']);
    setState(() {
      final idx = items.indexWhere((e) => e['id'] == it['id']);
      if (idx != -1 && saved.isNotEmpty) {
        final list = [...items];
        list[idx] = {...list[idx], ...saved};
        order['purchase_items'] = list;
      }
    });
    syncTotalsLocal();
  }

  Future<void> askDelete(Map<String, dynamic> it) async {
    final ok = await confirmAction(
      context,
      title: 'حذف المنتج؟',
      body: 'سيتم حذف «${J.str(it['name'])}» نهائياً.',
      confirmLabel: 'حذف',
    );
    if (!ok || !mounted) return;
    // حذف متفائل بدون إعادة تحميل.
    final list = [...items];
    final idx = list.indexWhere((e) => e['id'] == it['id']);
    Map<String, dynamic>? removed;
    if (idx != -1) {
      removed = list.removeAt(idx);
      setState(() => order['purchase_items'] = list);
      syncTotalsLocal();
    }
    final res =
        await app.api.akhDeleteItem(id: widget.id, itemId: it['id']);
    if (!mounted) return;
    if (!res.ok) {
      if (removed != null) {
        setState(() {
          final l = [...items];
          final at = idx < 0 ? 0 : (idx > l.length ? l.length : idx);
          l.insert(at, removed!);
          order['purchase_items'] = l;
        });
        syncTotalsLocal();
      }
      toast(context, res.message.isEmpty ? 'تعذر الحذف' : res.message);
    }
  }

  Future<void> openItemSheet({Map<String, dynamic>? existing}) async {
    final nameCtrl = TextEditingController(text: J.str(existing?['name']));
    final priceCtrl = TextEditingController(
        text: existing == null
            ? ''
            : J.d(existing['unit_price']).toStringAsFixed(2));
    final qtyCtrl = TextEditingController(
        text: '${J.d(existing?['quantity'], 1).toStringAsFixed(1)}');
    final storeCtrl = TextEditingController(
        text: J.str(existing?['store_name'] ??
            (existing?['seller'] is Map
                ? (existing?['seller']['store_name'] ?? '')
                : '')));
    String? pickedImagePath;

    final saved = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: StatefulBuilder(
          builder: (ctx, setSheet) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(existing == null ? 'منتج + سعر فقط' : 'تعديل المنتج',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'اسم المنتج *',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: priceCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'السعر *',
                          border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: qtyCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'الكمية', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: storeCtrl,
                decoration: const InputDecoration(
                    labelText: 'المتجر (اختياري)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final f = await ImagePicker().pickImage(
                            source: ImageSource.camera,
                            requestFullMetadata: false);
                        if (f != null) {
                          setSheet(() => pickedImagePath = f.path);
                        }
                      },
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: Text(pickedImagePath == null
                          ? 'صورة (اختياري)'
                          : 'تم اختيار صورة ✓'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, {
                    'name': nameCtrl.text.trim(),
                    'price': priceCtrl.text.trim(),
                    'qty': qtyCtrl.text.trim(),
                    'store': storeCtrl.text.trim(),
                    'image': pickedImagePath,
                  }),
                  child: const Text('حفظ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    nameCtrl.dispose();
    priceCtrl.dispose();
    qtyCtrl.dispose();
    storeCtrl.dispose();
    if (saved == null || !mounted) return;

    final name = J.str(saved['name']);
    final price = double.tryParse(J.str(saved['price']));
    if (name.isEmpty || price == null || price < 0) {
      toast(context, 'أكمل الاسم والسعر');
      return;
    }
    if (isDuplicate(name, existing?['id'])) {
      toast(context, 'هذا المنتج موجود مسبقاً — عدّل سعره');
      return;
    }
    final qty = double.tryParse(J.str(saved['qty'])) ?? 1;
    MultipartFile? img;
    if (J.str(saved['image']).isNotEmpty) {
      img = await MultipartFile.fromFile(J.str(saved['image']),
          filename: 'item.jpg');
    }
    setState(() => busy = true);
    ApiResult res;
    if (existing == null) {
      res = await app.api.akhAddItem(
        id: widget.id,
        name: name,
        unitPrice: price,
        quantity: qty <= 0 ? 1 : qty,
        storeName: J.str(saved['store']).isEmpty ? null : J.str(saved['store']),
        image: img,
      );
    } else {
      res = await app.api.akhUpdateItem(
        id: widget.id,
        itemId: existing['id'],
        name: name,
        unitPrice: price,
        quantity: qty <= 0 ? 1 : qty,
        storeName:
            J.str(saved['store']).isEmpty ? null : J.str(saved['store']),
        image: img,
      );
    }
    if (!mounted) return;
    setState(() => busy = false);
    if (!res.ok) {
      toast(context, res.message.isEmpty ? 'تعذر الحفظ' : res.message);
      return;
    }
    final item = J.map(res.raw['data']);
    if (item.isNotEmpty) {
      setState(() {
        if (existing == null) {
          order['purchase_items'] = [...items, item];
        } else {
          final list = [...items];
          final i = list.indexWhere((e) => e['id'] == existing['id']);
          if (i != -1) list[i] = {...list[i], ...item};
          order['purchase_items'] = list;
        }
      });
      syncTotalsLocal();
    }
  }

  Future<void> uploadReceipt() async {
    final file = await ImagePicker().pickImage(
        source: ImageSource.camera, requestFullMetadata: false);
    if (file == null || !mounted) return;
    setState(() => busy = true);
    final img =
        await MultipartFile.fromFile(file.path, filename: 'receipt.jpg');
    final res = await app.api.akhUploadReceipt(id: widget.id, receipt: img);
    if (!mounted) return;
    setState(() => busy = false);
    if (!res.ok) {
      toast(context, res.message.isEmpty ? 'تعذر الرفع' : res.message);
      return;
    }
    final data = J.map(res.raw['data']);
    if (data.isNotEmpty) setState(() => order = {...order, ...data});
    toast(context, 'تم رفع الإيصال');
  }

  Future<void> updateStatus(String status) async {
    final labels = {
      'picked_up': 'تم الاستلام',
      'out_for_delivery': 'خارج للتوصيل',
      'delivered': 'تم التوصيل',
      'cancelled': 'إلغاء الطلب',
    };
    final ok = await confirmAction(
      context,
      title: labels[status] ?? status,
      body: status == 'cancelled'
          ? 'سيتم إلغاء الطلب.'
          : 'تأكيد «${labels[status] ?? status}»؟',
      confirmLabel: status == 'cancelled' ? 'إلغاء الطلب' : 'تأكيد',
    );
    if (!ok || !mounted) return;
    setState(() => busy = true);
    final res = await app.api.akhUpdateStatus(id: widget.id, status: status);
    if (!mounted) return;
    setState(() => busy = false);
    if (!res.ok) {
      toast(context, res.message.isEmpty ? 'تعذر التحديث' : res.message);
      return;
    }
    final data = J.map(res.raw['data']);
    if (data.isNotEmpty) setState(() => order = {...order, ...data});
    toast(context, 'تم');
  }

  Widget statusChip() {
    final st = activeStatus;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: akhStatusColor(st).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        J.str(order['display_status']).isNotEmpty
            ? J.str(order['display_status'])
            : akhStatusLabel(st),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }

  // زر رئيسي واحد حسب المرحلة — نفس منطق الويب.
  Widget nextStepButton() {
    if (activeStatus == 'pending' || activeStatus == 'assigned') {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.amber[700]),
          onPressed: busy ? null : () => updateStatus('picked_up'),
          child: const Text('تم الاستلام'),
        ),
      );
    }
    if (activeStatus == 'picked_up') {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: busy ? null : () => updateStatus('out_for_delivery'),
          child: const Text('خارج للتوصيل'),
        ),
      );
    }
    if (activeStatus == 'out_for_delivery') {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.success),
          onPressed: busy ? null : () => updateStatus('delivered'),
          child: const Text('تم التوصيل'),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('أخدمني #${widget.id}')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : order.isEmpty
              ? const Center(child: Text('تعذر تحميل الطلب'))
              : RefreshIndicator(
                  color: AppColors.orange,
                  onRefresh: load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(J.str(order['dropoff_name'], 'عميل'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 17)),
                          ),
                          statusChip(),
                        ],
                      ),
                      if (J.str(order['dropoff_mobile']).isNotEmpty)
                        Text(J.str(order['dropoff_mobile']),
                            style: const TextStyle(
                                color: AppColors.greyText, fontSize: 13)),
                      if (J.str(order['description']).isNotEmpty)
                        Card(
                          margin: const EdgeInsets.only(top: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('طلب العميل',
                                    style: TextStyle(
                                        color: AppColors.greyText,
                                        fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(J.str(order['description']),
                                    style: const TextStyle(fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                      if (isPurchaseRequired) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('🛒 المشتريات (${items.length})',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 16)),
                            Text(
                              '${itemsTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.red),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonal(
                            onPressed: splitting ? null : autoSplit,
                            child: splitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Text('✨ تجهيز تلقائي'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: quickName,
                                decoration: const InputDecoration(
                                  hintText: 'اسم المنتج',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: quickPrice,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                  hintText: 'السعر',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: busy ? null : quickAdd,
                              child: const Icon(Icons.add),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (items.isEmpty)
                          OutlinedButton(
                            onPressed: splitting ? null : autoSplit,
                            child: const Text('✨ تجهيز تلقائي من وصف العميل'),
                          )
                        else
                          ...items.map((it) {
                            final priceCtrl = TextEditingController(
                                text: J.d(it['unit_price'])
                                        .toStringAsFixed(2) ==
                                    '0.00'
                                    ? ''
                                    : J.d(it['unit_price']).toStringAsFixed(2));
                            final store = J.str(it['store_name']).isNotEmpty
                                ? J.str(it['store_name'])
                                : (it['seller'] is Map
                                    ? J.str(it['seller']['store_name'])
                                    : '');
                            return Card(
                              margin: const EdgeInsets.only(bottom: 6),
                              color: J.d(it['unit_price']) > 0
                                  ? AppColors.white
                                  : const Color(0xFFFFFDF3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: J.d(it['unit_price']) > 0
                                      ? AppColors.greyBorder
                                      : Colors.amber,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: InkWell(
                                            onTap: () =>
                                                openItemSheet(existing: it),
                                            child: Text(
                                              '${J.str(it['name'])}${J.d(it['quantity'], 1) > 1 ? ' ×${J.d(it['quantity'], 1).toStringAsFixed(1)}' : ''}',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline,
                                              color: Colors.red),
                                          onPressed: () => askDelete(it),
                                        ),
                                      ],
                                    ),
                                    if (store.isNotEmpty)
                                      Text('🏪 $store',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.greyText)),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Text('السعر: ',
                                            style: TextStyle(fontSize: 13)),
                                        Expanded(
                                          child: TextField(
                                            controller: priceCtrl,
                                            keyboardType: const TextInputType
                                                .numberWithOptions(
                                                decimal: true),
                                            textAlign: TextAlign.center,
                                            decoration: const InputDecoration(
                                              hintText: '؟',
                                              border: OutlineInputBorder(),
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 6),
                                            ),
                                            onSubmitted: (v) =>
                                                savePrice(it, v),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '= ${(J.d(it['unit_price']) * (J.d(it['quantity'], 1) == 0 ? 1 : J.d(it['quantity'], 1))).toStringAsFixed(2)}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => openItemSheet(),
                            icon: const Icon(Icons.add),
                            label: const Text('إضافة بتفاصيل (متجر/صورة)'),
                          ),
                        ),
                        // الإيصال
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.receipt_outlined),
                            title: const Text('الإيصال'),
                            subtitle: J.str(order['receipt_image']).isNotEmpty
                                ? const Text('مرفوع ✓')
                                : const Text('لم يُرفع بعد'),
                            trailing: IconButton(
                              icon: const Icon(Icons.camera_alt_outlined),
                              onPressed: busy ? null : uploadReceipt,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              _totalRow('أجور التوصيل',
                                  J.d(order['delivery_charge'])),
                              if (isPurchaseRequired)
                                _totalRow('مبلغ الشراء',
                                    J.d(order['purchase_amount'])),
                              const Divider(),
                              _totalRow('الإجمالي النهائي',
                                  J.d(order['final_total']),
                                  big: true),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('طريقة الدفع',
                                      style: TextStyle(fontSize: 13)),
                                  Text(
                                      J.str(order['payment_method']) == 'COD'
                                          ? 'عند الاستلام'
                                          : J.str(order['payment_method']),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      nextStepButton(),
                      if (activeStatus != 'delivered' &&
                          activeStatus != 'cancelled')
                        Center(
                          child: TextButton(
                            onPressed:
                                busy ? null : () => updateStatus('cancelled'),
                            child: const Text('إلغاء الطلب',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _totalRow(String label, double value, {bool big = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: big ? 15 : 13)),
          Text(
            value.toStringAsFixed(2),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: big ? 17 : 14,
              color: big ? Colors.red : null,
            ),
          ),
        ],
      ),
    );
  }
}
