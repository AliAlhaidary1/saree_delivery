import 'dart:async';

/// OTP resend helpers for the forgot-password flow (hardcoded Arabic, no i18n).

enum OtpSendKind { hardLimit, cooldown, error }

const String kOtpSuccessMessage = 'تم إرسال الرمز بنجاح';
const String kOtpReassureHint = 'لم يصلك الرمز؟ لا تقلق، قد يتأخر قليلاً وسيصلك';
const String kOtpHardLimitFallback =
    'تجاوزت الحد المسموح لطلب رموز التحقق، يرجى المحاولة لاحقاً';
const String kOtpResendLabel = 'إعادة إرسال الرمز';

final RegExp _hardReason = RegExp(
  r'rate.?limit|limit.?exceed|hourly|hour.?limit|quota|otp.?(block|banned|suspend)|send.?(block|banned|suspend)',
  caseSensitive: false,
);
final RegExp _hardMessage = RegExp(
  r'الساعي|اليومي|تجاوزت الحد|تجاوز.*الحد|exceed.*limit|limit.*exceed|hourly|daily limit|maximum.*(attempt|request|code)',
  caseSensitive: false,
);
final RegExp _coolReason = RegExp(
  r'rate.?limit|too.?many|throttl|cooldown|limit.?exceed|hourly|otp.?(limit|cooldown|block)|send.?(limit|cooldown|block)',
  caseSensitive: false,
);
final RegExp _coolMessage = RegExp(
  r'انتظر|ثوان|ثانية|دقيقة|الساعي|ساعة|متاح|لاحق|مؤقت|كثير|الحد|إعادة|wait|second|minute|hour|availab|later|temporar|many|limit|throttl|too many|try again|retry|cooldown|rate',
  caseSensitive: false,
);

bool _isDioGenericMessage(String s) {
  final low = s.toLowerCase();
  if (low.contains('request failed')) return true;
  if (low.startsWith('dio')) return true;
  if (low.contains('dioexception')) return true;
  if (low.contains('xmlhttprequest')) return true;
  return false;
}

/// تطبيع الأرقام العربية/الفارسية — مثل تطبيق التاجر.
String normalizeOtpDigits(String input) {
  const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  var out = input;
  for (var i = 0; i < 10; i++) {
    out = out.replaceAll(arabic[i], '$i').replaceAll(persian[i], '$i');
  }
  return out;
}

String extractOtpReason(Map<String, dynamic> raw) {
  final top = raw['reason'];
  if (top is String && top.trim().isNotEmpty) return top.trim();
  final data = raw['data'];
  if (data is Map) {
    final r = data['reason'];
    if (r is String && r.trim().isNotEmpty) return r.trim();
  }
  final err = raw['error'];
  if (err is Map) {
    final det = err['details'];
    if (det is Map) {
      final r = det['reason'];
      if (r is String && r.trim().isNotEmpty) return r.trim();
      final nested = det['data'];
      if (nested is Map) {
        final rr = nested['reason'];
        if (rr is String && rr.trim().isNotEmpty) return rr.trim();
      }
    }
  }
  return '';
}

int _toRetryInt(dynamic value) {
  if (value == null) return 0;
  int? parsed;
  if (value is int) {
    parsed = value;
  } else if (value is num) {
    parsed = value.toInt();
  } else {
    parsed = int.tryParse('$value'.trim());
  }
  if (parsed != null && parsed > 0 && parsed <= 600) return parsed;
  return 0;
}

int extractOtpRetryAfter(Map<String, dynamic> raw, [String? message]) {
  final candidates = <dynamic>[
    raw['retry_after'],
    raw['retryAfter'],
  ];
  final data = raw['data'];
  if (data is Map) candidates.add(data['retry_after']);
  final err = raw['error'];
  if (err is Map) {
    final det = err['details'];
    if (det is Map) {
      candidates.add(det['retry_after']);
      final nested = det['data'];
      if (nested is Map) candidates.add(nested['retry_after']);
    }
  }
  for (final c in candidates) {
    final v = _toRetryInt(c);
    if (v > 0) return v;
  }
  final text = normalizeOtpDigits(message ?? '');
  if (text.isNotEmpty) {
    final m = RegExp(r'\d+').firstMatch(text);
    if (m != null) {
      final parsed = int.tryParse(m.group(0)!);
      if (parsed != null && parsed > 0 && parsed <= 600) return parsed;
    }
  }
  return 0;
}

