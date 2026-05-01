import 'package:dewprofi/app/dewprofi_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('manual calculator renders default result', (tester) async {
    await tester.pumpWidget(const DewprofiApp());

    expect(find.text('Manuelle Eingabe'), findsOneWidget);
    expect(find.text('Taupunkt'), findsOneWidget);
    expect(find.text('Absolute Feuchte'), findsOneWidget);
    expect(find.text('angenehm'), findsOneWidget);
    expect(find.byKey(const ValueKey('humidity-curve-chart')), findsOneWidget);
  });

  testWidgets('manual input updates the humidity zone', (tester) async {
    await tester.pumpWidget(const DewprofiApp());

    await tester.enterText(
      find.widgetWithText(TextField, 'Relative Luftfeuchte'),
      '75',
    );
    await tester.pump();

    expect(find.text('kritisch'), findsOneWidget);
  });

  testWidgets('optional pressure accepts comma decimals', (tester) async {
    await tester.pumpWidget(const DewprofiApp());

    await tester.enterText(
      find.widgetWithText(TextField, 'Temperatur'),
      '19,5',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Luftdruck optional'),
      '990,5',
    );
    await tester.pump();

    expect(find.text('19,5 °C'), findsOneWidget);
    expect(find.text('990,50 hPa'), findsOneWidget);
  });
}
