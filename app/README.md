# app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Stadia Maps

The bin map uses `flutter_map` with Stadia Maps' Alidade Smooth tiles. Paste
your Stadia Maps API key between the quotes for `kStadiaMapsApiKey` in
`lib/app_config.dart`. The key is embedded in the app and is not a secret; use
a client key with appropriate restrictions and usage limits. Without a key,
the map displays a setup prompt instead of requesting tiles, and address
search is unavailable. Bin search works without a key; submit an address query
to search it with Stadia's geocoding service.

The current bin coordinates are illustrative positions around Elmina Township
and are stored as Firestore GeoPoints in the `bins` collection. Replace them
with verified bin coordinates when available. Bin details request a pedestrian
road-route distance and estimated walking time from Stadia's routing API using
the device GPS location. Navigate draws the Stadia pedestrian route on the
in-app map but does not provide turn-by-turn instructions or live rerouting.

## Firebase

The app initializes Firebase for Android and iOS. Email/password sign-in is
required before accessing the app. New users can create an account from the
sign-in screen, choose a username, and confirm their password. The username is
saved to the Firebase Auth profile; sign-in continues to use email and
password. Users can choose a profile picture from their device; it is stored
locally and is not synced to other devices. Bin Map reads the `bins` collection
in real time. CO₂ savings are stored in `users/{uid}.co2SavedKg` and initialized
to `0` when the signed-in user first opens a screen that displays the total.
Clients can read only their own total and cannot edit it after initialization;
the app does not currently increment the total from marketplace or recycling
activity. Firestore rules allow authenticated users to read bins and deny
client-side bin writes. The email/password provider and Firestore rules are
configured in `firebase.json`, `firestore.rules`, and `firestore.indexes.json`.