String extractOtpMessage(Map<String, dynamic> raw) {
  dynamic m = raw['message'] ?? raw['msg'];
  String s = '';
  if (m is String) {
    s = m.trim();
  } else if (m != null) {
    s = '$m'.trim();
  }
  if (s.isNotEmpty && !_isDioGenericMessage(s)) return s;
  final err = raw['error'];
  if (err is Map) {
    final det = err['details'];
    if (det is Map) {
      dynamic dm = det['message'] ?? det['msg'];
      String ds = '';
      if (dm is String) {
        ds = dm.trim();
      } else if (dm != null) {
        ds = '$dm'.trim();
      }
      if (ds.isNotEmpty && !_isDioGenericMessage(ds)) return ds;
    }
  }
  if (s.isNotEmpty && !_isDioGenericMessage(s)) return s;
  return '';
}

int extractOtpStatus(Map<String, dynamic> raw) {
  final v = raw['status'];
  if (v is int && v != 0) return v;
  final parsed = int.tryParse('$v');
  if (parsed != null && parsed != 0) return parsed;
  final err = raw['error'];
  if (err is Map) {
    final hs = err['httpStatus'] ?? err['http_status'] ?? err['status'];
    if (hs is int && hs != 0) return hs;
    final hp = int.tryParse('$hs');
    if (hp != null && hp != 0) return hp;
  }
  return parsed ?? 0;
}

OtpSendKind classifyOtpSend({
  required String reason,
  required String message,
  required int retryAfter,
  required int status,
}) {
  final hasShortRetry = retryAfter >= 1 && retryAfter <= 300;
  if (!hasShortRetry) {
    if (_hardReason.hasMatch(reason) || _hardMessage.hasMatch(message)) {
      return OtpSendKind.hardLimit;
    }
  }
  if (status == 429) return OtpSendKind.cooldown;
  if (retryAfter > 0) return OtpSendKind.cooldown;
  if (_coolReason.hasMatch(reason)) return OtpSendKind.cooldown;
  if (_coolMessage.hasMatch(message)) return OtpSendKind.cooldown;
  return OtpSendKind.error;
}

OtpSendKind classifyOtpResult(Map<String, dynamic> raw) {
  final message = extractOtpMessage(raw);
  final reason = extractOtpReason(raw);
  final retryAfter = extractOtpRetryAfter(raw, message);
  final status = extractOtpStatus(raw);
  return classifyOtpSend(
    reason: reason,
    message: message,
    retryAfter: retryAfter,
    status: status,
  );
}

class OtpResendGate {
  DateTime allowedAt = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _unlockTimer;
  Timer? _bgTimer;
  int bgTries = 0;
  static const int maxBackgroundTries = 2;

  bool get canSend => !DateTime.now().isBefore(allowedAt);
  bool get canBackground => bgTries < maxBackgroundTries;

  void lock([int extraSec = 0, void Function()? onUnlock]) {
    final secs = extraSec > 60 ? extraSec : 60;
    allowedAt = DateTime.now().add(Duration(seconds: secs));
    _unlockTimer?.cancel();
    if (onUnlock != null) {
      _unlockTimer = Timer(Duration(seconds: secs), onUnlock);
    }
  }

  void scheduleBackground(Duration delay, Future<void> Function() task) {
    if (bgTries >= maxBackgroundTries) return;
    _bgTimer?.cancel();
    _bgTimer = Timer(delay, () async {
      bgTries += 1;
      await task();
    });
  }

  void cancelBackground() {
    _bgTimer?.cancel();
    _bgTimer = null;
  }

  void resetBackground() {
    bgTries = 0;
    cancelBackground();
  }

  void dispose() {
    _unlockTimer?.cancel();
    _bgTimer?.cancel();
  }
}
