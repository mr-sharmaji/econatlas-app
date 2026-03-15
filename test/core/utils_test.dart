import 'package:econatlas_app/core/utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('commodity conversions', () {
    test('gold conversion uses troy ounces for INR per 10g', () {
      const usdPerOz = 5023.10009765625;
      const usdInr = 92.5114;

      final value = Formatters.goldToIndian(usdPerOz, usdInr);

      expect(value, closeTo(149402.5974, 0.001));
    });

    test('silver conversion uses troy ounces for INR per kg', () {
      const usdPerOz = 80.6449966430664;
      const usdInr = 92.5114;

      final value = Formatters.silverToIndian(usdPerOz, usdInr);

      expect(value, closeTo(239863.2664, 0.001));
    });

    test('copper conversion keeps pound to kilogram factor', () {
      const usdPerLb = 5.675000190734863;
      const usdInr = 92.5114;

      final value = Formatters.copperToIndian(usdPerLb, usdInr);

      expect(value, closeTo(1157.4304, 0.001));
    });
  });
}
