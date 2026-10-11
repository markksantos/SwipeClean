# SwipeClean — App Store readiness pass

2026-07-26. Audit, fixes, monetization, and launch assets. 109 tests at the
start, 140 at the end, all passing, zero build warnings.

## What was actually broken

Ordered by how badly it would have hurt.

**The deck died after one swipe.** `SwipeCardView` kept `isFlyingOff` in `@State`
and `CardStack` rendered the front card at a fixed position in the view tree, so
SwiftUI handed the *next* photo to the same view instance. `isFlyingOff` stayed
true, the incoming card was drawn at `opacity 0` off-screen, and both branches of
the drag gesture bailed on `guard !isFlyingOff`. Every swipe after the first was
silently dropped until the screen was dismissed — the core interaction was
one-shot. The card is now keyed on the photo's id and the deck advances after the
fly-off animation instead of before it. A UI test drags seven times and asserts
the counter reads "8 of 18".

**Unbounded image memory.** `allItems` holds one `PhotoItem` per asset — tens of
thousands on a real library — and `PhotoItem` is a class, so a screen-sized
`UIImage` assigned during review stayed alive for the whole session. Nothing ever
released them. A session on a real library grew by megabytes per swipe until the
app was jetsammed.

**The AI quality score was 0 for every photo.** Both Pro features that rank
photos — Smart Cleanup and Similar Photos — rank by it, and the duplicate badge
read "0%" on all four photos in a group including the one labelled Best. Three
causes: saliency read `salientObjects` off an attention-based Vision request that
never populates it; sharpness rendered a Laplacian through `.RGBA8`, clamping
away every negative value; and the convolution's border artefacts added a
constant offset. Vision can also be genuinely unavailable (it throws on the
simulator), which both paths were catching and returning 0 for — indistinguishable
from a real measurement of zero. Components are now optional and the weights
renormalise over whatever ran.

**Undo corrupted lifetime statistics.** `SessionTracker.undoLastDelete` existed
but nothing called it, so undo rewound the deck and the queue while leaving
"photos cleaned" and "storage freed" inflated — and `endSession()` then persisted
those figures into the lifetime totals that award achievements. The gesture path
and the button path each had their own copy of the swipe logic, which is also how
the button path ended up never recording keeps. Both now go through one
`SwipeCoordinator`.

**The rescue button freed the wrong photo.** Both rescue paths in the review grid
called `undoLastDeletion()`, releasing whatever was queued most recently rather
than the photo the user tapped — so the tapped photo stayed queued and an
unrelated one was spared.

**"Delete Now" lied on failure.** It discarded the deletion `Result` and latched
to "Deleted". Declining iOS's own confirmation left the user told their photos
were gone when nothing had been touched.

**Supercut rendered almost nothing.** It composed from whatever images happened
to be cached on each `PhotoItem`, which for supercut's own fetch is nothing —
most stills were skipped entirely and the rest upscaled from 600px thumbnails.

**`.autoClean` fetched the whole library.** `fetchLimit = 0`, commented "empty
result". In PhotoKit 0 means *no limit*.

Smaller: card images were requested at point rather than pixel dimensions (a
third of their drawn resolution); grids read `PhotoItem.thumbnail`, which is only
populated inside the active window, so queued and unvisited photos drew
placeholder icons; album cards carried a drifted copy of the fetcher's
source-to-asset switch and requested with `.fastFormat`, which returns nil when
nothing is cached; confetti drew from `Date()` inside a bare `Canvas` and tried
to force redraws with a `Timer` that only invalidated itself, so it rendered one
frozen frame; a DRM-protected Apple Music pick set a nil URL and looked ignored;
the document picker opened a security scope it never closed; a "Change" button
had an empty closure; "share before delete" shared a resized re-encode instead of
the original file; and the home screen printed "SwipeClean" twice.

## What was added

- **Monetization**, which did not exist. One non-consumable,
  `com.nosleeplab.swipeclean.pro.lifetime`, $4.99, Family Sharing on. Gated:
  Smart Cleanup, Similar Photos, Auto Clean Rules, Supercut. Free forever:
  swiping, batch deletion, undo, bulk select, storage dashboard, streaks,
  reminders. Metering the review flow would earn one-star reviews for the exact
  thing the listing promises; a test asserts no plain album is ever gated.
- **Store assets**: six framed 1320x2868 screenshots, a 16s App Preview built
  from real screen recordings, and landscape + square social cuts.
