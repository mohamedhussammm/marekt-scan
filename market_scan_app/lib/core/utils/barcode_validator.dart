import 'package:flutter/foundation.dart';

/// Utility to validate scanned barcodes to prevent misreads and wrong numbers.
class BarcodeValidator {
  /// Check if the barcode string is a valid, correct scan.
  /// Returns true if it passes all validation checks, false if it should be discarded.
  static bool isValid(String barcode) {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) return false;

    // Reject extremely short or long inputs
    if (trimmed.length < 4 || trimmed.length > 40) {
      debugPrint('Barcode rejected: length out of bounds (${trimmed.length})');
      return false;
    }

    // Check if the barcode is purely numeric
    final isNumeric = RegExp(r'^[0-9]+$').hasMatch(trimmed);

    if (isNumeric) {
      final len = trimmed.length;

      // Numeric barcodes in retail are typically EAN-13 (13), UPC-A (12), EAN-8 (8), or UPC-E (6 or 8)
      // Any other digit length (like 5, 7, 9, 10, 11) is almost certainly a misread or truncated scan.
      if (len != 6 && len != 8 && len != 12 && len != 13) {
        debugPrint('Barcode rejected: suspicious numeric length ($len)');
        return false;
      }

      // Checksum validation for EAN-13, UPC-A, and EAN-8
      if (len == 8 || len == 12 || len == 13) {
        if (!_validateChecksum(trimmed)) {
          debugPrint('Barcode rejected: checksum invalid for EAN/UPC ($trimmed)');
          return false;
        }
      }
    }

    return true;
  }

  /// Universal EAN/UPC checksum validation (EAN-13, EAN-8, UPC-A)
  static bool _validateChecksum(String barcode) {
    try {
      final digits = barcode.split('').map(int.parse).toList();
      final length = digits.length;
      final actualCheckDigit = digits[length - 1];

      int sum = 0;
      bool multiplyByThree = true;

      // Alternate weights (3, 1, 3, 1...) starting from the digit immediately left of the check digit
      for (int i = length - 2; i >= 0; i--) {
        final digit = digits[i];
        if (multiplyByThree) {
          sum += digit * 3;
        } else {
          sum += digit * 1;
        }
        multiplyByThree = !multiplyByThree;
      }

      final calculatedCheckDigit = (10 - (sum % 10)) % 10;
      return calculatedCheckDigit == actualCheckDigit;
    } catch (_) {
      return false;
    }
  }
}
