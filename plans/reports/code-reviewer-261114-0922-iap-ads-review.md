# Code review: RevenueCat purchases and AdMob ads

## Scope

- Reviewed commits `e1f77d4` (feature) and `9e4164c` (docs). They were committed while the review was running. I diffed the committed `lib/` and `test/` against the copy I read, and the files are byte-identical.
- Size: 16 tracked files changed (+606/−210, including `pubspec.lock`), 1,461 lines in new files under `lib/` and `test/`, and docs (+134/−3).
- Focus: money correctness, misuse of the SDKs, exclusive items, UI, and the web build.
- Checks: I ran `flutter analyze` (no issues) and `flutter test` (49 passed) on an identical copy, so they would not compete with the build running in the other session. Probes live in `/tmp/claude-0/-home-user-pen-zz/c71402d3-a215-5010-aaa1-2dc4baa1a58e/scratchpad/probe/test/probe/`. I did not run `flutter build`.

## Overall assessment

The structure is clean and most of the rules hold. The coin ledger does not: on both platforms every coin-pack purchase is credited twice, and the 100-entry ledger cap re-credits old purchases once a player has made enough of them. The unit tests cannot catch either bug because the fake store returns the same transaction id on both the purchase path and the history path. The real SDK returns two different ids.

## Critical

### 1. Every coin-pack purchase is credited twice (CONFIRMED)

- **Where:** `lib/monetize/revenuecat_store.dart:26-29` and `:64-71`; `lib/state/game_controller.dart:240-249`.
- **Cause:** purchases_flutter 11.0.2 pins purchases-hybrid-common 20.9.0. That library fills the two ids from different sources:
  - `PurchaseResult.storeTransaction.transactionIdentifier` is the store's id. `StoreTransactionMapperKt.transactionIdentifierValue` returns `getOrderId()`, so on Android this is the Google order id `GPA.…`; on iOS it is the StoreKit id.
  - `CustomerInfo.nonSubscriptionTransactions[].transactionIdentifier` is RevenueCat's own id. `TransactionMapperKt` reads `Transaction.transactionIdentifier`, which is parsed from the backend field `id`. The store id lives in a separate `store_transaction_id` field that the Flutter model does not expose. The upstream iOS mapping (`NonSubscriptionTransaction+HybridAdditions.swift`) does the same thing.
- **Failure:** the two ids for one purchase never match, so `buy()`'s filter `t.id != tx.transactionIdentifier` keeps the real entry. It then appends a synthetic order-id entry, and `applyStore` credits both: the RevenueCat entry passes the time check, and the order-id entry passes as `purchasedTx`. Listener order does not matter. If the update listener runs first, it credits the RevenueCat entry and the purchase result still credits the order id.
- **Probe:** `rc_probe_test.dart` runs the real `RevenueCatStore` through a mocked `purchases_flutter` channel with payloads shaped like 20.9.0 output. One 1,000-coin purchase leaves 2,000 coins and `creditedTx = [rc_1, GPA.3345-…]`.
- **Test gap:** `test/support/fake_monetization.dart:66-72` uses one id for both paths, so "a coin pack is credited once per transaction" passes against a model the SDK does not follow. `docs/kiem-tien.md:84` makes the same false claim.
- **Fix:**
  - Key consumables only by RevenueCat ids.
  - In `buy()`, drop the synthetic entry. From `r.customerInfo.nonSubscriptionTransactions`, take the entry with the same `productIdentifier` whose `purchaseDate` matches (or is nearest to) `r.storeTransaction.purchaseDate`, and pass its id as `PurchaseDone.transactionId`. If none is present, pass null and let the listener credit it.
  - Add a `RevenueCatStore` test over a mocked method channel where the store id and the RevenueCat id differ; the probe can serve as the template.

## High

### 2. The 100-entry ledger cap re-credits old purchases (CONFIRMED)

