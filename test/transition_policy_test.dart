import 'package:flutter_geofence_logger/features/event_logs/domain/transition_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 1, 1, 12);
  test(
    'outside to inside inserts ENTER',
    () => expect(
      TransitionPolicy.decide(
        previous: GeofenceState.outside,
        current: GeofenceState.inside,
        callbackAt: now,
        lastEventAt: now.subtract(const Duration(minutes: 2)),
      ),
      TransitionDecision.insert,
    ),
  );
  test(
    'inside to outside inserts EXIT even after only 23 seconds',
    () => expect(
      TransitionPolicy.decide(
        previous: GeofenceState.inside,
        current: GeofenceState.outside,
        callbackAt: now,
        lastEventAt: now.subtract(const Duration(seconds: 23)),
      ),
      TransitionDecision.insert,
    ),
  );
  test(
    'same state is duplicate',
    () => expect(
      TransitionPolicy.decide(
        previous: GeofenceState.inside,
        current: GeofenceState.inside,
        callbackAt: now,
      ),
      TransitionDecision.duplicate,
    ),
  );
  test(
    'unknown outside establishes state only',
    () => expect(
      TransitionPolicy.decide(
        previous: GeofenceState.unknown,
        current: GeofenceState.outside,
        callbackAt: now,
      ),
      TransitionDecision.establishOutside,
    ),
  );
  test(
    'unknown inside creates initial ENTER',
    () => expect(
      TransitionPolicy.decide(
        previous: GeofenceState.unknown,
        current: GeofenceState.inside,
        callbackAt: now,
      ),
      TransitionDecision.insert,
    ),
  );
  test('rejects an out-of-order transition', () {
    expect(
      TransitionPolicy.decide(
        previous: GeofenceState.outside,
        current: GeofenceState.inside,
        callbackAt: now,
        lastEventAt: now.add(const Duration(seconds: 1)),
      ),
      TransitionDecision.outOfOrder,
    );
  });
}
