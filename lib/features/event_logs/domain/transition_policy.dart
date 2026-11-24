enum GeofenceState { unknown, inside, outside }

enum TransitionDecision { insert, duplicate, establishOutside, outOfOrder }

class TransitionPolicy {
  static TransitionDecision decide({
    required GeofenceState previous,
    required GeofenceState current,
    required DateTime callbackAt,
    DateTime? lastEventAt,
  }) {
    if (previous == current) return TransitionDecision.duplicate;
    if (previous == GeofenceState.unknown && current == GeofenceState.outside) {
      return TransitionDecision.establishOutside;
    }
    if (lastEventAt != null && callbackAt.isBefore(lastEventAt)) {
      return TransitionDecision.outOfOrder;
    }
    return TransitionDecision.insert;
  }
}