- **Where:** `lib/state/game_controller.dart:242-246`; `lib/core/save_data.dart:94` and `:176-180`.
- **Cause:** RevenueCat reports every non-subscription purchase the player has ever made. `creditedTx` keeps only the newest 100 ids, and the time check (`>= storeSince - 10 min`) accepts all of them.
- **Failure:** once the store reports more than 100 coin-pack purchases, every snapshot (app start, listener update, restore) credits each evicted id again, and each re-credit evicts the next id.
- **Probes:**
  - `ledger_probe_test.dart`: after 101 purchases, each further `applyStore` with the same history adds 101,000 coins.
  - `rc_probe51_test.dart`: with finding 1 still present, the leak starts after about 50 purchases, because each purchase stores two ids. The next snapshot after the 51st purchase adds 2,000 coins.
- **Note:** fixing finding 1 alone turns this into a re-credit of the full history on every snapshot, so fix both together.
- **Fix:** do not cap the ledger below what the store can report. Drop the cap (one id is about 30 bytes), or prune only ids that are missing from the latest snapshot. Add a test with more than 100 purchases.

## Medium

### 3. The `storeSince` cutoff uses the device clock against store timestamps

- **Where:** `lib/state/monetization.dart:37`; `lib/state/game_controller.dart:216-220` and `:238-244`.
- **A (CONFIRMED by probe):** the device clock is more than 10 minutes fast when the save first reaches the store. This happens on a new phone before network time syncs, or for a player who moved the clock to farm daily free coins. A coin pack that arrives only through the listener (a pending cash payment that clears later, or a purchase whose result was lost when the app was killed) is never credited. In `ledger_probe_test.dart`, with the clock 1 h fast, a payment that clears 20 min later credits 0 coins.
- **B (CONFIRMED by probe, inherent to the design):** the store charges a coin pack but the app never confirms it, for example because the network dropped while RevenueCat was posting the receipt. The player then reinstalls. RevenueCat syncs the unconsumed purchase on the new install, but its date is before the new `storeSince`, so it is never credited.
- **C (PLAUSIBLE):** the clock is slow at the new install's first store contact. Older coin packs that RevenueCat reports, for example after "Khôi phục giao dịch", are credited again.
- **Fix:** take the cutoff from server time instead of `DateTime.now()`, for example `CustomerInfo.requestDate` from the first snapshot (carry it in `StoreSnapshot`). Document case B in `docs/kiem-tien.md` and give support a manual way to compensate.

### 4. The settings sheet overflows on 360×640 phones (CONFIRMED)

- **Where:** `lib/ui/screens/settings_sheet.dart:10-11` (a modal sheet that is not scroll-controlled, so it is capped at 9/16 of the screen height) and `:30-65` (a Column with no scroll view).
- **Failure:** this hits any mobile build that has a RevenueCat key. Probed with the real Coiny and PatrickHand fonts loaded:
  - without the store and privacy buttons (the layout before this change) the sheet fits;
  - with the restore button it overflows by 26 px;
  - with restore plus the privacy-options button (EEA/UK) it overflows by 80 px.
  
  "Xoá tiến trình" at the bottom is clipped and cannot be tapped. The message shown after a restore adds another line. Probe: `realfont_probe_test.dart`, `realfont2_probe_test.dart`.
- **Fix:** pass `isScrollControlled: true` and wrap the Column in a `SingleChildScrollView`. Add a 360×640 widget test with the store ready and privacy options required.

### 5. Prices are fetched once, so an offline start blocks buying for the whole session (CONFIRMED by code path)

- **Where:** `lib/state/monetization.dart:39`; `lib/monetize/revenuecat_store.dart:40-43` and `:49-54`; `lib/ui/screens/store_sheet.dart:176-178`.
- **Failure:** the app starts offline, or Play Billing is briefly unavailable.
  - `configure` succeeds without a network, so `storeReady` is true.
  - `getProducts` fails, `_prices` stays empty, and every card shows "Chưa bán" with a disabled button until the app restarts.
  - The "Kiểm tra mạng" reason never appears, because `_offline` is set only when `configure` throws.
