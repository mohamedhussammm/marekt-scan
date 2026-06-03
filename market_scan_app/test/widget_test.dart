import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_scan_app/main.dart';
import 'package:provider/provider.dart';
import 'package:market_scan_app/core/providers/app_provider.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppProvider(),
        child: const MarketScanApp(),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
