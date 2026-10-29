import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:overload/app/providers.dart';
import 'package:overload/data/repositories/settings_repository.dart';
import 'package:overload/main.dart';

void main() {
  testWidgets(
    'swiping horizontally changes tab and keeps the nav bar in sync',
    (tester) async {
      await initializeDateFormatting('pt_PT');
      const profile = Profile(name: 'Teste', onboarded: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Static data keeps the test free of real database I/O.
            initialProfileProvider.overrideWithValue(profile),
            profileProvider.overrideWith((ref) => Stream.value(profile)),
            exercisesProvider.overrideWith((ref) => Stream.value(const [])),
            historyProvider.overrideWith((ref) => Stream.value(const [])),
            routinesProvider.overrideWith((ref) => Stream.value(const [])),
            bodyWeightsProvider.overrideWith((ref) => Stream.value(const [])),
          ],
          child: const OverloadApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Teste'), findsWidgets);

      NavigationBar bar() =>
          tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar().selectedIndex, 0);

      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1500);
      await tester.pumpAndSettle();
      expect(bar().selectedIndex, 1);
      expect(find.text('Treino livre'), findsOneWidget);

      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1500);
      await tester.pumpAndSettle();
      expect(bar().selectedIndex, 2);

      // Tapping a distant tab animates past the pages in between without
      // switching to them.
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      expect(bar().selectedIndex, 4);

      await tester.fling(find.byType(PageView), const Offset(400, 0), 1500);
      await tester.pumpAndSettle();
      expect(bar().selectedIndex, 3);
    },
  );
}
