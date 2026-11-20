import 'package:flutter_test/flutter_test.dart';
import 'package:novopharma/models/product.dart';

void main() {
  group('Product.normalizeSku', () {
    test('strips leading zeros on numeric barcodes', () {
      expect(Product.normalizeSku('0012345678905'), '12345678905');
      expect(Product.normalizeSku('012345678905'), '12345678905');
      expect(Product.normalizeSku(' 3600523614059 '), '3600523614059');
    });

    test('keeps non-numeric codes, case-insensitive', () {
      expect(Product.normalizeSku(' AB-001 '), 'ab-001');
    });
  });

  group('Product.skuLookupCandidates', () {
    test('UPC-A scanned on Android finds EAN-13 stored value', () {
      final c = Product.skuLookupCandidates('012345678905');
      expect(c, contains('0012345678905'));
      expect(c, contains('12345678905'));
      expect(c, contains(12345678905));
    });

    test('EAN-13 with leading zero finds Excel-stripped value', () {
      final c = Product.skuLookupCandidates('0761234567890');
      expect(c, contains('761234567890'));
      expect(c, contains('0761234567890'));
    });

    test('stays within Firestore whereIn limit', () {
      expect(Product.skuLookupCandidates('1').length, lessThanOrEqualTo(30));
      expect(Product.skuLookupCandidates('   '), isEmpty);
    });
  });
}
