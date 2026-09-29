# EcoCollect Rwanda

A mobile app that makes e-waste recycling in Kigali as easy as a tap: report old electronics, drop them off at a collection point or book a free home pickup, and earn EcoPoints and Mobile Money cash rewards. An admin dashboard lets the EcoCollect team verify hand-overs, schedule pickups and pay cash rewards.

The project has three parts:

| Part | What it is | Where |
|---|---|---|
| Member app | Flutter app for Android, iOS and web | `lib/` |
| Admin dashboard | Flutter web app sharing the same models and design | `lib/admin/` |
| Server | Dart API that connects both and stores the data | `server/` |

## Features

**Member app**
- Onboarding and profile (name, phone, district).
- Report e-waste in four steps: category, details and photo, drop-off or pickup, review.
- Drop-off map with search, filters, "Open now", distance and Google Maps directions.
- Home pickup booking with address (can use current location), phone, day and time slot.
- Report tracking: Pending → Handed over → Verified → Recycled (or Rejected with a reason).
- EcoPoints (10 per kg + 5 per item), levels, and rewards with voucher codes.
- **Cash rewards**: Mobile Money payouts at 10 kg (RWF 1,000), 25 kg (RWF 3,000), 50 kg (RWF 7,000) and 100 kg (RWF 15,000) of verified recycling, paid to MTN MoMo or Airtel Money.
- Impact dashboard with CO₂ avoided, weight by category and monthly activity.
- Works offline; changes sync automatically when the server is reachable.

**Admin dashboard**
- Overview: verified weight, reports to verify, pickups, payouts due, members, charts by district and category.
- Reports: verify, reject (with a reason shown to the member), mark recycled; members who say they handed over are listed first.
- Pickups: home collections grouped by day, with address and phone.
- Payouts: approve cash reward claims, check eligibility, record the Mobile Money transaction ID.
- Members: ranked by verified recycling, with points and cash paid.

Points and cash rewards are only credited after the admin verifies a hand-over.

## Running it

Requires the Flutter SDK (stable channel), which includes Dart.

### 1. Start the server

```bash
cd server
dart pub get
dart run bin/server.dart
```

It prints the addresses to use, including your computer's network address for phones. Settings (environment variables):

| Variable | Default | Purpose |
|---|---|---|
| `PORT` | `8787` | HTTP port |
| `ADMIN_PIN` | `admin123` | PIN for the admin dashboard. **Change it** outside local testing. |
| `DATA_DIR` | `server/data` | Where `db.json` and report photos are stored |

A new database starts with a few sample members and reports so the dashboard has content. Delete `server/data` to start fresh.

### 2. Open the admin dashboard

During development:

```bash
flutter run -d chrome -t lib/admin/admin_main.dart
```

Or build it once so the server hosts it at `http://localhost:8787/admin/`:

```bash
flutter build web -t lib/admin/admin_main.dart --base-href /admin/ -o <absolute path to project>/build/admin
```

(In Git Bash, prefix the command with `MSYS_NO_PATHCONV=1` so `/admin/` is not rewritten.)

### 3. Run the member app

```bash
flutter run                # phone or emulator
flutter run -d chrome      # browser
```

The app finds the server automatically on the web (same host, port 8787), on the Android emulator (`10.0.2.2:8787`) and on the iOS simulator (`localhost:8787`). On a real phone, open **Profile → Server connection → Change server** and enter the network address the server printed, e.g. `http://192.168.1.10:8787`, or build with `--dart-define=API_URL=http://192.168.1.10:8787`. The phone and computer must be on the same Wi-Fi.

`flutter build web` puts the member app in `build/web`, which the server also hosts at `http://localhost:8787/`.

### Tests

```bash
flutter test               # app: points, sync merge, cash rewards, onboarding
cd server && dart test     # server: API rules and admin permissions
```

## Project structure

```
lib/
  main.dart            Member app entry point
  models/              Drop-off points, reports, rewards, cash rewards, profile
  services/            App state, sync, API client, location, photo storage
  screens/             Member app screens
  widgets/             Shared UI components
  admin/               Admin dashboard (entry point, service, pages)
  utils/               Theme, colours, formatting, link helpers
server/
  bin/server.dart      Starts the HTTP server
  lib/api.dart         Routes and rules
  lib/store.dart       JSON file storage
test/                  App tests
```

## Notes

- Plain HTTP is allowed for local testing (Android cleartext, iOS local networking). Put the server behind HTTPS before real use.
- The admin PIN is a single shared secret, suitable for a pilot. Add proper staff accounts before scaling up.
- Drop-off locations, community statistics and the reward catalogue are sample data.
- Map tiles © OpenStreetMap contributors.
