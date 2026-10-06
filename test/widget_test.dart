import 'package:flutter_test/flutter_test.dart';
import 'package:polyscan/data/app_state.dart';
import 'package:polyscan/main.dart';

void main() {
  testWidgets('onboarding leads to the document list', (tester) async {
    await tester.pumpWidget(PolyscanApp(state: AppState()));
    expect(find.text('Scan without strings'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Polyscan'), findsOneWidget);
    expect(find.text('Rental agreement'), findsOneWidget);
  });
}
