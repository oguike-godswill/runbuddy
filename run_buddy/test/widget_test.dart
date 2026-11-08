import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:run_buddy/app/app.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App launches on Splash with brand messaging', (WidgetTester tester) async {
    await tester.pumpWidget(const RunBuddyApp());
    expect(find.text('RUN BUDDY'), findsOneWidget);
    expect(find.text('NEVER RUN ALONE'), findsOneWidget);

    // Fast-forward pending Splash timer & transitions
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });
}
