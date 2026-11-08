import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:run_buddy/app/app.dart';
import 'package:run_buddy/app/route_names.dart';
import 'package:run_buddy/app/router.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App navigates to /register successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const RunBuddyApp());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Test routing directly to register
    appRouter.go(RouteNames.register);
    await tester.pumpAndSettle();

    expect(find.text('Create Runner Profile'), findsOneWidget);
    expect(find.text('COMPLETE REGISTRATION'), findsOneWidget);
  });
}
