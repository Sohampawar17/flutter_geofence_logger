import 'package:flutter_geofence_logger/features/event_logs/domain/transition_policy.dart';
import 'package:flutter_geofence_logger/features/geofence/domain/geofence_config.dart';
import 'package:flutter_geofence_logger/features/geofence/domain/geofence_location_evaluator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final timestamp = DateTime.utc(2026, 11, 17, 12);
  final office = GeofenceConfig(
    id: 'office',
    name: 'Mock office',
    latitude: 18.5204,
    longitude: 73.8567,
    radiusMeters: 100,
    enabled: true,
    createdAt: timestamp,
    updatedAt: timestamp,
  );

  test('mock route calculates distance and creates an ENTER decision', () {
    final outside = GeofenceLocationEvaluator.evaluate(
      geofence: office,
      latitude: 18.5204,
      longitude: 73.8587,
    );
    final inside = GeofenceLocationEvaluator.evaluate(
      geofence: office,
      latitude: 18.5204,
      longitude: 73.8570,
    );

    expect(outside.distanceMeters, closeTo(211, 2));
    expect(outside.isInside, isFalse);
    expect(inside.distanceMeters, closeTo(32, 2));
    expect(inside.isInside, isTrue);

    final decision = TransitionPolicy.decide(
      previous: outside.isInside ? GeofenceState.inside : GeofenceState.outside,
      current: inside.isInside ? GeofenceState.inside : GeofenceState.outside,
      callbackAt: timestamp,
      lastEventAt: timestamp.subtract(const Duration(minutes: 2)),
    );
    expect(decision, TransitionDecision.insert);
  });

  test('a point just within the radius is inside', () {
    final boundaryLatitude = office.latitude + 99.9 / 111195;
    final result = GeofenceLocationEvaluator.evaluate(
      geofence: office,
      latitude: boundaryLatitude,
      longitude: office.longitude,
    );

    expect(result.distanceMeters, closeTo(99.9, 0.1));
    expect(result.isInside, isTrue);
  });
}
