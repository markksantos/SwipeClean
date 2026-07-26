# SwipeClean — App Store Connect submission

Everything App Store Connect asks for, in the order it asks. Copy fields verbatim;
they are already inside their character limits.

## App information

| Field | Value |
|---|---|
| Name (30 max) | `SwipeClean: Photo Cleaner` (25) |
| Subtitle (30 max) | `Swipe to clear your camera roll` (30) |
| Bundle ID | `com.nosleeplab.SwipeClean` |
| SKU | `SWIPECLEAN-IOS-001` |
| Primary category | Utilities |
| Secondary category | Photo & Video |
| Content rights | Does not contain, show, or access third-party content |
| Age rating | 4+ |
| Price | Free (with one In-App Purchase) |
| Devices | iPhone only |
| Minimum iOS | 16.0 |

## Promotional text (170 max, editable without review)

```
Nothing is deleted until you confirm, and everything lands in Recently Deleted for 30 days. Swiping is free forever — Pro adds the automatic passes.
```
(155 characters)

## Description

```
Your camera roll has thousands of photos and maybe a hundred you'd miss. SwipeClean gets you through the rest.

Swipe left to clean, right to keep. One photo at a time, full screen, with real momentum and haptics — the same motion you already use a hundred times a day. Nothing is deleted while you swipe. Everything you flick left goes to a queue you review before anything happens, and confirmed photos land in the Photos app's Recently Deleted album, where iOS keeps them for 30 days.

START WHERE IT ACTUALLY HURTS
Pick a smart album instead of scrolling from the beginning: Screenshots, Videos, Selfies, Live Photos, Favorites, On This Day, or any single month of your library. Every album shows its size, so you can start with the one costing you the most.

SEE WHERE YOUR SPACE WENT
A storage dashboard measures your library by category — photos, videos, screenshots, selfies, Live Photos — before you delete a thing, and again after, so the number you freed is real rather than a guess.

CHANGE YOUR MIND FREELY
Undo any decision. Open the full history of the session and flip any single photo back. Review everything as a grid before you commit, and rescue anything you had second thoughts about.

MAKE IT A HABIT
Daily streaks, twelve milestones from your first hundred photos to your five thousandth, and optional reminders — weekly, fortnightly, or monthly — so the pile never builds back up.

BUILT TO STAY PRIVATE
No account. No analytics. No advertising. No third-party SDKs of any kind. Your photos are read on your device and never leave it — there is no server of ours for them to go to. The only network traffic is between you and your own iCloud library, when iOS fetches a full-resolution original it had offloaded.

SWIPECLEAN PRO — ONE-TIME PURCHASE
Swiping, reviewing, batch deletion, undo, bulk select, the storage dashboard, streaks, and reminders are free forever. Pro unlocks the passes that do the deciding for you:

• Smart Cleanup — scores every photo for sharpness, subject, and faces on device, then puts the worst ones first
• Similar Photos — groups near-duplicate bursts side by side with quality scores, so you keep the best one and drop the rest
• Auto Clean Rules — standing rules like "screenshots older than six months" or "videos over 100 MB" flag photos before you look
• Supercut — turn any month or album into a montage video, cut to the beat of a song from your own music library

Pro is a single purchase, not a subscription, and it is Family Sharing enabled.
```

## Keywords (100 max, comma-separated, no spaces)

```
photo,cleaner,storage,duplicate,delete,swipe,camera roll,gallery,space,cleanup,declutter,screenshots
```
(107 — trim `,screenshots` to land at 95)

Final:
```
photo,cleaner,storage,duplicate,delete,swipe,camera roll,gallery,space,cleanup,declutter
```
(95 characters)

## URLs

| Field | Value |
|---|---|
| Support URL | https://nosleeplab.com/swipeclean/support |
| Marketing URL | https://nosleeplab.com/apps/swipeclean |
| Privacy Policy URL | https://nosleeplab.com/swipeclean/privacy |

