import 'package:flutter_test/flutter_test.dart';
import 'package:hy_academy/main.dart';

void main() {
  group('isSubscriptionActive', () {
    test('returns false when there is no activation record', () {
      expect(isSubscriptionActive(null), isFalse);
    });

    test('returns false when an administrator disabled the subscription', () {
      expect(
        isSubscriptionActive({'disabled': true}),
        isFalse,
      );
    });

    test('keeps legacy records without an activation date active', () {
      expect(isSubscriptionActive({'disabled': false}), isTrue);
    });

    test('honors the configured subscription duration', () {
      final now = DateTime.now();
      final activeRecord = {
        'activatedAt': now.subtract(const Duration(days: 3)).toIso8601String(),
        'durationDays': 30,
      };
      final expiredRecord = {
        'activatedAt': now.subtract(const Duration(days: 10)).toIso8601String(),
        'durationDays': 2,
      };

      expect(isSubscriptionActive(activeRecord), isTrue);
      expect(isSubscriptionActive(expiredRecord), isFalse);
    });
  });
}