- **Fix:** retry `prices()` when the store sheet opens (and on app resume) while any price is missing. Show a network hint instead of "Chưa bán" when the fetch failed. Call `notifyListeners()` after `_prices` changes.

### 6. A full-screen ad that never reports back freezes ads and swallows the tap (PLAUSIBLE)

- **Where:** `lib/monetize/admob_ads.dart:107-147`; `lib/ui/screens/battle_screen.dart:65-68`.
- **Cause:** in google_mobile_ads 9.2.0 on Android, `FlutterInterstitialAd.show()` and `FlutterRewardedAd.show()` return without showing anything or firing any callback when the plugin has no activity bound. The method call itself still succeeds. Separately, `showAdWithoutView` throws `AdShowError` if the ad id is gone.
- **Failure, case 1:** `closed.future` never completes.
  - `_showing` stays true, so no rewarded or interstitial ad works for the rest of the session.
  - `_leave` never calls `go()`, so the result-card button does nothing on that tap.
- **Failure, case 2 (the throw):** the exception skips `_loadRewarded()` / `_loadInterstitial()` and escapes `_leave` unhandled.
- **Fix:**
  - Wrap `show()` in try/catch and reload the ad in `finally`.
  - Treat the ad as not shown if `onAdShowedFullScreenContent` has not fired within a few seconds.
  - In `_leave`, call `go()` from a `finally`.

### 7. The web build still bundles and loads RevenueCat's web SDK (CONFIRMED)

- **Where:** purchases_flutter 11.0.2 registers a web plugin; its pubspec lists `web: pluginClass` plus web-only `assets/web/`. `.flutter-plugins-dependencies` lists `purchases_flutter` under `web`. Its `registerWith` (`lib/web/purchases_flutter_web.dart:73-86`) appends a `<script>` that loads the bundled 1,010,445-byte `purchases_js_hybrid_mappings.js` on every web launch.
- **Failure:** app code is excluded correctly: only `services_mobile.dart` imports either SDK, and google_mobile_ads has no web plugin. Even so, the web build ships and executes RevenueCat's JavaScript, which does not match "web build has neither".
- **Fix:** either accept this and document it, or remove it with a `dependency_overrides` copy of purchases_flutter that has no web platform entry.

## Low

### 8. The 150 s interstitial gap resets on restart (CONFIRMED)

- **Where:** `lib/state/monetization.dart:25`, `:89-90`.
- **Failure:** `_lastInterstitial` lives only in memory, while `matchesSinceAd` is saved. After a restart, an interstitial can show less than 150 s after the previous one.
- **Fix:** save the timestamp, or start each session with `_lastInterstitial = now`.

### 9. `showInterstitial()` returns true when the ad failed to show (CONFIRMED)

- **Where:** `lib/monetize/admob_ads.dart:141-146`.
- **Failure:** after `onAdFailedToShowFullScreenContent` (for example, an ad older than an hour) `afterMatch` still resets the match counter and the 150 s gap. This contradicts `ads_service.dart:21`.
- **Fix:** return a `shown` flag that is set in `onAdShowedFullScreenContent`.

### 10. The purchase-success message is shown even when nothing was granted (PLAUSIBLE)

- **Where:** `lib/state/monetization.dart:125-127`.
- **Failure:** if an entitlement is missing or misnamed in RevenueCat, the player still sees "Đã mua … Cảm ơn bạn!". The card stays buyable, and a second attempt fails with "already purchased".
- **Fix:** for one-time products, check that the product's entitlement is in the returned snapshot before showing success; otherwise show a support message.

### 11. The reset dialog text is now wrong (CONFIRMED)

- **Where:** `lib/ui/screens/settings_sheet.dart:80`.
- **Failure:** the dialog says purchased items are lost. `resetProgress` actually keeps items bought with real money and remove-ads, and it wipes coins, including coins bought with real money.
- **Fix:** change the text to say both things.