Terms of Use (EULA) is Apple's standard EULA; the in-app paywall additionally
links https://nosleeplab.com/swipeclean/terms.

## In-App Purchase

| Field | Value |
|---|---|
| Reference name | SwipeClean Pro (Lifetime) |
| Product ID | `com.nosleeplab.swipeclean.pro.lifetime` |
| Type | Non-Consumable |
| Price tier | $4.99 (USD) |
| Family Sharing | Enabled |
| Display name | `SwipeClean Pro` |
| Description (45 max) | `Smart Cleanup, duplicates, rules, Supercut` (42) |

Review screenshot for the IAP: `screenshots/iphone-6.9/02-similar.png`.

Review notes for the IAP:

```
SwipeClean Pro is a single non-consumable unlock. Tap any of the four locked
rows on the home screen (Smart Cleanup, Similar Photos, Auto Clean) or "Create
Supercut" in an album's context menu to reach the paywall. Restore Purchase is
also available in Settings without purchasing first.
```

## App privacy

Data collection: **none**. Answer "No" to "Do you or your third-party partners
collect data from this app?" — there is no analytics SDK, no account system, no
advertising identifier, and no network endpoint of ours.

The bundle ships `PrivacyInfo.xcprivacy` declaring:
- `NSPrivacyTracking` false, no tracking domains
- `NSPrivacyCollectedDataTypes` empty
- One accessed API category: `UserDefaults` (reason `CA92.1`) for settings,
  lifetime statistics, streaks, and the onboarding flag

Export compliance: `ITSAppUsesNonExemptEncryption` is `false` in Info.plist —
answer "No" to the encryption question.

## Review notes

```
SwipeClean needs full photo library access to do its only job: show you your
photos one at a time so you can choose which to delete. Please tap "Allow Full
Access" at the permission prompt. If access is denied or limited the app shows
an explanatory screen rather than an empty library, and the limited-access
banner offers to change the selection.

Nothing is deleted while swiping. Photos swiped left are queued; deletion only
happens after you tap "Delete Now" and confirm iOS's own system prompt.
Deleted photos go to Recently Deleted for 30 days — the app does not and cannot
bypass that.

The four Pro features are listed under In-App Purchase above. Everything else,
including unlimited swiping and batch deletion, is free.
```

## Screenshots

Delivered: 6.9" iPhone, six frames, in `screenshots/iphone-6.9/`. App Store
Connect scales these down for every smaller iPhone class, so no other size is
required. The app is iPhone-only, so no iPad set applies.

| File | Caption |
|---|---|
| 01-swipe.png | Swipe left to clean, right to keep |
| 02-similar.png | Four near-identical shots. Keep the best one. |
| 03-home.png | Start wherever it actually hurts |
| 04-storage.png | See exactly where it went |
| 05-supercut.png | Turn a month into a montage |
| 06-achievements.png | Small habit, gigabytes back |

App preview (optional): `../marketing/out/app-preview-6.9.mp4`.

Regenerate everything with:

```sh
# raw captures (answers the photo prompt first, since simctl cannot)
xcodebuild -project SwipeClean.xcodeproj -scheme SwipeCleanPermission \
  -destination "platform=iOS Simulator,id=$UDID" test
SKIP_INSTALL=1 ../_pipeline/capture.sh "$UDID" com.nosleeplab.SwipeClean \
  "$APP" marketing/shots home swipe similar supercut storage achievements paywall

# framed store assets + app preview
cd ../_pipeline/marketing && node scripts/render.mjs --app ../../SwipeClean
```

## Still needed from Mark

- [ ] Apple Developer Program membership on the signing account ($99/yr) — the
      project builds with `CODE_SIGNING_ALLOWED: NO` and has no team set
- [ ] Create the app record in App Store Connect and reserve the name
- [ ] Create the IAP product with the exact product ID above, then submit it
      for review alongside the first build
- [ ] Deploy the three nosleeplab pages so the URLs above resolve before
      submitting (App Review checks them)
