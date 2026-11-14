# Code review: Firebase cloud save

## Scope

- **Commits:** I reviewed `8f26176` (feature) and `9578cc1` (docs). They were committed while the review was running. The committed `lib/`, `test/`, `docs/`, rules and pubspec files are byte-identical to the copy I tested.
- **Size:** 29 files changed (+1,358/−27). Of these, 21 files are under `lib/` and `test/` (+1,057/−24).
- **Checks:**
  - `flutter analyze` is clean and `flutter test` passes (73 tests). I ran both on a copy in `/tmp/claude-0/-home-user-pen-zz/c71402d3-a215-5010-aaa1-2dc4baa1a58e/scratchpad/review-cloud/`.
  - Ten probes in `/tmp/claude-0/-home-user-pen-zz/c71402d3-a215-5010-aaa1-2dc4baa1a58e/scratchpad/review-cloud/test/probe/cloud_probe_test.dart` reproduce findings 2–5 and 7–10 (P1–P10).
  - I did not run `flutter build`.
- **Sources:** I checked each SDK claim against the package sources in `/root/.pub-cache/hosted/pub.dev/` and against the Firebase and RevenueCat docs.

## Overall assessment

The code is small and readable. The merge rules hold for coin packs and the starter pack: I found no double counting across merge, upload and merge cycles, resets, or account switches.

Three promises the feature makes do not hold:

1. "An offline start can never overwrite a better cloud save." Firestore's offline cache and write queue break it.
2. "The save that got further wins." The reset counter overrides progress when it compares unrelated saves.
3. "Purchases follow the account." "Gỡ quảng cáo" is switched off after linking to an existing account or after deleting the account.

The tests do not catch these because FakeCloud models offline as an exception and FakeStore shares entitlements across accounts.

## Critical

### 1. Firestore's offline cache and write queue let a stale phone overwrite a better cloud save (CONFIRMED)

