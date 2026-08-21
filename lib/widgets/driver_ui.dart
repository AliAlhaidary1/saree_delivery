import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';

/// High-visibility online/offline duty toggle with glowing indicator.
class DutyToggle extends StatefulWidget {
  const DutyToggle({
    super.key,
    required this.isOnline,
    required this.onChanged,
  });

  final bool isOnline;
  final ValueChanged<bool> onChanged;

  @override
  State<DutyToggle> createState() => _DutyToggleState();
}

class _DutyToggleState extends State<DutyToggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.isOnline) _pulse.repeat();
  }

  @override
  void didUpdateWidget(DutyToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOnline && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!widget.isOnline) {
      _pulse.stop();
      _pulse.reset();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          if (widget.isOnline)
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) {
                final glow = 0.4 + (_pulse.value * 0.6);
                return Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.orange,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.orange.withValues(alpha: glow),
                        blurRadius: 12,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                );
              },
            )
          else
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.greyText.withValues(alpha: 0.5),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isOnline ? 'متصل — جاهز للتوصيل' : 'غير متصل',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  widget.isOnline
                      ? 'تستقبل طلبات التوصيل الآن'
                      : 'فعّل الاتصال لاستقبال الطلبات',
                  style: TextStyle(
                    color: AppColors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: widget.isOnline,
            onChanged: widget.onChanged,
            activeThumbColor: AppColors.orange,
            activeTrackColor: AppColors.orange.withValues(alpha: 0.4),
            inactiveThumbColor: AppColors.greyText,
            inactiveTrackColor: AppColors.navyLight,
          ),
        ],
      ),
    );
  }
}

/// Compact KPI stat card for dashboard.
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.accent = AppColors.orange,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.greyBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.greyText),
          ),
        ],
      ),
    );
  }
}

/// Quick-access shortcut tile on dashboard.
class QuickActionTile extends StatelessWidget {
  const QuickActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.greyBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.navy, size: 24),
                  if (badge != null && badge!.isNotEmpty) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.orange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const Spacer(),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Order lifecycle progress timeline.
class OrderProgressTimeline extends StatelessWidget {
  const OrderProgressTimeline({
    super.key,
    required this.steps,
    required this.currentIndex,
  });

  final List<String> steps;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.greyBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'مسار التوصيل',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(steps.length, (i) {
            final done = i < currentIndex;
            final active = i == currentIndex;
            final isLast = i == steps.length - 1;
            return _TimelineStep(
              label: steps[i],
              done: done,
              active: active,
              isLast: isLast,
            );
          }),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.label,
    required this.done,
    required this.active,
    required this.isLast,
  });

  final String label;
  final bool done;
  final bool active;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final dotColor = done
        ? AppColors.success
        : active
        ? AppColors.orange
        : AppColors.greyBorder;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? AppColors.orange.withValues(alpha: 0.15)
                      : done
                      ? AppColors.success.withValues(alpha: 0.15)
                      : AppColors.greyBg,
                  border: Border.all(color: dotColor, width: 2),
                ),
                child: Icon(
                  done
                      ? Icons.check
                      : active
                      ? Icons.local_shipping
                      : Icons.circle,
                  size: done ? 16 : active ? 14 : 8,
                  color: dotColor,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: done ? AppColors.success : AppColors.greyBorder,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active || done ? AppColors.navy : AppColors.greyText,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Prominent orange CTA button for driver actions.
class DriverActionButton extends StatelessWidget {
  const DriverActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: AppColors.white,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Text(label),
            ],
          );

    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.orange,
        minimumSize: Size(expand ? double.infinity : 64, 52),
      ),
      child: child,
    );
  }
}

/// Slide-to-confirm widget for pickup/delivery actions.
class SlideToConfirm extends StatefulWidget {
  const SlideToConfirm({
    super.key,
    required this.label,
    required this.onConfirmed,
  });

