# EcoCollect Rwanda

A mobile app that makes e-waste recycling in Kigali as easy as a tap: report old electronics, drop them off at a collection point or book a free home pickup, and earn EcoPoints you can swap for rewards.

Built with Flutter for Android, iOS and the web.

## Features

- **Onboarding and profile**: a short intro, then name, phone number and district.
- **Report e-waste**: a four-step flow (category, details and photo, drop-off or pickup, review) with estimated weight and points.
- **Drop-off map**: OpenStreetMap with collection points, search, district and "Open now" filters, distance from your location, and directions via Google Maps.
- **Home pickup**: address (can be filled from your current location), phone, day and time slot.
- **Report tracking**: each report moves from Pending to Collected to Recycled. Confirming the hand-over credits the EcoPoints; collected items are marked recycled two days later.
- **EcoPoints and rewards**: levels (Seedling to Forest), redeemable rewards with voucher codes, and a voucher history.
- **Impact dashboard**: CO₂ avoided, weight by category, monthly activity and community totals.

All data is stored on the device with `shared_preferences`. A fresh install starts with a few sample reports so every screen has content. Use **Profile → Reset app data** to start over.

## Running the app

Requires the Flutter SDK (stable channel, Dart 3.1 or newer).

```bash
flutter pub get
flutter run            # on a connected device or emulator
flutter run -d chrome  # in the browser
```

Other useful commands:

```bash
flutter test           # unit and widget tests
flutter analyze        # static analysis
flutter build apk      # Android release build
```

Location, camera and photo-library permissions are declared in `android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist`.

## Project structure

```
lib/
  main.dart            App entry point and providers
  models/              Drop-off points, e-waste items, rewards, user profile
  services/            App state and persistence, location, photo storage, tab navigation
  screens/             One file per screen
  widgets/             Shared UI components
  utils/               Theme, colours, formatting, link helpers
test/                  Unit and widget tests
```

## Notes

- Drop-off locations, community statistics and rewards are sample data for the MVP.
- Points: 10 per kg plus 5 per item, credited when the item is handed over.
- Map tiles © OpenStreetMap contributors.