- **Where:** `lib/monetize/firebase_cloud.dart:83` calls `get()` with no options, and `:92` calls `set`. Firestore `Settings` are never configured. The flow is in `lib/state/cloud_sync.dart:66-74`.
- **Cause:**
  - On Android and iOS, Firestore persistence is on by default.
  - `get()` defaults to `Source.serverAndCache`. When the backend cannot be reached (offline, or a connection that does not come up within the client's timeout of about 10 s), it returns the cached document, which is this phone's own last upload.
  - Even `Source.server` overlays pending local writes on the server data (`cloud_firestore_platform_interface-8.1.0/lib/src/pigeon/messages.pigeon.dart:129`).
  - Writes made offline are persisted and sent later, without any merge.
- **Failure (a):**
  1. Phone A last synced at stage 10. The player links phone B and reaches stage 40 there.
  2. Phone B breaks, and the player opens phone A without a network.
  3. `download()` returns A's cached stage-10 copy. The merge changes nothing, `_mergedFor` is set, and every change queues a `set`.
  4. When A reconnects, the queued writes replace stage 40. A replacement phone that links gets stage 10, and stage 40 is lost.
- **Failure (b):**
  1. A session ends offline and leaves writes queued on disk.
  2. The next launch is online, but `get()` returns the server document with those pending writes applied.
  3. The merge therefore sees the phone's own save, and the queued writes then overwrite whatever another phone uploaded.
- **Test gap:** `test/state/cloud_sync_test.dart:53-69` models offline as `init()` and `download()` throwing. For a returning user, the real `init()` succeeds offline and `download()` returns the cache. `docs/luu-tren-may.md:19` and the commit message repeat the false guarantee.
- **Fix:**
  - Set `FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false)` right after `initializeApp`.
  - Read with `get(const GetOptions(source: Source.server))`. The merge read then fails offline instead of returning the cache, and no queued write outlives the process.
  - To cover offline periods inside a session, make the upload a transaction. It re-reads the document and re-merges when `updatedAt` differs from the value seen at the last merge. Transactions fail offline instead of queueing.

### 2. The reset counter (epoch) decides merges between unrelated saves (CONFIRMED)

- **Where:** `lib/core/save_merge.dart:20-21`.
- **Cause:** `epoch` counts resets within one save's history. `cloudLeads` also compares it between saves that never shared a history, such as a new phone's anonymous save and the account's save after linking. Any difference in epoch beats any amount of progress.
- **Failure (P2a):** The account was reset once long ago and is now at stage 5 (epoch 1). On a new phone the player reaches stage 30 before linking. After linking, the phone is back at stage 5. Stage 30 is discarded, which breaks the user decision that the save that got further wins.
- **Failure (P2b):**
  1. The account is at stage 80 (epoch 0).
  2. The player resets once on a new, unlinked phone (epoch 1), then links it to the account.
  3. The cloud becomes stage 0, epoch 1.
  4. The main phone (stage 80) is reset to stage 0 the next time it starts. No copy of stage 80 survives anywhere.
- **Fix:**
  - Record in the save the account it was last merged with (for example `account = uid`).
  - Apply the epoch rule only when `local.account == uid`. Otherwise compare progress only, and keep the cloud's epoch in the result so a foreign reset cannot reset the account's other phones.
  - Turn P2a and P2b into tests.

## High

### 3. "Gỡ quảng cáo" is switched off after linking to an existing account and after deleting the account (CONFIRMED)

- **Where:** `lib/state/game_controller.dart:240` (`save.noAds = snap.entitlements.contains(Ent.noAds)`), `lib/state/monetization.dart:53-56`, `lib/monetize/revenuecat_store.dart:99-109` and `lib/state/cloud_sync.dart:73`.
- **Cause:**
  - The merge ORs `noAds` (`save_merge.dart:43`). Then `onAccount` calls `logIn`, and the new account's snapshot overwrites `noAds`.
  - The RevenueCat App User ID is the anonymous Firebase uid, so a purchase made before linking belongs to that identified user.
  - RevenueCat does not move purchases when `logIn` switches from one identified user to another. They stay with the original user until a restore.
- **Failure (P4):**
  1. On a new phone the player buys "Gỡ quảng cáo".
  2. The store prompts "Liên kết Google để không mất đồ đã mua…", and the player links an account that already has progress.
  3. After the switch, `noAds` is false and ads come back.
  4. The store offers the product again, and buying it fails as "already purchased".
- **Failure (P5):** The same thing happens after "Xoá tài khoản".
- **Recovery:** The player has to restore purchases manually. That works only if the RevenueCat project's restore behaviour is "Transfer to new App User ID". Outfits survive only because `owned` never shrinks.
- **Fix:**
  - When the store's user changes from one identified id to another (switch or delete), call `Purchases.restorePurchases()` (or `syncPurchasesForResult()`) after `logIn`, and apply that snapshot.
  - Document the required RevenueCat setting in `docs/kiem-tien.md`.
  - Add a test with a store fake that keeps entitlements per App User ID; the probe's `AccountStore` can serve.

## Medium

### 4. A save written by the previous build loses its coin ledger, so the store pays again (CONFIRMED)

- **Where:** `lib/core/save_data.dart:184-189`.
- **Cause:** Commits `e1f77d4` to `2a26c82` stored `creditedTx` as a JSON list. The new reader accepts only a map, so the ledger loads empty while `storeSince` survives.
- **Failure (P1):** A test install with 1,000 coins and `creditedTx: ['rc_1']` updates to this build. The first store snapshot credits `rc_1` again, leaving 2,000 coins.
- **Exposure:** Only devices that installed those debug-signed builds (about 1.5 hours of history) and bought sandbox coin packs.
- **Fix:** Also read the list form, and add a test for it:

  ```dart
  if (tx is List) {
    for (final id in tx.whereType<String>().take(maxCreditedTx)) {
      out.creditedTx[id] = 0;
    }
  }
  ```

  The value 0 stops a later merge from adding those coins to another save.

### 5. `connect()` reuses a stale in-flight connect after an account switch, so the new account is never merged (CONFIRMED)

- **Where:** `lib/state/cloud_sync.dart:56-59`, `:108-111` and `:121-123`.
- **Cause:** `connect()` returns `_connecting` even when that run started for a different uid, and `_connect` does not re-check the uid when it finishes.
- **Failure (P3):** The first connect is still downloading (a slow network at launch) when the player links an existing account. `linkGoogle` clears `_mergedFor` and waits for the old run. That run merges the abandoned anonymous account's empty document and calls `onAccount('anon-1')`. As a result:
  - The switched account's stage 40 is not merged.
  - `synced` is false, so nothing is backed up for the rest of the session.
  - RevenueCat stays logged in to the abandoned uid. Purchases made now land there and then trigger finding 3.
  - The panel says "đã chuyển sang và gộp" but shows the local stage.
- **Other triggers:** The same race happens after an offline launch, when closing the Google account picker resumes the app and starts a connect while the link is still running. `deleteAccount` has the same pattern.
- **Fix:**
  - In `linkGoogle` and `deleteAccount`, wait for `_connecting` before changing `_mergedFor`, then call `connect()`.
  - In `_connect`, stop if `cloud.uid != uid` once `download()` returns, and repeat while `cloud.uid != _mergedFor`.

### 6. Waiting on Firestore writes hangs linking and account deletion while offline (CONFIRMED)

- **Where:** `lib/state/cloud_sync.dart:106` (`await push()` before linking) and `:74`; `lib/monetize/firebase_cloud.dart:92` and `:143`.
- **Cause:** A Firestore write future resolves only when the backend acknowledges the write, so it stays pending while offline. The Firebase reference says this for setDoc and deleteDoc and advises against awaiting them.
- **Failure:**
  - Offline, with an unsent change, tapping "Liên kết Google" never reaches the account picker. The panel stays on "Đang liên kết…" with its buttons disabled until the network returns, and then the picker appears unprompted.
  - Offline, "Xoá tài khoản" hangs the same way on the document delete. Instead of failing with "Kiểm tra mạng", the deletion runs later, possibly asking for a Google re-auth minutes afterwards.
  - `_connect` also holds `_connecting` until its own upload is acknowledged.
- **Possible wedge (PLAUSIBLE):** If the Firebase user changes while that upload is pending, the write stays in the old user's queue and may never resolve this session. Every later `connect()` would then hang. This depends on how Firestore keeps a write queue per user.
- **Fix:**
  - Drop the upload before linking; the switch path merges the local save anyway.
  - Use `unawaited(push())` in `_connect`.
  - Before deleting, do a `Source.server` read so offline fails fast, and put a timeout on the delete.

### 7. An upload during deletion re-creates the deleted account's document (CONFIRMED)

- **Where:** `lib/state/cloud_sync.dart:118-127`; `lib/monetize/firebase_cloud.dart:143-155`.
- **Cause:** `FirebaseCloud.deleteAccount` deletes the document first, then the user (a network call, plus a Google re-auth for linked players), then signs in anonymously. During that window `cloud.uid` is still the old uid. `synced` therefore stays true, and any `push()` writes `players/{old}` with a token that is still valid.
- **Failure (P6):** The player changes a setting, for example sound in the same Settings sheet, then confirms deletion. The 8-second debounce fires during the deletion, after the document was deleted. The account is gone, but its save stays in Firestore as an orphan. That undoes the data deletion Google Play requires.
- **Fix:** In `CloudSync.deleteAccount`, cancel `_timer` and set `_mergedFor = null` before calling `cloud.deleteAccount()`, and restore it if the call fails.

## Low

### 8. `_sent` survives an account switch (CONFIRMED)

- **Where:** `lib/state/cloud_sync.dart:67-70`.
- **Failure:** The switched account may have no document, for example because it was linked while the first merge had failed. `push()` then compares against the last upload to the old account and skips the upload. P7 shows `synced` true and no document.
- **Fix:** In `_connect`, always set `_sent = raw`, which is null when there is no document.

### 9. A cloud document that is not valid JSON stops the backup permanently (CONFIRMED)

- **Where:** `lib/state/cloud_sync.dart:68`.
- **Failure:** `jsonDecode` throws, the catch-all swallows it, and every connect fails the same way (P8). The panel shows "Chưa kết nối" indefinitely.
- **Fix:** Treat an undecodable document as absent, and let the merge result overwrite it.

### 10. The store's link prompt ignores outfit purchases (CONFIRMED)

- **Where:** `lib/ui/screens/store_sheet.dart:44-45`.
- **Failure:** Buying "Bộ Hoàng gia" or "Bộ Ngân hà" sets none of the flags the prompt checks (P9). The plan says the store prompts after the first purchase.
- **Fix:** Also check `g.save.owned.any((id) => itemIndex[id]?.exclusive ?? false)`.

### 11. `GoogleSignIn.initialize` can run twice, and the store prompt has no busy guard (PLAUSIBLE)

- **Where:** `lib/monetize/firebase_cloud.dart:97-102` sets `_googleReady` only after the await, and `lib/ui/screens/store_sheet.dart:121` lets a double tap start two link flows.
- **Failure:**
  - google_sign_in 7.2.0 documents a second `initialize` call as undefined behaviour.
  - If the first link succeeds, the second `linkWithCredential` reports `provider-already-linked` as a failure.
- **Fix:** Store and reuse the initialize future, clearing it on error. Disable the prompt's button while a link runs.

### 12. A build without `GOOGLE_SERVER_CLIENT_ID` shows a link button that always fails (CONFIRMED)

- **Where:** `lib/monetize/firebase_cloud.dart:28`.
- **Failure:** `complete` does not check the server client id. On Android without `google-services.json`, google_sign_in_android throws `clientConfigurationError` ("serverClientId must be provided on Android").
- **Fix:** On Android, require the id before showing the link button while keeping the anonymous backup, or require it in `complete`.

### 13. Several flows report the wrong outcome (CONFIRMED)

- `lib/ui/screens/cloud_panel.dart:15-17` claims a merge after `LinkedSwitched`, even when the following connect failed or was skipped (finding 5). It should check `sync.synced`.
- `lib/monetize/firebase_cloud.dart:117`: if `reload()` fails after a successful link, the player sees "Liên kết không thành công".
- `lib/monetize/firebase_cloud.dart:155`: if the anonymous sign-in fails after `user.delete()` succeeded, `deleteAccount` returns false ("Chưa xoá được") although the account is gone, and CloudSync keeps the deleted uid in `_mergedFor`.
- `lib/monetize/firebase_cloud.dart:149-158`: cancelling the Google re-auth shows a "Kiểm tra mạng" message, and the document has already been deleted by then.
- `lib/ui/screens/cloud_panel.dart:91` labels the link button "Đang liên kết…" while a delete runs.

### 14. The pending RevenueCat login is lost if `getCustomerInfo` fails during store start-up (PLAUSIBLE)

- **Where:** `lib/monetize/revenuecat_store.dart:44-55`.
- **Failure:**
  - If `identify()` arrives while the store is starting and `getCustomerInfo()` then throws, line 51 never runs. CloudSync does not call `onAccount` again this session, so purchases go to the cached or anonymous RevenueCat user.
  - If `identify()` lands between lines 46 and 48, it logs in directly, and `init` then applies the earlier user's snapshot last.
- **Fix:** Keep the init future, make `identify` await it, then call `logIn`.

### 15. A merge at resume can swap the save under a running match (PLAUSIBLE)

- **Where:** `lib/state/cloud_sync.dart:70` together with `lib/state/game_controller.dart:295-299`.
- **What is safe:** Nothing caches the `SaveData` object (every UI read happens inside a build), so match rewards land in the merged save.
- **Failure:** The first connect failed, and a resume during a match adopts a save that was reset on another phone. Winning the running stage-41 match then sets `stage = 41` on the reset save and skips 40 stages.
- **Fix:** Wait to call `replaceSave` until the battle and editor screens are closed.

## Checked and fine

- **Web build:** The conditional export in `services.dart` keeps `firebase_cloud.dart` and the Firebase imports out of the web build. The plugins still register their web classes, but `registerWith` only sets platform instances. No Firebase script loads, because the web app never calls `initializeApp`.
- **`credential-already-in-use`:** On Android the plugin returns `updatedCredential` as `e.credential`; it is stored natively by hash code and found again by `signInWithCredential`. The fallback reuse of the Google ID token is valid within the token's lifetime because no nonce is set.
- **`requires-recent-login`:** The firebase_auth 7.0.1 doc comment says this error does not apply to anonymous users. Linked users go through re-authentication.
- **Rules:**
  - `updatedAt == request.time` holds for `FieldValue.serverTimestamp()`.
  - `hasOnly` together with `is string` rejects other document shapes.
  - The 600,000-character limit is below the 1 MiB document cap.
  - List queries cannot enumerate other players.
- **Money:**
  - I found no double count in merge, upload and merge cycles, resets, or account switches.
  - Taking the minimum `storeSince` only widens the window over the same account's history, and those ids are already in the merged ledger.
  - `eq` stays consistent because the base save is copied whole and only exclusive items are added.
- **Auth state:** I found no race between the `userChanges` stream and `_user`.
- **Android minSdk:** Flutter's default of 24 matches what the plugins require.
- **RevenueCat ordering:**
  - The explicit `logIn` always follows the merge, both when the store is ready and when the id is held for `configure`.
  - Before the merge, `init` applies the snapshot of the cached user (normally the same uid) or the anonymous user to the unmerged save. That is harmless apart from finding 14.

## Plan follow-ups (`plans/261114-1122-firebase-cloud-save/plan.md`)

- **Criterion 1:** Analyze and tests pass, and the listed tests exist. They miss the risky paths: the Firestore cache, epoch across accounts, the legacy ledger, entitlements per account, and concurrency. After the fixes, add the probes as tests.
- **Criterion 2:** Not verified here, because I ran no build.
- **Criterion 3:** The rules, `firebase.json` and setup docs exist. After the fixes, `docs/luu-tren-may.md:19` and `:35` need correcting: the offline guarantee, purchases following the account, and the RevenueCat transfer setting.
- **Step 5 ("review, đẩy code"):** The commits landed before this review. Keep the plan at "đang làm" until findings 1–7 are fixed.

## Metrics

- **Type safety:** The analyzer is clean, and the new code has no lint suppressions.
- **Tests:** 73 passed. I did not measure coverage.
- **Lint issues:** 0.

## Unresolved questions

- Should account deletion also delete the RevenueCat customer, which needs a server-side REST call? Or is keeping the purchase records acceptable, as long as it is disclosed?
- Should the anonymous account and document left behind on a switch be deleted before `signInWithCredential`, while that account is still signed in, to satisfy Google Play's deletion rules?
- Which RevenueCat restore behaviour is configured? Recovery from finding 3 depends on "Transfer to new App User ID".

## Sources

- [Firestore offline data](https://firebase.google.com/docs/firestore/manage-data/enable-offline)
- [Firestore JS reference (setDoc, deleteDoc)](https://firebase.google.com/docs/reference/js/firestore_.md)
- [RevenueCat: identify users with logIn](https://revenuecat.github.io/codelabs/guides/identify-users-login-logout.html)
- [RevenueCat community: switching accounts](https://community.revenuecat.com/sdks-51/reset-subscription-status-when-switching-accounts-944)