  final String label;
  final VoidCallback onConfirmed;

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm> {
  double _drag = 0;
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag = constraints.maxWidth - 56;
        final progress = maxDrag > 0 ? (_drag / maxDrag).clamp(0.0, 1.0) : 0.0;

        return Container(
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: 1 - progress,
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: AppColors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Positioned(
                left: 4 + _drag,
                child: GestureDetector(
                  onHorizontalDragUpdate: _done
                      ? null
                      : (d) {
                          setState(() {
                            _drag = (_drag + d.delta.dx).clamp(0.0, maxDrag);
                          });
                          if (_drag >= maxDrag * 0.92) {
                            setState(() => _done = true);
                            widget.onConfirmed();
                          }
                        },
                  onHorizontalDragEnd: _done
                      ? null
                      : (_) {
                          if (!_done) setState(() => _drag = 0);
                        },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.orange.withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(
                      _done ? Icons.check : Icons.chevron_left,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Full-screen incoming order alert with countdown.
class IncomingOrderOverlay extends StatefulWidget {
  const IncomingOrderOverlay({
    super.key,
    required this.order,
    required this.onAccept,
    required this.onDecline,
    this.countdownSeconds = 30,
  });

  final Map<String, dynamic> order;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final int countdownSeconds;

  @override
  State<IncomingOrderOverlay> createState() => _IncomingOrderOverlayState();
}

class _IncomingOrderOverlayState extends State<IncomingOrderOverlay> {
  late int _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.countdownSeconds;
    _tick();
  }

  Future<void> _tick() async {
    while (_remaining > 0 && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _remaining--);
    }
    if (mounted && _remaining <= 0) widget.onDecline();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return Material(
      color: AppColors.navy.withValues(alpha: 0.95),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.orange, width: 3),
                ),
                child: Center(
                  child: Text(
                    '$_remaining',
                    style: const TextStyle(
                      color: AppColors.orange,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'طلب توصيل جديد!',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 32),
              _infoCard(
                Icons.storefront_outlined,
                'نقطة الاستلام',
                '${order['store_name'] ?? order['seller_name'] ?? 'المتجر'}',
              ),
              const SizedBox(height: 12),
              _infoCard(
                Icons.location_on_outlined,
                'عنوان التوصيل',
                '${order['address'] ?? '—'}',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _metricBox(
                      'المسافة',
                      '${order['distance'] ?? order['delivery_distance'] ?? '—'}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _metricBox(
                      'الأجرة',
                      '${order['delivery_charge'] ?? order['final_total'] ?? '—'}',
                      highlight: true,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              DriverActionButton(
                label: 'قبول الطلب',
                icon: Icons.check_circle_outline,
                onPressed: widget.onAccept,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: widget.onDecline,
                child: const Text(
                  'تجاهل',
                  style: TextStyle(color: AppColors.greyText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard(IconData icon, String title, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navyLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.orange, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricBox(String label, String value, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.orange.withValues(alpha: 0.15)
            : AppColors.navyLight,
        borderRadius: BorderRadius.circular(16),
        border: highlight
            ? Border.all(color: AppColors.orange.withValues(alpha: 0.4))
            : null,
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.white.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: highlight ? AppColors.orange : AppColors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Proof-of-delivery photo upload modal.
class ProofOfDeliverySheet extends StatelessWidget {
  const ProofOfDeliverySheet({
    super.key,
    required this.onTakePhoto,
    required this.onFromGallery,
    this.photoPath,
  });

  final VoidCallback onTakePhoto;
  final VoidCallback onFromGallery;
  final String? photoPath;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.greyBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'إثبات التسليم',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'التقط صورة للطرد عند التسليم',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.greyText),
          ),
          const SizedBox(height: 20),
          if (photoPath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildPhoto(photoPath!),
            ),
          if (photoPath != null) const SizedBox(height: 16),
          DriverActionButton(
            label: 'التقاط صورة',
            icon: Icons.camera_alt_outlined,
            onPressed: onTakePhoto,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onFromGallery,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('من المعرض'),
          ),
        ],
      ),
    );
  }
}

Widget _buildPhoto(String path) {
  if (path.startsWith('http')) {
    return Image.network(
      path,
      height: 160,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _photoPlaceholder(),
    );
  }
  return Image.file(
    File(path),
    height: 160,
    width: double.infinity,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => _photoPlaceholder(),
  );
}

Widget _photoPlaceholder() {
  return Container(
    height: 160,
    color: AppColors.greyBg,
    child: const Icon(Icons.check_circle, color: AppColors.success, size: 48),
  );
}

/// Contact action row for customer communication.
class ContactActions extends StatelessWidget {
  const ContactActions({
    super.key,
    required this.phone,
    required this.onCall,
    required this.onMessage,
    this.onCopy,
  });

  final String phone;
  final VoidCallback onCall;
  final VoidCallback onMessage;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ContactBtn(
            icon: Icons.phone,
            label: 'اتصال',
            color: AppColors.orange,
            onTap: onCall,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ContactBtn(
            icon: Icons.chat_bubble_outline,
            label: 'رسالة',
            color: AppColors.navy,
            onTap: onMessage,
          ),
        ),
        if (onCopy != null) ...[
          const SizedBox(width: 8),
          _ContactBtn(
            icon: Icons.copy,
            label: '',
            color: AppColors.greyText,
            onTap: onCopy!,
            compact: true,
          ),
        ],
      ],
    );
  }
}

class _ContactBtn extends StatelessWidget {
  const _ContactBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: 14,
            horizontal: compact ? 14 : 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Styled order list card.
class OrderListCard extends StatelessWidget {
  const OrderListCard({
    super.key,
    required this.orderId,
    required this.customerName,
    required this.address,
    required this.total,
    required this.onTap,
    this.status,
    this.isActive = false,
  });

  final String orderId;
  final String customerName;
  final String address;
  final String total;
  final VoidCallback onTap;
  final String? status;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? AppColors.orange : AppColors.greyBorder,
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.orange.withValues(alpha: 0.12)
                      : AppColors.greyBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isActive ? Icons.local_shipping : Icons.receipt_long,
                  color: isActive ? AppColors.orange : AppColors.navy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '#$orderId',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                        if (status != null && status!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.orange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customerName,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.greyText,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                total,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.orange,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section header used across screens.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          if (action != null && onAction != null) ...[
            const Spacer(),
            TextButton(onPressed: onAction, child: Text(action!)),
          ],
        ],
      ),
    );
  }
}

/// Opens Google Maps with the given address.
Future<void> openMapsNavigation(String address) async {
  if (address.trim().isEmpty) return;
  final encoded = Uri.encodeComponent(address);
  final uri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=$encoded&travelmode=driving',
  );
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Determine timeline step index from order status name.
int timelineIndexFromStatus(String status, List<String> steps) {
  final lower = status.toLowerCase();
  if (lower.contains('deliver') ||
      lower.contains('تسليم') ||
      lower.contains('مكتمل')) {
    return steps.length - 1;
  }
  if (lower.contains('way') ||
      lower.contains('في الطريق') ||
      lower.contains('transit')) {
    return 3;
  }
  if (lower.contains('pick') ||
      lower.contains('استلام') ||
      lower.contains('picked')) {
    return 2;
  }
  if (lower.contains('arriv') || lower.contains('وصل')) {
    return 1;
  }
  return 0;
}

/// Default delivery lifecycle steps (Arabic).
const kDeliverySteps = [
  'تم القبول',
  'وصلت للمتجر',
  'تم استلام الطلب',
  'في الطريق',
  'تم التسليم',
];

/// Stylized map with orange route line.
class DeliveryMapView extends StatelessWidget {
  const DeliveryMapView({
    super.key,
    required this.pickupLabel,
    required this.dropoffLabel,
    this.onNavigate,
    this.height = 280,
  });

  final String pickupLabel;
  final String dropoffLabel;
  final VoidCallback? onNavigate;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          children: [
            CustomPaint(
              size: Size.infinite,
              painter: _MapPainter(),
            ),
            Positioned(
              top: 16,
              right: 16,
              left: 16,
              child: Row(
                children: [
                  _MapPin(label: pickupLabel, isPickup: true),
                ],
              ),
            ),
            Positioned(
              bottom: 56,
              right: 16,
              left: 16,
              child: _MapPin(label: dropoffLabel, isPickup: false),
            ),
            if (onNavigate != null)
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: DriverActionButton(
                  label: 'التنقل عبر خرائط جوجل',
                  icon: Icons.navigation,
                  onPressed: onNavigate,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.label, required this.isPickup});

  final String label;
  final bool isPickup;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.15),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPickup ? Icons.storefront : Icons.home,
            color: isPickup ? AppColors.navy : AppColors.orange,
            size: 18,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFE8EDF2);
    canvas.drawRect(Offset.zero & size, bg);

    final gridPaint = Paint()
      ..color = const Color(0xFFD1D9E0)
      ..strokeWidth = 0.8;
    const step = 40.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final start = Offset(size.width * 0.25, size.height * 0.3);
    final end = Offset(size.width * 0.7, size.height * 0.75);
    final control = Offset(size.width * 0.5, size.height * 0.2);

    final routeShadow = Paint()
      ..color = AppColors.orange.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final route = Paint()
      ..color = AppColors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);

