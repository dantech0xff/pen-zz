import 'dart:io' show Platform;

import 'admob_ads.dart';
import 'ads_service.dart';
import 'cloud_service.dart';
import 'firebase_cloud.dart';
import 'revenuecat_store.dart';
import 'store_service.dart';

bool get _mobile => Platform.isAndroid || Platform.isIOS;

AdsService createAds() => _mobile ? AdMobAds() : NoAds();

/// RevenueCat public SDK keys, passed with `--dart-define`. See docs/kiem-tien.md.
const _rcAndroid = String.fromEnvironment('RC_KEY_ANDROID');
const _rcIos = String.fromEnvironment('RC_KEY_IOS');

StoreService createStore() => _mobile ? RevenueCatStore(Platform.isIOS ? _rcIos : _rcAndroid) : const NoStore();

/// Firebase cloud save, when the build carries Firebase settings.
CloudService createCloud() => _mobile && FirebaseConfig.complete ? FirebaseCloud() : NoCloud();
