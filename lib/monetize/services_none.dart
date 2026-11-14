import 'ads_service.dart';
import 'cloud_service.dart';
import 'store_service.dart';

AdsService createAds() => NoAds();

StoreService createStore() => const NoStore();

CloudService createCloud() => NoCloud();
