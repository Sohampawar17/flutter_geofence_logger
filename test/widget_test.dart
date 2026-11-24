import 'package:flutter/material.dart';
import 'package:flutter_geofence_logger/app/app_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('metric renders dashboard value and label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Metric('Pending', '3', Icons.sync)),
      ),
    );
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.byIcon(Icons.sync), findsOneWidget);
  });

  testWidgets('event details use standard unavailable labels', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EventDetails({
            'event_type': 'ENTER',
            'geofence_name': 'Office',
          }),
        ),
      ),
    );
    expect(find.text('Event Details'), findsOneWidget);
    expect(find.text('ENTER'), findsOneWidget);
    expect(find.text('Office'), findsWidgets);
    expect(find.text('Not available'), findsWidgets);
  });
}