    canvas.drawPath(path, routeShadow);
    canvas.drawPath(path, route);

    _drawDot(canvas, start, AppColors.navy);
    _drawDot(canvas, end, AppColors.orange);
  }

  void _drawDot(Canvas canvas, Offset center, Color color) {
    canvas.drawCircle(center, 10, Paint()..color = color);
    canvas.drawCircle(center, 5, Paint()..color = AppColors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Floating bottom card for live delivery status on map screen.
class DeliveryFloatingCard extends StatelessWidget {
  const DeliveryFloatingCard({
    super.key,
    required this.storeName,
    required this.orderId,
    required this.distance,
    required this.earnings,
    required this.onNavigate,
    required this.onViewDetails,
  });

  final String storeName;
  final String orderId;
  final String distance;
  final String earnings;
  final VoidCallback onNavigate;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.storefront,
                  color: AppColors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      storeName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.navy,
                      ),
                    ),
                    Text(
                      'طلب #$orderId',
                      style: const TextStyle(
                        color: AppColors.greyText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    earnings,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: AppColors.orange,
                    ),
                  ),
                  Text(
                    distance,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.greyText,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DriverActionButton(
                  label: 'التنقل',
                  icon: Icons.navigation,
                  onPressed: onNavigate,
                  expand: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onViewDetails,
                  child: const Text('التفاصيل'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Horizontal filter chips for orders list.
class FilterChips extends StatelessWidget {
  const FilterChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final int? selected;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _chip('الكل', null),
          _chip('جارية', 1),
          _chip('سابقة', 0),
        ],
      ),
    );
  }

  Widget _chip(String label, int? value) {
    final active = selected == value;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: FilterChip(
        label: Text(label),
        selected: active,
        onSelected: (_) => onSelected(value),
        selectedColor: AppColors.orange.withValues(alpha: 0.15),
        checkmarkColor: AppColors.orange,
        labelStyle: TextStyle(
          color: active ? AppColors.orange : AppColors.navy,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        ),
        side: BorderSide(
          color: active ? AppColors.orange : AppColors.greyBorder,
        ),
      ),
    );
  }
}

/// Account menu item with navy/orange styling.
class AccountMenuItem extends StatelessWidget {
  const AccountMenuItem({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.error : AppColors.navy;
    return Material(
      color: AppColors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.greyText,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_left,
                color: AppColors.greyText.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Format a percentage string safely.
String formatPercent(dynamic value) {
  if (value == null) return '—';
  final n = double.tryParse('$value');
  if (n == null) return '$value%';
  if (n <= 1) return '${(n * 100).toStringAsFixed(0)}%';
  return '${n.toStringAsFixed(0)}%';
}

/// Safe earnings display from dashboard data.
String formatEarnings(Map<String, dynamic> dashboard) {
  return '${dashboard['today_earnings'] ?? dashboard['today_balance'] ?? dashboard['balance'] ?? '0'}';
}
