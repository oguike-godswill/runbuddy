import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:run_buddy/app/app.dart';
import 'package:run_buddy/app/route_names.dart';
import 'package:run_buddy/app/router.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('QA Verification: All primary routes mount without exception', (WidgetTester tester) async {
    await tester.pumpWidget(const RunBuddyApp());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // 1. Verify /history
    appRouter.go(RouteNames.history);
    await tester.pumpAndSettle();
    expect(find.text('Run History'), findsOneWidget);
    expect(find.text('LOGGED SESSIONS'), findsOneWidget);

    // 2. Verify /profile
    appRouter.go(RouteNames.profile);
    await tester.pumpAndSettle();
    expect(find.text('Runner Profile'), findsOneWidget);
    expect(find.text('LIFETIME METRICS'), findsOneWidget);

    // 3. Verify /friends
    appRouter.go(RouteNames.friends);
    await tester.pumpAndSettle();
    expect(find.text('Companions & Friends'), findsOneWidget);

    // 4. Verify /start-run
    appRouter.go(RouteNames.startRun);
    await tester.pumpAndSettle();
    expect(find.text('Run Together Setup'), findsOneWidget);

    // 5. Verify /home
    appRouter.go(RouteNames.home);
    await tester.pumpAndSettle();
    expect(find.text('ACTIVE RUNNER PROFILE'), findsOneWidget);
  });
}