- **`appstore/METADATA.md`**: every App Store Connect field, inside its limits.
- **nosleeplab.com**: `/apps/swipeclean` plus the support page the app links to,
  and a correction to privacy and terms, which claimed the app "makes no network
  requests whatsoever" and works "in Airplane Mode". It doesn't — PhotoKit
  fetches iCloud originals.
- **Reproducible capture**: a DEBUG-only `ScreenshotMode` opens any named screen
  from a launch argument, so store screenshots regenerate without automating taps.

## Regenerating the assets

```sh
UDID=$(xcrun simctl list devices booted | grep -o '[0-9A-F-]\{36\}' | head -1)
APP=$(xcodebuild -project SwipeClean.xcodeproj -scheme SwipeClean \
  -destination "platform=iOS Simulator,id=$UDID" -showBuildSettings \
  | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{d=$2} / FULL_PRODUCT_NAME /{n=$2} END{print d"/"n}')

# 1. answer the photo prompt (simctl cannot dismiss a Springboard alert)
xcodebuild -project SwipeClean.xcodeproj -scheme SwipeCleanPermission \
  -destination "platform=iOS Simulator,id=$UDID" test

# 2. raw captures — SKIP_INSTALL keeps the permission answer alive
SKIP_INSTALL=1 ../_pipeline/capture.sh "$UDID" com.nosleeplab.SwipeClean "$APP" \
  marketing/shots home swipe similar supercut storage achievements paywall

# 3. real swipe footage for the App Preview
TRIM_START=8 ../_pipeline/record.sh "$UDID" SwipeClean.xcodeproj SwipeCleanPermission \
  SwipeCleanUITests/DemoFootageUITests/test_recordSwipeDemo marketing/clips/swipe-demo.mp4

# 4. framed screenshots + videos
cd ../_pipeline/marketing && node scripts/render.mjs --app ../../SwipeClean
```

The simulator needs a believable library first. `marketing/` has none committed
(captures are gitignored); seed one with `xcrun simctl addmedia` using photos
that include a burst of near-identical shots, or Similar Photos has nothing to
group.

## Landmines

- **`simctl privacy grant photos` does not suppress the photo prompt** on the
  iOS 26 simulator. It writes `kTCCServicePhotos = 2` and library reads do
  succeed, but the prompt still appears and `authorizationStatus(for: .readWrite)`
  still answers `.notDetermined`. A system alert belongs to Springboard, so
  nothing in `simctl` can dismiss it and every screenshot taken while it is up is
  a photo of the alert. Answer it once from a UI test, then avoid reinstalling —
  installing resets the bundle's TCC record.
- **Vision throws on the simulator**: "Failed to create espresso context". Any
  code path that treats a Vision failure as a zero result will look fine locally
  and be wrong on device, or vice versa.
- **`XCUIElement.swipeLeft()` will not drive the card.** It is a short flick at an
  element's centre; dispatched at the window it registered one swipe in seven.
  Use a coordinate drag, and keep both ends inside `0...1` — a normalized offset
  outside the app's frame is not delivered at all.

## Blocked on Mark

- Apple Developer Program membership on the signing account. The project builds
  with `CODE_SIGNING_ALLOWED: NO` and no team, so there is no way to archive or
  upload from here.
- Create the App Store Connect record, reserve the name, and create the IAP with
  the exact product id above.
- Deploy the nosleeplab pages so the three URLs resolve before submitting; App
  Review checks them.

## 2026-10-11 — Xcode 27 launch-prep pass

Verified on Xcode 27.0 GM (27A266a), iOS 27.0 simulator (iPhone 17 Pro Max):
140 tests pass, Release device build compiles unsigned, the app launches with no
crash (SwiftUI scene manifest present in the built Info.plist), and
`PhotoPermissionUITests` passes: the iOS 27 prompt's "Allow Full Access" leads
to the home screen. Home, swipe, storage, paywall and settings checked in light
and dark appearance. Product ID matches `SwipeClean.storekit`; Restore is on the
paywall and in Settings. Privacy manifest (UserDefaults `CA92.1` only) matches a
scan of the sources. No code change was needed; screenshots stay as they are.

Landmine: run `PhotoPermissionUITests` on its own (`-only-testing:`). Run after
`DemoFootageUITests`, it inherits that test's unanswered prompt, the app comes
up as `.denied`, and the test fails for a reason that is not the app's.
