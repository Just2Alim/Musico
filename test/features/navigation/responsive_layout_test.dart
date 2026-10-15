import 'package:flutter_test/flutter_test.dart';
import 'package:musico_app/core/responsive_breakpoints.dart';

void main() {
  test('selects phone, tablet, and wide-screen grid densities', () {
    expect(responsiveGridColumns(390), 2);
    expect(responsiveGridColumns(800), 3);
    expect(responsiveGridColumns(1024), 4);
  });
}