### 12. An empty `admobAppId` property makes the app crash at launch (PLAUSIBLE)

- **Where:** `android/app/build.gradle.kts:32-33`.
- **Failure:** `-PadmobAppId=` (for example from an unset CI variable) bypasses the `?:` fallback, and the Mobile Ads SDK aborts app start on an invalid application id.
- **Fix:** add `.takeIf { it.isNotBlank() }` before the fallback.

### 13. Restore has no in-flight guard (PLAUSIBLE)

- **Where:** `lib/ui/screens/settings_sheet.dart:52-58`; `lib/ui/screens/store_sheet.dart:137`.
- **Failure:** on a double tap, the second call fails with "operation already in progress" and can overwrite the success message with "Không khôi phục được…".
- **Fix:** reuse `_busy` for restore and disable the button while it runs.

## Verified safe

- **Exclusive items:**
  - Coins cannot buy them (`game_controller.dart:114`); the wardrobe links to the store instead.
  - The `exclusive_probe_test.dart` probe shows they stay owned and equipped through a save round trip, and stay owned after a reset.
  - Stage and practice bots never wear them (`bots.dart:105`, `:112-115`, plus the test over all 120 stages).
- **Consent order:** the consent update runs first, then the form; the plugin's future completes only when the form is dismissed. `canRequestAds` is checked next, and only then does `MobileAds.initialize` run and ads start loading. Nothing loads before consent.
- **Rewards:** a reward is granted only from `onUserEarnedReward`. Google documents that this fires before dismissal for its own ads, and the app uses no mediation.
- **Double taps:**
  - Buy is guarded by `_busy` and the disabled button.
  - The free-coins and x2 buttons are guarded by `_showing` and `_rewarded = null`, both set synchronously before the first await.
- **Async gaps:** every use of `BuildContext` after an await checks `mounted`.
- **Lobby:** the new scroll layout fits 320×568 with a 90 px banner. A horizontal overflow at text scale 1.6 or more (`home_screen.dart:90`) predates this change.
- **No RevenueCat key:** the store reports it is not ready and the game runs normally.

## Plan acceptance criteria

1. Analyzer and tests pass, and all listed tests exist. However, the "coin pack credited once" test checks a fake the SDK does not match (finding 1).
2. I did not run `flutter build apk` or `flutter build web`, as instructed.
3. Platform config is met. `SKAdNetworkItems` lists only Google's id, and the docs say to add the full list.
4. The docs exist. `docs/kiem-tien.md:84` and `:89` need correcting once findings 1–3 are fixed.

## Recommended actions

1. Fix findings 1 and 2 together and add a `RevenueCatStore` test where the store id and the RevenueCat id differ. This blocks release.
2. Fix finding 3 (server-time cutoff), finding 4 (scrollable settings sheet) and finding 5 (price retry).
3. Harden the ad show path (findings 6 and 9) and the navigation in `_leave`.
4. Decide finding 7, then handle findings 8 and 10–13.

## Metrics

- Analyzer: 0 issues.
- Tests: 49 passed; coverage not measured.
- Type safety: sound null safety; no new `dynamic` or lint suppressions in app code.

## Unresolved questions

- Does the ghost opponent count as a bot? It is AI-driven but wears the player's own look, including exclusive items (`bots.dart:221-237`).
- Is loading RevenueCat's JavaScript in the web build acceptable (finding 7)?
- Product question: should a rewarded view count toward the 150 s interstitial gap? Today an x2 ad can be followed immediately by an interstitial.
- With a 13+ audience, should the maximum ad content rating be set to T, either in AdMob or through `RequestConfiguration`?

Status: DONE_WITH_CONCERNS
Summary: Every coin-pack purchase is credited twice on both platforms, and the 100-entry ledger cap re-credits history; both are confirmed with probes and block release. The other issues are medium or low.
Concerns/Blockers: Findings 1 and 2 must be fixed before real keys ship. I did not run the release builds.
