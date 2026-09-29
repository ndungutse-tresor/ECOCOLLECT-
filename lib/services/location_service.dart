import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/dropoff_point.dart';

enum LocationStatus {
  unknown,
  loading,
  available,
  denied,
  deniedForever,
  serviceDisabled,
  unavailable,
}

/// Finds the user's position on demand and measures distances to drop-off points.
class LocationService extends ChangeNotifier {
  static const _distance = Distance();

  LatLng? _position;
  LocationStatus _status = LocationStatus.unknown;

  LatLng? get position => _position;
  LocationStatus get status => _status;
  bool get hasPosition => _position != null;
  bool get isLoading => _status == LocationStatus.loading;

  bool get canOpenSettings =>
      !kIsWeb &&
      (_status == LocationStatus.deniedForever ||
          _status == LocationStatus.serviceDisabled);

  String get statusMessage {
    switch (_status) {
      case LocationStatus.denied:
        return 'Location permission was denied.';
      case LocationStatus.deniedForever:
        return 'Location is blocked. Enable it in your app settings.';
      case LocationStatus.serviceDisabled:
        return 'Turn on location services to find nearby points.';
      case LocationStatus.unavailable:
        return 'We could not get your location. Try again.';
      default:
        return '';
    }
  }

  Future<LatLng?> request() async {
    if (_status == LocationStatus.loading) return _position;
    _setStatus(LocationStatus.loading);

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _setStatus(LocationStatus.serviceDisabled);
        return _position;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _setStatus(LocationStatus.denied);
        return _position;
      }
      if (permission == LocationPermission.deniedForever) {
        _setStatus(LocationStatus.deniedForever);
        return _position;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      _position = LatLng(position.latitude, position.longitude);
      _setStatus(LocationStatus.available);
    } catch (e) {
      debugPrint('EcoCollect: location error: $e');
      _setStatus(
        _position != null
            ? LocationStatus.available
            : LocationStatus.unavailable,
      );
    }
    return _position;
  }

  Future<void> openSettings() async {
    if (_status == LocationStatus.serviceDisabled) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }

  /// Distance in metres, or null when the position is unknown.
  double? distanceTo(DropoffPoint point) {
    final position = _position;
    if (position == null) return null;
    return _distance.as(
      LengthUnit.Meter,
      position,
      LatLng(point.latitude, point.longitude),
    );
  }

  /// Nearest first when the position is known; otherwise the original order.
  List<DropoffPoint> sortByDistance(List<DropoffPoint> points) {
    if (_position == null) return points;
    final sorted = [...points];
    sorted.sort((a, b) => distanceTo(a)!.compareTo(distanceTo(b)!));
    return sorted;
  }

  void _setStatus(LocationStatus status) {
    _status = status;
    notifyListeners();
  }
}
