import 'package:flutter_geofence_logger/core/errors/app_exception.dart';
import 'package:flutter_geofence_logger/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts valid coordinates and default radius', () {
    expect(
      () => Validators.geofence(
        id: 'a',
        name: 'Office',
        latitude: 18.5,
        longitude: 73.8,
        radiusMeters: 200,
      ),
      returnsNormally,
    );
  });

  test('rejects invalid geofence values', () {
    for (final call in <void Function()>[
      () => Validators.geofence(
        id: 'a',
        name: '',
        latitude: 0,
        longitude: 0,
        radiusMeters: 200,
      ),
      () => Validators.geofence(
        id: 'a',
        name: 'A',
        latitude: 91,
        longitude: 0,
        radiusMeters: 200,
      ),
      () => Validators.geofence(
        id: 'a',
        name: 'A',
        latitude: 0,
        longitude: 181,
        radiusMeters: 200,
      ),
      () => Validators.geofence(
        id: 'a',
        name: 'A',
        latitude: 0,
        longitude: 0,
        radiusMeters: 0,
      ),
    ]) {
      expect(call, throwsA(isA<ValidationException>()));
    }
  });

  test('requires HTTPS API URL', () {
    expect(
      () => Validators.httpsBaseUrl('http://example.test'),
      throwsA(isA<ValidationException>()),
    );
    expect(
      Validators.httpsBaseUrl('https://example.test/'),
      'https://example.test',
    );
  });
}
