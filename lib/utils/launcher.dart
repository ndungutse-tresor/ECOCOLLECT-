import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/dropoff_point.dart';

/// Opens turn-by-turn directions to [point] in Google Maps (app or browser).
Future<void> openDirections(BuildContext context, DropoffPoint point) {
  return openExternalUrl(
    context,
    'https://www.google.com/maps/dir/?api=1'
    '&destination=${point.latitude},${point.longitude}',
  );
}

Future<void> openExternalUrl(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  var opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    opened = false;
  }
  if (!opened) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not open the link on this device.')),
    );
  }
}
