import 'package:flutter/foundation.dart';

/// Where a balance value came from, so the UI can distinguish a fresh RPC read
/// from cached data.
enum BalanceSource {
  /// Read directly from a chain JSON-RPC endpoint.
  rpc,

  /// Value that was previously read and is being shown while a refresh runs.
  cached,
}

/// A native token balance in its smallest unit (wei).
@immutable
class NativeBalance {
  const NativeBalance({
    required this.wei,
    required this.fetchedAt,
    this.source = BalanceSource.rpc,
  });

  /// Balance in wei as an arbitrary precision integer. Never a double.
  final BigInt wei;

  final DateTime fetchedAt;

  final BalanceSource source;
}

/// Integer only helpers to convert and display wei values.
///
/// Floating point arithmetic is never used, so no precision is lost for
/// financial values.
abstract final class BalanceFormatter {
  static const String thousandsSeparator = ',';

  /// Parses a JSON-RPC hexadecimal quantity such as `0x38d7ea4c68000`.
  static BigInt parseWeiFromHex(String raw) {
    var value = raw.trim();
    if (value.toLowerCase().startsWith('0x')) {
      value = value.substring(2);
    }
    if (value.isEmpty || !_hexPattern.hasMatch(value)) {
      throw FormatException('Invalid hexadecimal balance value: $raw');
    }
    return BigInt.parse(value, radix: 16);
  }

  static final RegExp _hexPattern = RegExp(r'^[0-9a-fA-F]+$');

  /// Converts [wei] into a decimal string with at most [maxFractionDigits]
  /// fraction digits, rounded half-up.
  static String format({
    required BigInt wei,
    required int decimals,
    int maxFractionDigits = 6,
  }) {
    if (decimals < 0) {
      throw ArgumentError.value(decimals, 'decimals', 'must not be negative');
    }
    final digits = maxFractionDigits < 0 ? 0 : maxFractionDigits;
    final negative = wei.isNegative;
    final absolute = wei.abs();

    BigInt whole;
    BigInt fraction;
    int fractionDigits;

    if (digits < decimals) {
      // Round to `digits` fraction digits before splitting.
      final divisor = BigInt.from(10).pow(decimals - digits);
      var units = absolute ~/ divisor;
      final remainder = absolute % divisor;
      if (remainder * BigInt.two >= divisor) {
        units += BigInt.one;
      }
      final base = BigInt.from(10).pow(digits);
      whole = units ~/ base;
      fraction = units % base;
      fractionDigits = digits;
    } else {
      final base = BigInt.from(10).pow(decimals);
      whole = absolute ~/ base;
      fraction = absolute % base;
      fractionDigits = decimals;
    }

    var fractionString = fractionDigits == 0
        ? ''
        : fraction.toString().padLeft(fractionDigits, '0');
    fractionString = _trimTrailingZeros(fractionString);

    final body = fractionString.isEmpty
        ? _group(whole.toString())
        : '${_group(whole.toString())}.$fractionString';
    return negative ? '-$body' : body;
  }

  /// Same as [format] with the token symbol appended.
  static String formatWithSymbol({
    required BigInt wei,
    required int decimals,
    required String symbol,
    int maxFractionDigits = 6,
  }) => '${format(wei: wei, decimals: decimals, maxFractionDigits: maxFractionDigits)} $symbol';

  static String _trimTrailingZeros(String value) {
    var end = value.length;
    while (end > 0 && value.codeUnitAt(end - 1) == 0x30) {
      end--;
    }
    return value.substring(0, end);
  }

  static String _group(String digits) {
    if (digits.length <= 4) return digits;
    final buffer = StringBuffer();
    final firstGroup = digits.length % 3 == 0 ? 3 : digits.length % 3;
    buffer.write(digits.substring(0, firstGroup));
    for (var i = firstGroup; i < digits.length; i += 3) {
      buffer.write(thousandsSeparator);
      buffer.write(digits.substring(i, i + 3));
    }
    return buffer.toString();
  }
}
