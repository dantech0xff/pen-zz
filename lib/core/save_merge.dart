import 'dart:math' as math;

import 'catalog.dart';
import 'save_data.dart';
import 'store_catalog.dart';

/// How far a save has got: stages cleared first, then level, experience and matches played.
List<int> progressOf(SaveData s) => [s.stage, s.lvl, s.xp, s.wins + s.losses];

int _compareProgress(SaveData a, SaveData b) {
  final pa = progressOf(a), pb = progressOf(b);
  for (var i = 0; i < pa.length; i++) {
    if (pa[i] != pb[i]) return pa[i].compareTo(pb[i]);
  }
  return 0;
}

/// Whether [cloud] should be the base of the merge rather than [local]: a newer reset
/// (epoch) wins, then the save that got further. Ties keep the save on this phone.
bool cloudLeads(SaveData local, SaveData cloud) =>
    cloud.epoch != local.epoch ? cloud.epoch > local.epoch : _compareProgress(cloud, local) > 0;

/// Merges the save on this phone with the copy in the cloud.
///
/// The save that leads (see [cloudLeads]) is kept as it is, and real-money purchases found
/// only in the other one are added to it: coin packs and the starter pack add their coins
/// once, exclusive items and "remove ads" carry over. The daily free-coin views take the
/// larger count, so merging never gives extra views. Sound and haptics stay as set on this
/// phone.
SaveData mergeSaves(SaveData local, SaveData cloud) {
  final fromCloud = cloudLeads(local, cloud);
  final base = fromCloud ? cloud : local, other = fromCloud ? local : cloud;
  final out = SaveData.fromJson(base.toJson());
  for (final e in other.creditedTx.entries) {
    if (out.creditedTx.containsKey(e.key)) continue;
    out.creditedTx[e.key] = e.value;
    out.coins += e.value;
  }
  for (final id in other.creditedPacks) {
    if (out.creditedPacks.add(id)) out.coins += productById(id)?.coins ?? 0;
  }
  out.owned.addAll(other.owned.where((id) => itemIndex[id]?.exclusive ?? false));
  out.noAds = out.noAds || other.noAds;
  final since = [out.storeSince, other.storeSince].where((t) => t > 0);
  out.storeSince = since.isEmpty ? 0 : since.reduce(math.min);
  if (other.adDay > out.adDay) {
    out.adDay = other.adDay;
    out.adCoinsUsed = other.adCoinsUsed;
  } else if (other.adDay == out.adDay) {
    out.adCoinsUsed = math.max(out.adCoinsUsed, other.adCoinsUsed);
  }
  out.tutorialDone = out.tutorialDone || other.tutorialDone;
  out.sound = local.sound;
  out.haptics = local.haptics;
  return out;
}
