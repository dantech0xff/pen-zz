// Picks the ad and store services for this platform. The web build compiles the stub, so it
// never contains the AdMob or RevenueCat code paths.
export 'services_none.dart' if (dart.library.io) 'services_mobile.dart';
