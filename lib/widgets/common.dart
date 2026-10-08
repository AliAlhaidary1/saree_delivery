import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_controller.dart';
import '../core/brand_config.dart';
import '../theme/app_colors.dart';
import 'branded_skeleton.dart';

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.check_circle_outline,
              color: AppColors.orange,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      backgroundColor: AppColors.navy,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.all(16),
    ),
  );
}

class BusySpinner extends StatelessWidget {
  const BusySpinner({super.key, this.color, this.brand});
  final Color? color;
  final BrandConfig? brand;

  @override
  Widget build(BuildContext context) {
    final c = color ?? (brand ?? app.brand).orange;
    return SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(strokeWidth: 2.4, color: c),
    );
  }
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  String? body,
  String confirmLabel = 'تأكيد',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.help_outline,
              color: AppColors.orange,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title)),
        ],
      ),
      content: body == null ? null : Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok == true;
}

Widget labeledField(
  TextEditingController controller,
  String label, {
  int maxLines = 1,
  TextInputType? type,
  bool obscure = false,
  bool toggleObscure = false,
}) {
  if (toggleObscure) {
    return _ObscureField(controller: controller, label: label);
  }
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      maxLines: maxLines,
      obscureText: obscure,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );
}

class _ObscureField extends StatefulWidget {
  const _ObscureField({required this.controller, required this.label});
  final TextEditingController controller;
  final String label;

  @override
  State<_ObscureField> createState() => _ObscureFieldState();
}

class _ObscureFieldState extends State<_ObscureField> {
  bool hidden = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: widget.controller,
        obscureText: hidden,
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            onPressed: () => setState(() => hidden = !hidden),
            icon: Icon(
              hidden
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ),
      ),
    );
  }
}

class Refreshable extends StatelessWidget {
  const Refreshable({super.key, required this.onRefresh, required this.child});
  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(height: constraints.maxHeight, child: child),
        ),
      ),
    );
  }
}

Future<void> copyText(
  BuildContext context,
  String value, [
  String ok = 'تم النسخ',
]) async {
  if (value.trim().isEmpty) return;
  await Clipboard.setData(ClipboardData(text: value));
  if (context.mounted) toast(context, ok);
}

Future<void> openTel(String raw) async {
  final phone = raw.replaceAll(RegExp(r'[^0-9+]'), '');
  if (phone.isEmpty) return;
  try {
    await launchUrl(Uri.parse('tel:$phone'));
  } catch (_) {}
}

Future<void> openSms(String raw) async {
  final phone = raw.replaceAll(RegExp(r'[^0-9+]'), '');
  if (phone.isEmpty) return;
  try {
    await launchUrl(Uri.parse('sms:$phone'));
  } catch (_) {}
}

Future<void> openMail(String raw) async {
  final email = raw.trim();
  if (email.isEmpty) return;
  try {
    await launchUrl(Uri.parse('mailto:$email'));
  } catch (_) {}
}

String? dropdownId(String? id, List<Map<String, dynamic>> items) {
  if (id == null || id.isEmpty) return null;
  return items.any((item) => '${item['id']}' == id) ? id : null;
}

Future<String?> pickDate(
  BuildContext context, {
  DateTime? initial,
  bool withTime = false,
}) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initial ?? DateTime.now(),
    firstDate: DateTime(2020),
    lastDate: DateTime(2035),
  );
  if (date == null) return null;
  if (!withTime) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
  if (!context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial ?? DateTime.now()),
  );
  final hour = time?.hour ?? 0;
  final minute = time?.minute ?? 0;
  return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00';
}

class EmptyBox extends StatelessWidget {
  const EmptyBox(
    this.text, {
    super.key,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });
  final String text;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.orange.withValues(alpha: 0.14),
                    AppColors.navy.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: AppColors.orange),
            ),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// حالة الجلب الموحدة — نسخة طبق الأصل من تطبيق التاجر (FetchBody)
/// loading / error / empty + Refreshable + retry — تُستخدم في كل شاشات القوائم.
///
/// التحميل يعرض shimmer يحاكي شكل البطاقات + انتقال ناعم للمحتوى.
class FetchBody extends StatelessWidget {
  const FetchBody({
    super.key,
    required this.loading,
    required this.onRefresh,
    required this.isEmpty,
    required this.child,
    this.error,
    this.emptyText = 'لا توجد بيانات',
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.skeleton,
    this.skeletonCount = 4,
  });

  final bool loading;
  final Future<void> Function() onRefresh;
  final bool isEmpty;
  final Widget child;
  final String? error;
  final String emptyText;
  final IconData emptyIcon;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;
  final Widget? skeleton;
  final int skeletonCount;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return skeleton ??
          BrandedSkeletonList(brand: app.brand, count: skeletonCount);
    }
    if (error != null && error!.isNotEmpty) {
      return Refreshable(
        onRefresh: onRefresh,
        child: EmptyBox(
          error!,
          icon: Icons.wifi_off_outlined,
          actionLabel: 'إعادة المحاولة',
          onAction: () {
            onRefresh();
          },
        ),
      );
    }
    if (isEmpty) {
      return Refreshable(
        onRefresh: onRefresh,
        child: EmptyBox(
          emptyText,
          icon: emptyIcon,
          actionLabel: emptyActionLabel,
          onAction: onEmptyAction,
        ),
      );
    }
    // انتقال ناعم من الهيكل إلى المحتوى بدل الظهور المفاجئ
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.orange,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: child,
      ),
    );
  }
}
