import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:spectacular_barcode/spectacular_barcode.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('platform interface is registered', (tester) async {
    expect(SpectacularBarcodePlatform.instance, isNotNull);
  });
}
