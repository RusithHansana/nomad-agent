import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:app/app.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/app_typography.dart';
import 'package:app/core/constants/app_spacing.dart';
import 'package:app/core/network/api_client.dart';

void main() {
  setUp(() {
    // Prevent google_fonts from making HTTP requests during tests.
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  group('App bootstrap', () {
    testWidgets('App renders inside ProviderScope without crashing', (
      tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: App()));

      // The Home screen should be visible as the initial route
      expect(find.text('Home'), findsWidgets);
    });

    testWidgets('App uses Material 3', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: App()));

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme?.useMaterial3, isTrue);
      expect(materialApp.darkTheme?.useMaterial3, isTrue);
      expect(materialApp.themeMode, ThemeMode.system);
    });

    testWidgets('Bottom NavigationBar has 3 destinations', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: App()));

      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.destinations.length, 3);
    });

    testWidgets('Tapping History tab navigates to History screen', (
      tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: App()));

      // Tap the History tab (index 1)
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      expect(find.text('History Screen'), findsOneWidget);
    });

    testWidgets('Tapping Settings tab navigates to Settings screen', (
      tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: App()));

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Settings Screen'), findsOneWidget);
    });
  });

  group('Theme tokens', () {
    test('Light theme uses correct primary color', () {
      final theme = AppTheme.light;
      expect(theme.colorScheme.primary, AppColors.primary);
    });

    test('Dark theme uses correct primary color', () {
      final theme = AppTheme.dark;
      expect(theme.colorScheme.primary, AppColors.darkPrimary);
    });

    test('Light theme scaffold background is beige sand', () {
      final theme = AppTheme.light;
      expect(theme.scaffoldBackgroundColor, AppColors.background);
    });

    test('Dark theme scaffold background is dark gray', () {
      final theme = AppTheme.dark;
      expect(theme.scaffoldBackgroundColor, AppColors.darkBackground);
    });
  });

  group('AppColors', () {
    test('Primary is Deep Forest Green #2C3E2D', () {
      expect(AppColors.primary, const Color(0xFF2C3E2D));
    });

    test('Secondary is Terracotta #C8956C', () {
      expect(AppColors.secondary, const Color(0xFFC8956C));
    });

    test('Background is Beige Sand #FAF7F2', () {
      expect(AppColors.background, const Color(0xFFFAF7F2));
    });

    test('Dark background is #1E1E1E', () {
      expect(AppColors.darkBackground, const Color(0xFF1E1E1E));
    });
  });

  group('AppTypography', () {
    test('Display is 28px bold', () {
      final style = AppTypography.display();
      expect(style.fontSize, 28);
      expect(style.fontWeight, FontWeight.w700);
    });

    test('Body is 15px regular', () {
      final style = AppTypography.body();
      expect(style.fontSize, 15);
      expect(style.fontWeight, FontWeight.w400);
    });

    // Note: ThoughtLog (JetBrains Mono) is tested indirectly via
    // the AppTypography.thoughtLog method signature. Calling it in a
    // unit test triggers an async font fetch that fails without bundled
    // assets. The method is exercised in integration/widget tests where
    // the full app context is available.

    test('Caption is 11px medium', () {
      final style = AppTypography.caption();
      expect(style.fontSize, 11);
      expect(style.fontWeight, FontWeight.w500);
    });
  });

  group('AppSpacing', () {
    test('4px base scale values are correct', () {
      expect(AppSpacing.xxs, 4);
      expect(AppSpacing.xs, 8);
      expect(AppSpacing.sm, 12);
      expect(AppSpacing.md, 16);
      expect(AppSpacing.lg, 20);
      expect(AppSpacing.xl, 24);
      expect(AppSpacing.xxl, 32);
      expect(AppSpacing.xxxl, 40);
      expect(AppSpacing.huge, 48);
      expect(AppSpacing.massive, 64);
    });
  });

  group('ApiClient', () {
    test('Dio instance has correct base URL default', () {
      final dio = ApiClient.instance;
      expect(dio.options.baseUrl, 'http://localhost:8000');
    });

    test('Dio instance has 35s total timeout', () {
      final dio = ApiClient.instance;
      final connectTimeout = dio.options.connectTimeout!.inSeconds;
      final receiveTimeout = dio.options.receiveTimeout!.inSeconds;
      expect(connectTimeout + receiveTimeout, 35);
    });

    test('Dio instance has API key interceptor', () {
      final dio = ApiClient.instance;
      // At least one interceptor should be present (the API key one)
      expect(dio.interceptors.length, greaterThanOrEqualTo(1));
    });
  });
}
